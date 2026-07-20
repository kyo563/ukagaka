import AppKit
import Combine
import Foundation

struct CompanionSettingsDraft: Equatable {
    var apiKey: String
    var model: String
    var characterAName: String
    var characterBName: String
    var characterAPrompt: String
    var characterBPrompt: String
    var characterAssetRootPath: String
    var characterOpacity: Double
    var bubbleOpacity: Double
    var bubbleBackgroundOpacity: Double
    var characterAScale: Double
    var characterBScale: Double
    var idleBanterInterval: Double
    var aiIdleBanterEnabled: Bool
    var automaticAIBanterInterval: Double
    var automaticAIDailyLimit: Int
    var bubbleDisplayDuration: Double
    var clickThrough: Bool
    var alwaysOnTop: Bool
    var launchAtLogin: Bool

    @MainActor
    init(settings: CompanionSettings) {
        apiKey = settings.apiKey
        model = settings.model
        characterAName = settings.characterAName
        characterBName = settings.characterBName
        characterAPrompt = settings.characterAPrompt
        characterBPrompt = settings.characterBPrompt
        characterAssetRootPath = settings.characterAssetRootPath
        characterOpacity = settings.characterOpacity
        bubbleOpacity = settings.bubbleOpacity
        bubbleBackgroundOpacity = settings.bubbleBackgroundOpacity
        characterAScale = settings.characterAScale
        characterBScale = settings.characterBScale
        idleBanterInterval = settings.idleBanterInterval
        aiIdleBanterEnabled = settings.aiIdleBanterEnabled
        automaticAIBanterInterval = settings.automaticAIBanterInterval
        automaticAIDailyLimit = settings.automaticAIDailyLimit
        bubbleDisplayDuration = settings.bubbleDisplayDuration
        clickThrough = settings.clickThrough
        alwaysOnTop = settings.alwaysOnTop
        launchAtLogin = settings.launchAtLogin
    }
}

@MainActor
final class CompanionSettings: ObservableObject {
    private enum Keys {
        static let legacyAPIKey = "settings.openai.apiKey"
        static let keychainAPIKey = "openai-api-key"
        static let model = "settings.openai.model"
        static let characterAName = "settings.characterA.name"
        static let characterBName = "settings.characterB.name"
        static let characterAPrompt = "settings.characterA.prompt"
        static let characterBPrompt = "settings.characterB.prompt"
        static let characterAssetRootPath = "settings.characters.assetRootPath"
        static let legacyStageOpacity = "settings.stage.opacity"
        static let characterOpacity = "settings.characters.opacity"
        static let bubbleOpacity = "settings.bubble.opacity"
        static let bubbleBackgroundOpacity = "settings.bubble.backgroundOpacity"
        static let characterAScale = "settings.characterA.scale"
        static let characterBScale = "settings.characterB.scale"
        static let idleBanterInterval = "settings.idleBanter.interval"
        static let aiIdleBanterEnabled = "settings.idleBanter.aiEnabled"
        static let automaticAIBanterInterval = "settings.idleBanter.aiInterval"
        static let automaticAIDailyLimit = "settings.idleBanter.aiDailyLimit"
        static let bubbleDisplayDuration = "settings.bubble.displayDuration"
        static let clickThrough = "settings.window.clickThrough"
        static let alwaysOnTop = "settings.window.alwaysOnTop"
        static let launchAtLogin = "settings.lifecycle.launchAtLogin"
        static let didCompleteInitialSetup = "settings.initialSetup.completed"
        static let usageDate = "usage.api.date"
        static let dailyAPIRequestCount = "usage.api.daily.total"
        static let dailyAutomaticAPIRequestCount = "usage.api.daily.automatic"

        static let persisted = [
            legacyAPIKey, model, characterAName, characterBName, characterAPrompt,
            characterBPrompt, characterAssetRootPath, legacyStageOpacity,
            characterOpacity, bubbleOpacity, bubbleBackgroundOpacity,
            characterAScale, characterBScale, idleBanterInterval,
            aiIdleBanterEnabled, automaticAIBanterInterval,
            automaticAIDailyLimit, bubbleDisplayDuration, clickThrough,
            alwaysOnTop, launchAtLogin, didCompleteInitialSetup, usageDate,
            dailyAPIRequestCount, dailyAutomaticAPIRequestCount
        ]
    }

    private let defaults: UserDefaults
    private let credentialStore: CredentialStoring
    private let bundleIdentifier: String

    @Published private(set) var apiKey = ""
    @Published private(set) var model = AppDefaults.openAIModel
    @Published private(set) var characterAName = "キャラクターA"
    @Published private(set) var characterBName = "キャラクターB"
    @Published private(set) var characterAPrompt = CharacterPromptDefaults.characterA
    @Published private(set) var characterBPrompt = CharacterPromptDefaults.characterB
    @Published private(set) var characterAssetRootPath = ""
    @Published private(set) var characterOpacity = AppDefaults.characterOpacity
    @Published private(set) var bubbleOpacity = AppDefaults.bubbleOpacity
    @Published private(set) var bubbleBackgroundOpacity = AppDefaults.bubbleBackgroundOpacity
    @Published private(set) var characterAScale = AppDefaults.characterAScale
    @Published private(set) var characterBScale = AppDefaults.characterBScale
    @Published private(set) var idleBanterInterval = AppDefaults.idleBanterInterval
    @Published private(set) var aiIdleBanterEnabled = false
    @Published private(set) var automaticAIBanterInterval = AppDefaults.automaticAIBanterInterval
    @Published private(set) var automaticAIDailyLimit = AppDefaults.automaticAIDailyLimit
    @Published private(set) var bubbleDisplayDuration = AppDefaults.bubbleDisplayDuration
    @Published private(set) var clickThrough = false
    @Published private(set) var alwaysOnTop = true
    @Published private(set) var launchAtLogin = false
    @Published private(set) var didCompleteInitialSetup = false
    @Published private(set) var dailyAPIRequestCount = 0
    @Published private(set) var dailyAutomaticAPIRequestCount = 0
    @Published private(set) var launchAtLoginStatusMessage = LaunchAtLoginService.statusMessage
    @Published private(set) var credentialStatusMessage = "APIキーはmacOS Keychainに保存されます。"

    var isChatGPTEnabled: Bool {
        apiKey.trimmedNonEmpty != nil
    }

    init(
        defaults: UserDefaults = .standard,
        credentialStore: CredentialStoring = KeychainCredentialStore(),
        bundleIdentifier: String = Bundle.main.bundleIdentifier ?? AppDefaults.bundleIdentifier
    ) {
        self.defaults = defaults
        self.credentialStore = credentialStore
        self.bundleIdentifier = bundleIdentifier
        loadFromStorage(migrateLegacyAPIKey: true)
    }

    func apply(_ draft: CompanionSettingsDraft) {
        let shouldUpdateLoginItem = launchAtLogin != draft.launchAtLogin

        apiKey = draft.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        model = draft.model.trimmedNonEmpty ?? AppDefaults.openAIModel
        characterAName = draft.characterAName
        characterBName = draft.characterBName
        characterAPrompt = draft.characterAPrompt
        characterBPrompt = draft.characterBPrompt
        characterAssetRootPath = draft.characterAssetRootPath
        characterOpacity = clamped(draft.characterOpacity, lower: AppDefaults.minimumCharacterOpacity, upper: 1)
        bubbleOpacity = clamped(draft.bubbleOpacity, lower: AppDefaults.minimumBubbleOpacity, upper: 1)
        bubbleBackgroundOpacity = clamped(
            draft.bubbleBackgroundOpacity,
            lower: AppDefaults.minimumBubbleBackgroundOpacity,
            upper: 1
        )
        characterAScale = clamped(
            draft.characterAScale,
            lower: AppDefaults.minimumCharacterScale,
            upper: AppDefaults.maximumCharacterScale
        )
        characterBScale = clamped(
            draft.characterBScale,
            lower: AppDefaults.minimumCharacterScale,
            upper: AppDefaults.maximumCharacterScale
        )
        idleBanterInterval = clamped(
            draft.idleBanterInterval,
            lower: AppDefaults.minimumIdleBanterInterval,
            upper: AppDefaults.maximumIdleBanterInterval
        )
        aiIdleBanterEnabled = draft.aiIdleBanterEnabled
        automaticAIBanterInterval = clamped(
            draft.automaticAIBanterInterval,
            lower: AppDefaults.minimumAutomaticAIBanterInterval,
            upper: AppDefaults.maximumAutomaticAIBanterInterval
        )
        automaticAIDailyLimit = min(max(draft.automaticAIDailyLimit, 1), AppDefaults.maximumAutomaticAIDailyLimit)
        bubbleDisplayDuration = clamped(
            draft.bubbleDisplayDuration,
            lower: AppDefaults.minimumBubbleDisplayDuration,
            upper: AppDefaults.maximumBubbleDisplayDuration
        )
        clickThrough = draft.clickThrough
        alwaysOnTop = draft.alwaysOnTop
        launchAtLogin = draft.launchAtLogin
        save()

        if shouldUpdateLoginItem {
            launchAtLoginStatusMessage = LaunchAtLoginService.apply(enabled: launchAtLogin)
        }
    }

    func completeInitialSetup() {
        didCompleteInitialSetup = true
        save()
    }

    func restoreForLaunch() {
        loadFromStorage(migrateLegacyAPIKey: true)
        launchAtLoginStatusMessage = LaunchAtLoginService.reconcile(preferredEnabled: launchAtLogin)
    }

    func reload() {
        loadFromStorage(migrateLegacyAPIKey: true)
        launchAtLoginStatusMessage = LaunchAtLoginService.statusMessage
    }

    func save() {
        persistAPIKey()
        defaults.set(model, forKey: Keys.model)
        defaults.set(characterAName, forKey: Keys.characterAName)
        defaults.set(characterBName, forKey: Keys.characterBName)
        defaults.set(characterAPrompt, forKey: Keys.characterAPrompt)
        defaults.set(characterBPrompt, forKey: Keys.characterBPrompt)
        defaults.set(characterAssetRootPath, forKey: Keys.characterAssetRootPath)
        defaults.set(characterOpacity, forKey: Keys.characterOpacity)
        defaults.set(bubbleOpacity, forKey: Keys.bubbleOpacity)
        defaults.set(bubbleBackgroundOpacity, forKey: Keys.bubbleBackgroundOpacity)
        defaults.set(characterAScale, forKey: Keys.characterAScale)
        defaults.set(characterBScale, forKey: Keys.characterBScale)
        defaults.set(idleBanterInterval, forKey: Keys.idleBanterInterval)
        defaults.set(aiIdleBanterEnabled, forKey: Keys.aiIdleBanterEnabled)
        defaults.set(automaticAIBanterInterval, forKey: Keys.automaticAIBanterInterval)
        defaults.set(automaticAIDailyLimit, forKey: Keys.automaticAIDailyLimit)
        defaults.set(bubbleDisplayDuration, forKey: Keys.bubbleDisplayDuration)
        defaults.set(clickThrough, forKey: Keys.clickThrough)
        defaults.set(alwaysOnTop, forKey: Keys.alwaysOnTop)
        defaults.set(launchAtLogin, forKey: Keys.launchAtLogin)
        defaults.set(didCompleteInitialSetup, forKey: Keys.didCompleteInitialSetup)
        defaults.removeObject(forKey: Keys.legacyStageOpacity)
        defaults.synchronize()
    }

    func recordAPIRequest(automatic: Bool) {
        resetDailyUsageIfNeeded()
        dailyAPIRequestCount += 1
        if automatic {
            dailyAutomaticAPIRequestCount += 1
        }
        defaults.set(dailyAPIRequestCount, forKey: Keys.dailyAPIRequestCount)
        defaults.set(dailyAutomaticAPIRequestCount, forKey: Keys.dailyAutomaticAPIRequestCount)
    }

    func canUseAutomaticAI() -> Bool {
        resetDailyUsageIfNeeded()
        return aiIdleBanterEnabled && dailyAutomaticAPIRequestCount < automaticAIDailyLimit
    }

    func setClickThrough(_ enabled: Bool) {
        clickThrough = enabled
        defaults.set(enabled, forKey: Keys.clickThrough)
    }

    func chooseCharacterAssetRootPath() -> String? {
        let panel = NSOpenPanel()
        panel.title = "モデル画像フォルダを選択"
        panel.message = "character_a / character_b フォルダを含む場所、または Characters フォルダを選択してください。"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        return panel.runModal() == .OK ? panel.url?.path : nil
    }

    func openLoginItemsSettings() {
        LaunchAtLoginService.openSystemSettings()
    }

    func eraseAllStoredData() throws {
        try LaunchAtLoginService.unregisterForRemoval()
        try credentialStore.delete(key: Keys.keychainAPIKey)
        Keys.persisted.forEach(defaults.removeObject(forKey:))
        defaults.removePersistentDomain(forName: bundleIdentifier)
        defaults.synchronize()
        try removeAppOwnedFiles()
    }

    private func loadFromStorage(migrateLegacyAPIKey: Bool) {
        let legacyAPIKey = defaults.string(forKey: Keys.legacyAPIKey)?.trimmedNonEmpty
        do {
            if let storedAPIKey = try credentialStore.read(key: Keys.keychainAPIKey) {
                apiKey = storedAPIKey
            } else if migrateLegacyAPIKey, let legacyAPIKey {
                try credentialStore.write(legacyAPIKey, key: Keys.keychainAPIKey)
                apiKey = legacyAPIKey
                defaults.removeObject(forKey: Keys.legacyAPIKey)
                credentialStatusMessage = "既存のAPIキーをmacOS Keychainへ移行しました。"
            } else {
                apiKey = ""
            }
        } catch {
            apiKey = legacyAPIKey ?? ""
            credentialStatusMessage = error.localizedDescription
        }

        let storedModel = defaults.string(forKey: Keys.model)
        model = storedModel == "gpt-5.6-luna" ? AppDefaults.openAIModel : (storedModel ?? AppDefaults.openAIModel)
        characterAName = defaults.string(forKey: Keys.characterAName) ?? "キャラクターA"
        characterBName = defaults.string(forKey: Keys.characterBName) ?? "キャラクターB"
        characterAPrompt = defaults.string(forKey: Keys.characterAPrompt) ?? CharacterPromptDefaults.characterA
        characterBPrompt = defaults.string(forKey: Keys.characterBPrompt) ?? CharacterPromptDefaults.characterB
        characterAssetRootPath = defaults.string(forKey: Keys.characterAssetRootPath) ?? ""

        let legacyOpacity = storedDouble(forKey: Keys.legacyStageOpacity, fallback: AppDefaults.characterOpacity)
        characterOpacity = clamped(
            storedDouble(forKey: Keys.characterOpacity, fallback: legacyOpacity),
            lower: AppDefaults.minimumCharacterOpacity,
            upper: 1
        )
        bubbleOpacity = clamped(
            storedDouble(forKey: Keys.bubbleOpacity, fallback: AppDefaults.bubbleOpacity),
            lower: AppDefaults.minimumBubbleOpacity,
            upper: 1
        )
        bubbleBackgroundOpacity = clamped(
            storedDouble(forKey: Keys.bubbleBackgroundOpacity, fallback: AppDefaults.bubbleBackgroundOpacity),
            lower: AppDefaults.minimumBubbleBackgroundOpacity,
            upper: 1
        )
        characterAScale = clamped(
            storedDouble(forKey: Keys.characterAScale, fallback: AppDefaults.characterAScale),
            lower: AppDefaults.minimumCharacterScale,
            upper: AppDefaults.maximumCharacterScale
        )
        characterBScale = clamped(
            storedDouble(forKey: Keys.characterBScale, fallback: AppDefaults.characterBScale),
            lower: AppDefaults.minimumCharacterScale,
            upper: AppDefaults.maximumCharacterScale
        )
        idleBanterInterval = clamped(
            storedDouble(forKey: Keys.idleBanterInterval, fallback: AppDefaults.idleBanterInterval),
            lower: AppDefaults.minimumIdleBanterInterval,
            upper: AppDefaults.maximumIdleBanterInterval
        )
        aiIdleBanterEnabled = defaults.object(forKey: Keys.aiIdleBanterEnabled) == nil
            ? false
            : defaults.bool(forKey: Keys.aiIdleBanterEnabled)
        automaticAIBanterInterval = clamped(
            storedDouble(forKey: Keys.automaticAIBanterInterval, fallback: AppDefaults.automaticAIBanterInterval),
            lower: AppDefaults.minimumAutomaticAIBanterInterval,
            upper: AppDefaults.maximumAutomaticAIBanterInterval
        )
        automaticAIDailyLimit = min(
            max(storedInteger(forKey: Keys.automaticAIDailyLimit, fallback: AppDefaults.automaticAIDailyLimit), 1),
            AppDefaults.maximumAutomaticAIDailyLimit
        )
        bubbleDisplayDuration = clamped(
            storedDouble(forKey: Keys.bubbleDisplayDuration, fallback: AppDefaults.bubbleDisplayDuration),
            lower: AppDefaults.minimumBubbleDisplayDuration,
            upper: AppDefaults.maximumBubbleDisplayDuration
        )
        clickThrough = defaults.bool(forKey: Keys.clickThrough)
        alwaysOnTop = defaults.object(forKey: Keys.alwaysOnTop) == nil ? true : defaults.bool(forKey: Keys.alwaysOnTop)
        launchAtLogin = defaults.bool(forKey: Keys.launchAtLogin)
        didCompleteInitialSetup = defaults.bool(forKey: Keys.didCompleteInitialSetup)
        resetDailyUsageIfNeeded()
    }

    private func persistAPIKey() {
        do {
            if let value = apiKey.trimmedNonEmpty {
                try credentialStore.write(value, key: Keys.keychainAPIKey)
                credentialStatusMessage = "APIキーはmacOS Keychainに保存されています。"
            } else {
                try credentialStore.delete(key: Keys.keychainAPIKey)
                credentialStatusMessage = "APIキーは未設定です。"
            }
            defaults.removeObject(forKey: Keys.legacyAPIKey)
        } catch {
            credentialStatusMessage = error.localizedDescription
        }
    }

    private func resetDailyUsageIfNeeded() {
        let today = Self.usageDateFormatter.string(from: Date())
        if defaults.string(forKey: Keys.usageDate) != today {
            defaults.set(today, forKey: Keys.usageDate)
            defaults.set(0, forKey: Keys.dailyAPIRequestCount)
            defaults.set(0, forKey: Keys.dailyAutomaticAPIRequestCount)
        }
        dailyAPIRequestCount = defaults.integer(forKey: Keys.dailyAPIRequestCount)
        dailyAutomaticAPIRequestCount = defaults.integer(forKey: Keys.dailyAutomaticAPIRequestCount)
    }

    private func storedDouble(forKey key: String, fallback: Double) -> Double {
        guard defaults.object(forKey: key) != nil else { return fallback }
        let value = defaults.double(forKey: key)
        return value.isFinite ? value : fallback
    }

    private func storedInteger(forKey key: String, fallback: Int) -> Int {
        defaults.object(forKey: key) == nil ? fallback : defaults.integer(forKey: key)
    }

    private func clamped(_ value: Double, lower: Double, upper: Double) -> Double {
        min(max(value, lower), upper)
    }

    private func removeAppOwnedFiles() throws {
        let fileManager = FileManager.default
        var urls: [URL] = []

        if let applicationSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            urls.append(applicationSupport.appendingPathComponent(bundleIdentifier, isDirectory: true))
        }
        if let caches = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first {
            urls.append(caches.appendingPathComponent(bundleIdentifier, isDirectory: true))
        }
        if let library = fileManager.urls(for: .libraryDirectory, in: .userDomainMask).first {
            urls.append(
                library
                    .appendingPathComponent("Saved Application State", isDirectory: true)
                    .appendingPathComponent("\(bundleIdentifier).savedState", isDirectory: true)
            )
        }

        for url in urls where fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
        }
    }

    private static let usageDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = .current
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}
