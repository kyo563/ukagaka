import Combine
import Foundation

enum OpenAIConnectionStatus: Equatable {
    case idle
    case checking(String)
    case success(String)
    case failure(String)
}

@MainActor
final class CompanionAppState: ObservableObject {
    @Published private(set) var characters: [CompanionCharacter]
    @Published private(set) var lines: [CharacterLine] = []
    @Published private(set) var conversationHistory: [ConversationTurn] = []
    @Published var draftText = ""
    @Published private(set) var isThinking = false
    @Published private(set) var isBubbleVisible = true
    @Published private(set) var availableModels: [String]
    @Published private(set) var connectionStatus: OpenAIConnectionStatus = .idle
    @Published private(set) var lastAPIError: String?

    let settings: CompanionSettings

    private let commandParser: CommandParser
    private let commandRouter: CommandRouter
    private let banterService: BanterService
    private let dayEventService: DayEventService
    private let activityMonitor: SystemActivityMonitor
    private var idleTimer: Timer?
    private var hourlyTimer: Timer?
    private var bubbleDismissTimer: Timer?
    private var lastHourlyAnnouncement: Int?
    private var lastAutomaticAIRequestAt: Date?
    private var validatedConnectionFingerprint: String?
    private var settingsObservers: Set<AnyCancellable> = []
    private var hasStarted = false
    private var conversationTask: Task<Void, Never>?

    init(
        settings: CompanionSettings,
        commandParser: CommandParser,
        commandRouter: CommandRouter,
        banterService: BanterService,
        dayEventService: DayEventService,
        activityMonitor: SystemActivityMonitor
    ) {
        self.settings = settings
        self.characters = CharacterProfiles.make(settings: settings)
        self.commandParser = commandParser
        self.commandRouter = commandRouter
        self.banterService = banterService
        self.dayEventService = dayEventService
        self.activityMonitor = activityMonitor
        self.availableModels = Self.initialModelList(settings.model)
        observeSettings()
    }

    static func bootstrap() -> CompanionAppState {
        CompanionAppState(
            settings: CompanionSettings(),
            commandParser: CommandParser(),
            commandRouter: CommandRouter(),
            banterService: BanterService(),
            dayEventService: DayEventService(),
            activityMonitor: SystemActivityMonitor()
        )
    }

    func start() {
        guard !hasStarted else { return }
        hasStarted = true
        lastAutomaticAIRequestAt = Date()
        append(dayEventService.openingLines(characters: characters))
        scheduleIdleBanter()
        scheduleHourlyAnnouncements()
    }

    func restorePersistedSettings() {
        settings.restoreForLaunch()
        availableModels = Self.initialModelList(settings.model)
        reloadCharacters(clearImageCache: true)
        if hasStarted {
            scheduleIdleBanter()
            scheduleBubbleDismissal()
        }
    }

    func saveSettingsForTermination() {
        settings.save()
        conversationTask?.cancel()
        idleTimer?.invalidate()
        hourlyTimer?.invalidate()
        bubbleDismissTimer?.invalidate()
    }

    func submitDraft() {
        guard !isThinking else { return }
        let input = draftText
        draftText = ""
        showBubble()

        conversationTask = Task {
            await handle(input)
        }
    }

    func expression(for character: CompanionCharacter) -> CharacterExpression {
        lines.last(where: { $0.speakerID == character.id })?.expression ?? .neutral
    }

    func gesture(for character: CompanionCharacter) -> CharacterGesture {
        lines.last(where: { $0.speakerID == character.id })?.gesture ?? .default
    }

    func showBubble() {
        isBubbleVisible = true
        scheduleBubbleDismissal()
    }

    func hideBubble() {
        bubbleDismissTimer?.invalidate()
        isBubbleVisible = false
    }

    func toggleClickThrough() {
        settings.setClickThrough(!settings.clickThrough)
    }

    func refreshAvailableModels(apiKey: String) async {
        guard let key = apiKey.trimmedNonEmpty else {
            connectionStatus = .failure("APIキーを入力してください。")
            return
        }

        connectionStatus = .checking("利用可能なモデルを取得しています...")
        do {
            let models = try await OpenAIModelService(apiKey: key).listModels()
            guard !models.isEmpty else {
                throw OpenAIResponsesError.invalidResponse
            }
            availableModels = models
            connectionStatus = .success("\(models.count)件のモデルを取得しました。")
        } catch {
            setAPIError(error)
        }
    }

    func testOpenAIConnection(apiKey: String, model: String) async -> Bool {
        guard let key = apiKey.trimmedNonEmpty else {
            connectionStatus = .failure("APIキーを入力してください。")
            return false
        }
        guard let selectedModel = model.trimmedNonEmpty else {
            connectionStatus = .failure("モデルを選択してください。")
            return false
        }

        connectionStatus = .checking("モデルとAPI接続を確認しています...")
        do {
            let modelService = OpenAIModelService(apiKey: key)
            let models = try await modelService.listModels()
            availableModels = models
            guard models.contains(selectedModel) else {
                throw OpenAIResponsesError.requestFailed(
                    statusCode: 404,
                    code: "model_not_found",
                    message: "選択したモデルはこのAPIキーで利用できません。"
                )
            }
            settings.recordAPIRequest(automatic: false)
            try await modelService.testConnection(model: selectedModel)
            validatedConnectionFingerprint = Self.connectionFingerprint(apiKey: key, model: selectedModel)
            lastAPIError = nil
            connectionStatus = .success("接続に成功しました。モデル: \(selectedModel)")
            return true
        } catch {
            setAPIError(error)
            return false
        }
    }

    func validateAndApplySettings(_ draft: CompanionSettingsDraft) async -> Bool {
        if let key = draft.apiKey.trimmedNonEmpty {
            guard let model = draft.model.trimmedNonEmpty else {
                connectionStatus = .failure("モデルを選択してください。")
                return false
            }
            let fingerprint = Self.connectionFingerprint(apiKey: key, model: model)
            if validatedConnectionFingerprint != fingerprint {
                guard await testOpenAIConnection(apiKey: key, model: model) else {
                    return false
                }
            } else if !availableModels.contains(model) {
                connectionStatus = .failure("選択したモデルは利用可能モデル一覧にありません。")
                return false
            }
        } else {
            connectionStatus = .idle
            validatedConnectionFingerprint = nil
        }

        let assetPathChanged = settings.characterAssetRootPath != draft.characterAssetRootPath
        settings.apply(draft)
        reloadCharacters(clearImageCache: assetPathChanged)
        scheduleIdleBanter()
        scheduleBubbleDismissal()
        if draft.apiKey.trimmedNonEmpty == nil {
            connectionStatus = .success("ローカル応答モードで保存しました。")
        } else {
            connectionStatus = .success("設定を保存しました。")
        }
        return true
    }

    func completeInitialSetup(with draft: CompanionSettingsDraft) async -> Bool {
        guard await validateAndApplySettings(draft) else { return false }
        settings.completeInitialSetup()
        return true
    }

    private func observeSettings() {
        Publishers.CombineLatest4(
            settings.$characterAName,
            settings.$characterBName,
            settings.$characterAPrompt,
            settings.$characterBPrompt
        )
        .dropFirst()
        .sink { [weak self] _ in self?.reloadCharacters(clearImageCache: false) }
        .store(in: &settingsObservers)

        settings.$characterAssetRootPath
            .dropFirst()
            .sink { [weak self] _ in self?.reloadCharacters(clearImageCache: true) }
            .store(in: &settingsObservers)

        settings.$idleBanterInterval
            .dropFirst()
            .sink { [weak self] _ in self?.scheduleIdleBanter() }
            .store(in: &settingsObservers)
    }

    private func reloadCharacters(clearImageCache: Bool) {
        if clearImageCache {
            CharacterImageLoader.clearCache()
        }
        characters = CharacterProfiles.make(settings: settings)
        CharacterImageLoader.preload(characters: characters)
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
            case .showToday:
                append(dayEventService.todayLines(characters: characters))
            case .passToConversation:
                if case .chat(let userInput) = command {
                    await requestConversation(for: userInput)
                }
            }
        } catch {
            append(CharacterLine(
                speakerID: characters.first?.id ?? "character_a",
                text: "操作を実行できませんでした: \(error.localizedDescription)",
                expression: .sad
            ))
        }
    }

    private func requestConversation(for userInput: String) async {
        guard !isThinking else { return }
        isThinking = true
        defer { isThinking = false }

        conversationHistory.append(ConversationTurn(role: .user, text: userInput))
        trimConversationHistory()

        do {
            if settings.isChatGPTEnabled {
                settings.recordAPIRequest(automatic: false)
            }
            let generated = try await conversationService().generateReply(
                userInput: userInput,
                recentTurns: conversationHistory,
                characters: characters
            )
            appendConversationLines(generated)
            lastAPIError = nil
        } catch {
            setAPIError(error)
            append(CharacterLine(
                speakerID: characters.first?.id ?? "character_a",
                text: OpenAIErrorPresenter.message(for: error),
                expression: .sad
            ))
        }
    }

    private func conversationService() -> ConversationGenerating {
        guard let apiKey = settings.apiKey.trimmedNonEmpty else {
            return LocalConversationService()
        }
        return OpenAIResponsesService(
            apiKey: apiKey,
            model: settings.model.trimmedNonEmpty ?? AppDefaults.openAIModel
        )
    }

    private func scheduleIdleBanter() {
        idleTimer?.invalidate()
        guard hasStarted else { return }
        let interval = min(
            max(settings.idleBanterInterval, AppDefaults.minimumIdleBanterInterval),
            AppDefaults.maximumIdleBanterInterval
        )
        idleTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, !self.isThinking else { return }
                await self.requestIdleBanter()
            }
        }
    }

    private func requestIdleBanter(date: Date = Date()) async {
        guard activityMonitor.allowsAutomaticBanter() else { return }

        let elapsed = lastAutomaticAIRequestAt.map { date.timeIntervalSince($0) } ?? .greatestFiniteMagnitude
        let shouldUseAI = settings.isChatGPTEnabled
            && settings.canUseAutomaticAI()
            && elapsed >= settings.automaticAIBanterInterval

        guard shouldUseAI else {
            append(banterService.nextBanter(characters: characters))
            return
        }

        isThinking = true
        defer { isThinking = false }
        lastAutomaticAIRequestAt = date
        settings.recordAPIRequest(automatic: true)

        do {
            let generated = try await conversationService().generateReply(
                userInput: "ユーザーは操作していません。設定された性格を守り、2人だけで短い小噺を始めてください。",
                recentTurns: conversationHistory,
                characters: characters
            )
            appendConversationLines(generated)
            lastAPIError = nil
        } catch {
            setAPIError(error)
            append(banterService.nextBanter(characters: characters))
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
        guard activityMonitor.allowsAutomaticBanter(),
              components.minute == 0,
              let hour = components.hour,
              lastHourlyAnnouncement != hour,
              let character = characters.first else {
            return
        }

        lastHourlyAnnouncement = hour
        append(dayEventService.hourlyLine(on: date, character: character))
    }

    private func appendConversationLines(_ newLines: [CharacterLine]) {
        append(newLines)
        conversationHistory.append(contentsOf: newLines.map {
            ConversationTurn(role: .character($0.speakerID), text: $0.text, createdAt: $0.createdAt)
        })
        trimConversationHistory()
    }

    private func append(_ newLines: [CharacterLine]) {
        lines.append(contentsOf: newLines)
        trimDisplayHistory()
        showBubble()
    }

    private func append(_ line: CharacterLine) {
        lines.append(line)
        trimDisplayHistory()
        showBubble()
    }

    private func scheduleBubbleDismissal() {
        bubbleDismissTimer?.invalidate()
        guard hasStarted, isBubbleVisible else { return }
        bubbleDismissTimer = Timer.scheduledTimer(
            withTimeInterval: settings.bubbleDisplayDuration,
            repeats: false
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self, !self.isThinking, self.draftText.isEmpty else { return }
                self.isBubbleVisible = false
            }
        }
    }

    private func setAPIError(_ error: Error) {
        let message = OpenAIErrorPresenter.message(for: error)
        lastAPIError = message
        connectionStatus = .failure(message)
    }

    private func trimDisplayHistory() {
        if lines.count > 12 {
            lines.removeFirst(lines.count - 12)
        }
    }

    private func trimConversationHistory() {
        if conversationHistory.count > 24 {
            conversationHistory.removeFirst(conversationHistory.count - 24)
        }
    }

    private static func initialModelList(_ selectedModel: String) -> [String] {
        var models = AppDefaults.selectableModels
        if !models.contains(selectedModel) {
            models.insert(selectedModel, at: 0)
        }
        return models
    }

    private static func connectionFingerprint(apiKey: String, model: String) -> String {
        "\(apiKey.hashValue):\(model)"
    }
}
