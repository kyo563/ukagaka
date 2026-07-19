import AppKit
import Foundation
import SwiftUI

@main
struct UkagakaReproductionProjectApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("伺か再現プロジェクト", systemImage: "sparkles") {
            Button("表示") {
                appDelegate.showAccessory()
            }
            Button("隠す") {
                appDelegate.hideAccessory()
            }
            Divider()
            Button("終了") {
                NSApplication.shared.terminate(nil)
            }
        }

        Settings {
            EmptyView()
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var appState: CompanionAppState?
    private var accessoryController: DesktopAccessoryController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let state = CompanionAppState.bootstrap()
        appState = state
        accessoryController = DesktopAccessoryController(state: state)
        showAccessory()
        state.start()
    }

    func showAccessory() {
        if let accessoryController {
            accessoryController.show()
        }
    }

    func hideAccessory() {
        accessoryController?.hide()
    }
}

struct CompanionCharacter: Identifiable {
    let id: String
    let displayName: String
    let assetNamePrefix: String
    let accentColor: Color
    let profilePrompt: String
}

enum CharacterExpression: String, Codable, CaseIterable {
    case neutral
    case happy
    case angry
    case sad
    case surprised
}

struct CharacterLine: Identifiable, Codable, Equatable {
    let id: UUID
    let speakerID: String
    let text: String
    let expression: CharacterExpression
    let createdAt: Date

    init(
        id: UUID = UUID(),
        speakerID: String,
        text: String,
        expression: CharacterExpression = .neutral,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.speakerID = speakerID
        self.text = text
        self.expression = expression
        self.createdAt = createdAt
    }
}

enum CharacterProfiles {
    static let defaults: [CompanionCharacter] = [
        CompanionCharacter(
            id: "character_a",
            displayName: "キャラクターA",
            assetNamePrefix: "character_a",
            accentColor: .teal,
            profilePrompt: """
            あなたはデスクトップ常駐コンシェルジュの一人目です。
            観察力があり、落ち着いた口調で、ユーザーの作業をさりげなく助けます。
            返答は短く、相方との掛け合いでは少しだけ茶目っ気を出します。
            """
        ),
        CompanionCharacter(
            id: "character_b",
            displayName: "キャラクターB",
            assetNamePrefix: "character_b",
            accentColor: .pink,
            profilePrompt: """
            あなたはデスクトップ常駐コンシェルジュの二人目です。
            明るくテンポがよく、気づいたことを軽やかに話します。
            相方の説明を補足しつつ、ユーザーが次に動きやすい一言を添えます。
            """
        )
    ]
}

enum AppCommand {
    case search(String)
    case launchApplication(String)
    case chat(String)
}

struct CommandParser {
    func parse(_ input: String) -> AppCommand? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let query = trimmed.removingCommandPrefix(["検索", "search", "s"]) {
            return .search(query)
        }

        if let applicationName = trimmed.removingCommandPrefix(["起動", "open", "launch"]) {
            return .launchApplication(applicationName)
        }

        return .chat(trimmed)
    }
}

private extension String {
    func removingCommandPrefix(_ prefixes: [String]) -> String? {
        for prefix in prefixes {
            if self == prefix {
                return ""
            }

            for separator in [" ", "　", ":", "："] {
                let marker = prefix + separator
                if hasPrefix(marker) {
                    return String(dropFirst(marker.count)).trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
        }
        return nil
    }
}

enum CommandResult {
    case handled(String, CharacterExpression)
    case passToConversation
}

enum CommandRouterError: Error {
    case invalidSearchURL
}

@MainActor
struct CommandRouter {
    func run(_ command: AppCommand) async throws -> CommandResult {
        switch command {
        case .search(let query):
            return try openSearch(query)
        case .launchApplication(let applicationName):
            return launchApplication(applicationName)
        case .chat:
            return .passToConversation
        }
    }

    private func openSearch(_ query: String) throws -> CommandResult {
        let finalQuery = query.isEmpty ? "伺か" : query
        var components = URLComponents(string: "https://www.google.com/search")
        components?.queryItems = [URLQueryItem(name: "q", value: finalQuery)]

        guard let url = components?.url else {
            throw CommandRouterError.invalidSearchURL
        }

        NSWorkspace.shared.open(url)
        return .handled("「\(finalQuery)」を検索します。", .happy)
    }

    private func launchApplication(_ applicationName: String) -> CommandResult {
        let finalName = applicationName.isEmpty ? "Safari" : applicationName
        let appURL = URL(fileURLWithPath: "/Applications/\(finalName).app")

        if FileManager.default.fileExists(atPath: appURL.path) {
            NSWorkspace.shared.openApplication(
                at: appURL,
                configuration: NSWorkspace.OpenConfiguration(),
                completionHandler: nil
            )
        } else {
            NSWorkspace.shared.launchApplication(finalName)
        }

        return .handled("「\(finalName)」を起動してみます。", .happy)
    }
}

protocol ConversationGenerating {
    func generateReply(
        userInput: String,
        recentLines: [CharacterLine],
        characters: [CompanionCharacter]
    ) async throws -> [CharacterLine]
}

struct LocalConversationService: ConversationGenerating {
    func generateReply(
        userInput: String,
        recentLines: [CharacterLine],
        characters: [CompanionCharacter]
    ) async throws -> [CharacterLine] {
        guard characters.count >= 2 else { return [] }

        return [
            CharacterLine(
                speakerID: characters[0].id,
                text: "「\(userInput)」ですね。まずは状況を整理してみましょう。",
                expression: .neutral
            ),
            CharacterLine(
                speakerID: characters[1].id,
                text: "必要なら検索やアプリ起動もここからできます。入力の先頭に「検索:」や「起動:」を付けてください。",
                expression: .happy
            )
        ]
    }
}

struct OpenAIResponsesService: ConversationGenerating {
    private let apiKey: String
    private let model: String
    private let session: URLSession

    init(apiKey: String, model: String = "gpt-5", session: URLSession = .shared) {
        self.apiKey = apiKey
        self.model = model
        self.session = session
    }

    func generateReply(
        userInput: String,
        recentLines: [CharacterLine],
        characters: [CompanionCharacter]
    ) async throws -> [CharacterLine] {
        guard let url = URL(string: "https://api.openai.com/v1/responses") else {
            throw OpenAIResponsesError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload(
            userInput: userInput,
            recentLines: recentLines,
            characters: characters
        ))

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw OpenAIResponsesError.requestFailed(String(data: data, encoding: .utf8) ?? "")
        }

        let text = try extractOutputText(from: data)
        return parseLines(from: text, fallbackSpeakerID: characters.first?.id ?? "character_a")
    }

    private func payload(
        userInput: String,
        recentLines: [CharacterLine],
        characters: [CompanionCharacter]
    ) -> [String: Any] {
        [
            "model": model,
            "max_output_tokens": 500,
            "input": [
                [
                    "role": "developer",
                    "content": systemPrompt(characters: characters)
                ],
                [
                    "role": "user",
                    "content": """
                    ユーザー入力:
                    \(userInput)

                    直近の会話:
                    \(recentLines.suffix(6).map { "\($0.speakerID): \($0.text)" }.joined(separator: "\n"))
                    """
                ]
            ]
        ]
    }

    private func systemPrompt(characters: [CompanionCharacter]) -> String {
        let profiles = characters.map { character in
            """
            ID: \(character.id)
            名前: \(character.displayName)
            設定:
            \(character.profilePrompt)
            """
        }.joined(separator: "\n\n")

        return """
        あなたはmacOSデスクトップ常駐アクセサリ「伺か再現プロジェクト」の会話エンジンです。
        2名のキャラクターが短く自然に掛け合います。

        \(profiles)

        必ず次のJSON配列だけを返してください。
        [{"speakerID":"character_a","text":"短いセリフ","expression":"neutral"}]

        expressionは neutral, happy, angry, sad, surprised のいずれかです。
        """
    }

    private func extractOutputText(from data: Data) throws -> String {
        let object = try JSONSerialization.jsonObject(with: data)
        guard let dictionary = object as? [String: Any] else {
            throw OpenAIResponsesError.invalidResponse
        }

        if let outputText = dictionary["output_text"] as? String {
            return outputText
        }

        if let output = dictionary["output"] as? [[String: Any]] {
            let text = output.flatMap { item -> [String] in
                guard let content = item["content"] as? [[String: Any]] else { return [] }
                return content.compactMap { contentItem in
                    contentItem["text"] as? String
                }
            }.joined(separator: "\n")

            if !text.isEmpty {
                return text
            }
        }

        throw OpenAIResponsesError.invalidResponse
    }

    private func parseLines(from text: String, fallbackSpeakerID: String) -> [CharacterLine] {
        guard let data = text.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([GeneratedLine].self, from: data) else {
            return [CharacterLine(
                speakerID: fallbackSpeakerID,
                text: text.trimmingCharacters(in: .whitespacesAndNewlines),
                expression: .neutral
            )]
        }

        return decoded.map { line in
            CharacterLine(
                speakerID: line.speakerID,
                text: line.text,
                expression: line.expression
            )
        }
    }
}

private struct GeneratedLine: Decodable {
    let speakerID: String
    let text: String
    let expression: CharacterExpression
}

enum OpenAIResponsesError: Error {
    case invalidURL
    case invalidResponse
    case requestFailed(String)
}

struct BanterService {
    private let topics = [
        "今日の作業、少しだけ先回りして整えておきたいですね。",
        "デスクトップの端から見ると、締切というものは妙に足音がします。",
        "水分補給の時報も、ある意味では高度なコンシェルジュ機能です。",
        "検索したいことが浮かんだら、ここにそのまま投げてください。",
        "昔の常駐アクセサリ感と今のAI感、ちょうどいい混ざり具合を探しましょう。"
    ]

    func nextBanter(characters: [CompanionCharacter]) -> [CharacterLine] {
        guard characters.count >= 2 else { return [] }
        let topic = topics.randomElement() ?? topics[0]

        return [
            CharacterLine(speakerID: characters[0].id, text: topic, expression: .neutral),
            CharacterLine(speakerID: characters[1].id, text: "了解です。では、邪魔にならない声量で見守ります。", expression: .happy)
        ]
    }
}

struct DayEventService {
    private let eventsByMonthDay: [String: String] = [
        "01-01": "元日",
        "02-22": "猫の日",
        "03-14": "ホワイトデー",
        "04-01": "エイプリルフール",
        "05-05": "こどもの日",
        "07-07": "七夕",
        "08-11": "山の日",
        "09-09": "重陽の節句",
        "10-31": "ハロウィン",
        "11-03": "文化の日",
        "12-25": "クリスマス"
    ]

    func openingLines(on date: Date = Date(), characters: [CompanionCharacter]) -> [CharacterLine] {
        guard characters.count >= 2 else { return [] }

        let dateText = Self.dateFormatter.string(from: date)
        let eventText = eventName(on: date) ?? "記念日データはまだ登録されていない日"

        return [
            CharacterLine(speakerID: characters[0].id, text: "おかえりなさい。今日は\(dateText)です。", expression: .happy),
            CharacterLine(speakerID: characters[1].id, text: "今日のメモは「\(eventText)」。この一覧はあとで増やせます。", expression: .neutral)
        ]
    }

    func hourlyLine(on date: Date = Date(), character: CompanionCharacter) -> CharacterLine {
        let timeText = Self.timeFormatter.string(from: date)
        return CharacterLine(speakerID: character.id, text: "\(timeText)になりました。ひと息入れるなら今です。", expression: .happy)
    }

    private func eventName(on date: Date) -> String? {
        let key = Self.monthDayFormatter.string(from: date)
        return eventsByMonthDay[key]
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateStyle = .full
        formatter.timeStyle = .none
        return formatter
    }()

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "H時"
        return formatter
    }()

    private static let monthDayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "MM-dd"
        return formatter
    }()
}

@MainActor
final class CompanionAppState: ObservableObject {
    @Published private(set) var characters: [CompanionCharacter]
    @Published private(set) var lines: [CharacterLine] = []
    @Published var draftText = ""
    @Published private(set) var isThinking = false

    private let commandParser: CommandParser
    private let commandRouter: CommandRouter
    private let conversationService: ConversationGenerating
    private let banterService: BanterService
    private let dayEventService: DayEventService
    private var idleTimer: Timer?
    private var hourlyTimer: Timer?
    private var lastHourlyAnnouncement: Int?

    init(
        characters: [CompanionCharacter],
        commandParser: CommandParser,
        commandRouter: CommandRouter,
        conversationService: ConversationGenerating,
        banterService: BanterService,
        dayEventService: DayEventService
    ) {
        self.characters = characters
        self.commandParser = commandParser
        self.commandRouter = commandRouter
        self.conversationService = conversationService
        self.banterService = banterService
        self.dayEventService = dayEventService
    }

    static func bootstrap() -> CompanionAppState {
        let apiKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"]
        let model = ProcessInfo.processInfo.environment["OPENAI_MODEL"] ?? "gpt-5"
        let service: ConversationGenerating

        if let apiKey, !apiKey.isEmpty {
            service = OpenAIResponsesService(apiKey: apiKey, model: model)
        } else {
            service = LocalConversationService()
        }

        return CompanionAppState(
            characters: CharacterProfiles.defaults,
            commandParser: CommandParser(),
            commandRouter: CommandRouter(),
            conversationService: service,
            banterService: BanterService(),
            dayEventService: DayEventService()
        )
    }

    func start() {
        append(dayEventService.openingLines(characters: characters))
        scheduleIdleBanter()
        scheduleHourlyAnnouncements()
    }

    func submitDraft() {
        let input = draftText
        draftText = ""

        Task {
            await handle(input)
        }
    }

    func expression(for character: CompanionCharacter) -> CharacterExpression {
        lines.last(where: { $0.speakerID == character.id })?.expression ?? .neutral
    }

    private func handle(_ input: String) async {
        guard let command = commandParser.parse(input) else { return }

        do {
            let result = try await commandRouter.run(command)
            switch result {
            case .handled(let text, let expression):
                append(CharacterLine(
                    speakerID: characters.first?.id ?? "character_a",
                    text: text,
                    expression: expression
                ))
            case .passToConversation:
                if case .chat(let userInput) = command {
                    await requestConversation(for: userInput)
                }
            }
        } catch {
            append(CharacterLine(
                speakerID: characters.first?.id ?? "character_a",
                text: "うまく実行できませんでした。入力を少し変えて試してください。",
                expression: .sad
            ))
        }
    }

    private func requestConversation(for userInput: String) async {
        isThinking = true
        defer { isThinking = false }

        do {
            let generated = try await conversationService.generateReply(
                userInput: userInput,
                recentLines: lines,
                characters: characters
            )
            append(generated)
        } catch {
            append(CharacterLine(
                speakerID: characters.first?.id ?? "character_a",
                text: "会話生成でつまずきました。API設定を確認してください。",
                expression: .sad
            ))
        }
    }

    private func scheduleIdleBanter() {
        idleTimer?.invalidate()
        idleTimer = Timer.scheduledTimer(withTimeInterval: 90, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, !self.isThinking else { return }
                self.append(self.banterService.nextBanter(characters: self.characters))
            }
        }
    }

    private func scheduleHourlyAnnouncements() {
        hourlyTimer?.invalidate()
        hourlyTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.announceHourIfNeeded()
            }
        }
        announceHourIfNeeded()
    }

    private func announceHourIfNeeded(date: Date = Date()) {
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        guard components.minute == 0,
              let hour = components.hour,
              lastHourlyAnnouncement != hour,
              let character = characters.first else {
            return
        }

        lastHourlyAnnouncement = hour
        append(dayEventService.hourlyLine(on: date, character: character))
    }

    private func append(_ newLines: [CharacterLine]) {
        lines.append(contentsOf: newLines)
        trimHistory()
    }

    private func append(_ line: CharacterLine) {
        lines.append(line)
        trimHistory()
    }

    private func trimHistory() {
        if lines.count > 12 {
            lines.removeFirst(lines.count - 12)
        }
    }
}

@MainActor
final class DesktopAccessoryController {
    private let panel: DesktopAccessoryPanel

    init(state: CompanionAppState) {
        let visibleFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1280, height: 800)
        let size = NSSize(width: 700, height: 480)
        let origin = NSPoint(x: visibleFrame.maxX - size.width - 32, y: visibleFrame.minY + 24)

        panel = DesktopAccessoryPanel(
            contentRect: NSRect(origin: origin, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        panel.title = "伺か再現プロジェクト"
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.isMovableByWindowBackground = true
        panel.contentView = NSHostingView(rootView: CharacterStageView(state: state))
    }

    func show() {
        panel.orderFrontRegardless()
    }

    func hide() {
        panel.orderOut(nil)
    }
}

final class DesktopAccessoryPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

struct CharacterStageView: View {
    @ObservedObject var state: CompanionAppState

    var body: some View {
        VStack(spacing: 12) {
            SpeechBubbleView(state: state)
                .frame(maxWidth: 620)

            HStack(alignment: .bottom, spacing: 8) {
                ForEach(state.characters) { character in
                    CharacterView(
                        character: character,
                        expression: state.expression(for: character)
                    )
                }
            }
            .frame(height: 300)
        }
        .padding(18)
        .frame(width: 700, height: 480)
        .background(Color.clear)
    }
}

struct SpeechBubbleView: View {
    @ObservedObject var state: CompanionAppState

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(state.lines.suffix(3)) { line in
                    if let character = state.characters.first(where: { $0.id == line.speakerID }) {
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(character.displayName)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(character.accentColor)
                                .frame(width: 96, alignment: .leading)

                            Text(line.text)
                                .font(.system(size: 14))
                                .foregroundStyle(.primary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }

                if state.isThinking {
                    Text("考え中...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(minHeight: 86, alignment: .topLeading)

            HStack(spacing: 8) {
                TextField("話しかける / 検索: キーワード / 起動: Safari", text: $state.draftText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14))
                    .onSubmit {
                        state.submitDraft()
                    }

                Button {
                    state.submitDraft()
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 20))
                }
                .buttonStyle(.plain)
                .disabled(state.draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.white.opacity(0.72), in: Capsule())
        }
        .padding(16)
        .background(.regularMaterial, in: SpeechBubbleShape())
        .overlay {
            SpeechBubbleShape()
                .stroke(.white.opacity(0.7), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.16), radius: 18, y: 10)
    }
}

struct SpeechBubbleShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let radius: CGFloat = 22
        let tailWidth: CGFloat = 28
        let tailHeight: CGFloat = 18
        let bubbleRect = CGRect(
            x: rect.minX,
            y: rect.minY,
            width: rect.width,
            height: rect.height - tailHeight
        )

        path.addRoundedRect(in: bubbleRect, cornerSize: CGSize(width: radius, height: radius))
        path.move(to: CGPoint(x: bubbleRect.midX - tailWidth, y: bubbleRect.maxY - 1))
        path.addLine(to: CGPoint(x: bubbleRect.midX - 4, y: rect.maxY))
        path.addLine(to: CGPoint(x: bubbleRect.midX + tailWidth, y: bubbleRect.maxY - 1))
        path.closeSubpath()

        return path
    }
}

struct CharacterView: View {
    let character: CompanionCharacter
    let expression: CharacterExpression

    var body: some View {
        VStack(spacing: 6) {
            if let image = CharacterImageLoader.image(for: character, expression: expression) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 300, maxHeight: 290)
            } else {
                PlaceholderCharacterView(character: character, expression: expression)
                    .frame(width: 260, height: 290)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
    }
}

private struct PlaceholderCharacterView: View {
    let character: CompanionCharacter
    let expression: CharacterExpression

    var body: some View {
        ZStack {
            Capsule()
                .fill(character.accentColor.opacity(0.22))
                .frame(width: 150, height: 230)
                .offset(y: 30)

            Circle()
                .fill(character.accentColor.opacity(0.32))
                .frame(width: 112, height: 112)
                .offset(y: -78)

            expressionFace
                .offset(y: -78)

            Text(character.displayName)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(.regularMaterial, in: Capsule())
                .offset(y: 118)
        }
        .shadow(color: character.accentColor.opacity(0.24), radius: 18, y: 8)
    }

    @ViewBuilder
    private var expressionFace: some View {
        switch expression {
        case .neutral:
            FaceView(mouthCurve: 0, eyebrowTilt: 0)
        case .happy:
            FaceView(mouthCurve: 12, eyebrowTilt: 0)
        case .angry:
            FaceView(mouthCurve: -4, eyebrowTilt: -8)
        case .sad:
            FaceView(mouthCurve: -10, eyebrowTilt: 3)
        case .surprised:
            SurprisedFaceView()
        }
    }
}

private struct FaceView: View {
    let mouthCurve: CGFloat
    let eyebrowTilt: CGFloat

    var body: some View {
        ZStack {
            HStack(spacing: 28) {
                Circle().frame(width: 8, height: 8)
                Circle().frame(width: 8, height: 8)
            }
            .offset(y: -10)

            HStack(spacing: 20) {
                Capsule()
                    .frame(width: 22, height: 4)
                    .rotationEffect(.degrees(eyebrowTilt))
                Capsule()
                    .frame(width: 22, height: 4)
                    .rotationEffect(.degrees(-eyebrowTilt))
            }
            .offset(y: -28)

            Path { path in
                path.move(to: CGPoint(x: 72, y: 68))
                path.addQuadCurve(
                    to: CGPoint(x: 112, y: 68),
                    control: CGPoint(x: 92, y: 68 + mouthCurve)
                )
            }
            .stroke(.primary, style: StrokeStyle(lineWidth: 4, lineCap: .round))
            .frame(width: 184, height: 130)
        }
        .foregroundStyle(.primary.opacity(0.72))
    }
}

private struct SurprisedFaceView: View {
    var body: some View {
        ZStack {
            HStack(spacing: 28) {
                Circle().frame(width: 9, height: 9)
                Circle().frame(width: 9, height: 9)
            }
            .offset(y: -12)

            Circle()
                .stroke(lineWidth: 4)
                .frame(width: 20, height: 20)
                .offset(y: 18)
        }
        .foregroundStyle(.primary.opacity(0.72))
    }
}

enum CharacterImageLoader {
    static func image(for character: CompanionCharacter, expression: CharacterExpression) -> NSImage? {
        let baseNames = [
            "\(character.assetNamePrefix)_\(expression.rawValue)",
            character.assetNamePrefix
        ]
        let fileExtensions = ["png", "jpg", "jpeg"]

        for baseName in baseNames {
            for fileExtension in fileExtensions {
                if let url = Bundle.module.url(
                    forResource: baseName,
                    withExtension: fileExtension,
                    subdirectory: "Characters"
                ), let image = NSImage(contentsOf: url) {
                    return image
                }
            }
        }

        return nil
    }
}
