import Combine
import Foundation

@MainActor
final class CompanionAppState: ObservableObject {
    @Published private(set) var characters: [CompanionCharacter]
    @Published private(set) var lines: [CharacterLine] = []
    @Published var draftText = ""
    @Published private(set) var isThinking = false

    let settings: CompanionSettings

    private let commandParser: CommandParser
    private let commandRouter: CommandRouter
    private let banterService: BanterService
    private let dayEventService: DayEventService
    private var idleTimer: Timer?
    private var hourlyTimer: Timer?
    private var lastHourlyAnnouncement: Int?
    private var settingsObservers: Set<AnyCancellable> = []
    private var hasStarted = false

    init(
        settings: CompanionSettings,
        commandParser: CommandParser,
        commandRouter: CommandRouter,
        banterService: BanterService,
        dayEventService: DayEventService
    ) {
        self.settings = settings
        self.characters = CharacterProfiles.make(settings: settings)
        self.commandParser = commandParser
        self.commandRouter = commandRouter
        self.banterService = banterService
        self.dayEventService = dayEventService
        observeSettings()
    }

    static func bootstrap() -> CompanionAppState {
        CompanionAppState(
            settings: CompanionSettings(),
            commandParser: CommandParser(),
            commandRouter: CommandRouter(),
            banterService: BanterService(),
            dayEventService: DayEventService()
        )
    }

    func start() {
        guard !hasStarted else { return }
        hasStarted = true
        append(dayEventService.openingLines(characters: characters))
        scheduleIdleBanter()
        scheduleHourlyAnnouncements()
    }

    func restorePersistedSettings() {
        settings.restoreForLaunch()
        reloadCharacters()
        if hasStarted {
            scheduleIdleBanter()
        }
    }

    func saveSettingsForTermination() {
        settings.save()
        idleTimer?.invalidate()
        hourlyTimer?.invalidate()
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

    func gesture(for character: CompanionCharacter) -> CharacterGesture {
        lines.last(where: { $0.speakerID == character.id })?.gesture ?? .default
    }

    func applySettingsChanges() {
        settings.save()
        reloadCharacters()
        if hasStarted {
            scheduleIdleBanter()
        }
    }

    private func observeSettings() {
        settings.$characterAName
            .dropFirst()
            .sink { [weak self] _ in self?.reloadCharacters() }
            .store(in: &settingsObservers)

        settings.$characterBName
            .dropFirst()
            .sink { [weak self] _ in self?.reloadCharacters() }
            .store(in: &settingsObservers)

        settings.$characterAPrompt
            .dropFirst()
            .sink { [weak self] _ in self?.reloadCharacters() }
            .store(in: &settingsObservers)

        settings.$characterBPrompt
            .dropFirst()
            .sink { [weak self] _ in self?.reloadCharacters() }
            .store(in: &settingsObservers)

        settings.$characterAssetRootPath
            .dropFirst()
            .sink { [weak self] _ in self?.reloadCharacters() }
            .store(in: &settingsObservers)

        settings.$idleBanterInterval
            .dropFirst()
            .sink { [weak self] _ in self?.scheduleIdleBanter() }
            .store(in: &settingsObservers)
    }

    private func reloadCharacters() {
        characters = CharacterProfiles.make(settings: settings)
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
            let generated = try await conversationService().generateReply(
                userInput: userInput,
                recentLines: lines,
                characters: characters
            )
            append(generated)
        } catch {
            append(CharacterLine(
                speakerID: characters.first?.id ?? "character_a",
                text: "会話生成でつまずきました。APIキーやモデル名を設定画面で確認してください。",
                expression: .sad
            ))
        }
    }

    private func conversationService() -> ConversationGenerating {
        guard let apiKey = settings.apiKey.trimmedNonEmpty else {
            return LocalConversationService()
        }
        return OpenAIResponsesService(apiKey: apiKey, model: settings.model.trimmedNonEmpty ?? "gpt-5")
    }

    private func scheduleIdleBanter() {
        idleTimer?.invalidate()
        idleTimer = Timer.scheduledTimer(withTimeInterval: settings.idleBanterInterval, repeats: true) { [weak self] _ in
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
