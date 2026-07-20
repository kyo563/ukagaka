import AppKit
import Combine
import Foundation

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
        static let stageOpacity = "settings.stage.opacity"
        static let idleBanterInterval = "settings.idleBanter.interval"
        static let launchAtLogin = "settings.lifecycle.launchAtLogin"
        static let didCompleteInitialSetup = "settings.initialSetup.completed"

        static let persisted = [
            legacyAPIKey,
            model,
            characterAName,
            characterBName,
            characterAPrompt,
            characterBPrompt,
            characterAssetRootPath,
            stageOpacity,
            idleBanterInterval,
            launchAtLogin,
            didCompleteInitialSetup
        ]
    }

    private let defaults: UserDefaults
    private let credentialStore: CredentialStoring
    private let bundleIdentifier: String
    private var isRestoring = false

    @Published var apiKey = "" {
        didSet {
            guard !isRestoring else { return }
            persistAPIKey()
        }
    }
    @Published var model = AppDefaults.openAIModel {
        didSet { persist(model, key: Keys.model) }
    }
    @Published var characterAName = "キャラクターA" {
        didSet { persist(characterAName, key: Keys.characterAName) }
    }
    @Published var characterBName = "キャラクターB" {
        didSet { persist(characterBName, key: Keys.characterBName) }
    }
    @Published var characterAPrompt = CharacterPromptDefaults.characterA {
        didSet { persist(characterAPrompt, key: Keys.characterAPrompt) }
    }
    @Published var characterBPrompt = CharacterPromptDefaults.characterB {
        didSet { persist(characterBPrompt, key: Keys.characterBPrompt) }
    }
    @Published var characterAssetRootPath = "" {
        didSet { persist(characterAssetRootPath, key: Keys.characterAssetRootPath) }
    }
    @Published var stageOpacity = AppDefaults.stageOpacity {
        didSet { persist(stageOpacity, key: Keys.stageOpacity) }
    }
    @Published var idleBanterInterval = AppDefaults.idleBanterInterval {
        didSet { persist(idleBanterInterval, key: Keys.idleBanterInterval) }
    }
    @Published var launchAtLogin = false {
        didSet {
            guard !isRestoring else { return }
            defaults.set(launchAtLogin, forKey: Keys.launchAtLogin)
            launchAtLoginStatusMessage = LaunchAtLoginService.apply(enabled: launchAtLogin)
        }
    }
    @Published var didCompleteInitialSetup = false {
        didSet { persist(didCompleteInitialSetup, key: Keys.didCompleteInitialSetup) }
    }
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
        defaults.set(stageOpacity, forKey: Keys.stageOpacity)
        defaults.set(idleBanterInterval, forKey: Keys.idleBanterInterval)
        defaults.set(launchAtLogin, forKey: Keys.launchAtLogin)
        defaults.set(didCompleteInitialSetup, forKey: Keys.didCompleteInitialSetup)
        defaults.synchronize()
    }

    func eraseAllStoredData() throws {
        try LaunchAtLoginService.unregisterForRemoval()
        try credentialStore.delete(key: Keys.keychainAPIKey)
        Keys.persisted.forEach(defaults.removeObject(forKey:))
        defaults.removePersistentDomain(forName: bundleIdentifier)
        defaults.synchronize()
        try removeAppOwnedFiles()
    }

    func selectCharacterAssetRootPath() {
        let panel = NSOpenPanel()
        panel.title = "モデル画像フォルダを選択"
        panel.message = "character_a / character_b フォルダを含む場所、または Characters フォルダを選択してください。"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false

        if panel.runModal() == .OK, let url = panel.url {
            characterAssetRootPath = url.path
        }
    }

    func clearCharacterAssetRootPath() {
        characterAssetRootPath = ""
    }

    func openLoginItemsSettings() {
        LaunchAtLoginService.openSystemSettings()
    }

    private func loadFromStorage(migrateLegacyAPIKey: Bool) {
        isRestoring = true
        defer { isRestoring = false }

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

        model = defaults.string(forKey: Keys.model) ?? AppDefaults.openAIModel
        characterAName = defaults.string(forKey: Keys.characterAName) ?? "キャラクターA"
        characterBName = defaults.string(forKey: Keys.characterBName) ?? "キャラクターB"
        characterAPrompt = defaults.string(forKey: Keys.characterAPrompt) ?? CharacterPromptDefaults.characterA
        characterBPrompt = defaults.string(forKey: Keys.characterBPrompt) ?? CharacterPromptDefaults.characterB
        characterAssetRootPath = defaults.string(forKey: Keys.characterAssetRootPath) ?? ""

        stageOpacity = clamped(
            storedDouble(forKey: Keys.stageOpacity, fallback: AppDefaults.stageOpacity),
            lower: AppDefaults.minimumStageOpacity,
            upper: 1.0
        )
        idleBanterInterval = clamped(
            storedDouble(forKey: Keys.idleBanterInterval, fallback: AppDefaults.idleBanterInterval),
            lower: AppDefaults.minimumIdleBanterInterval,
            upper: AppDefaults.maximumIdleBanterInterval
        )
        launchAtLogin = defaults.bool(forKey: Keys.launchAtLogin)
        didCompleteInitialSetup = defaults.bool(forKey: Keys.didCompleteInitialSetup)
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

    private func persist(_ value: Any, key: String) {
        guard !isRestoring else { return }
        defaults.set(value, forKey: key)
    }

    private func storedDouble(forKey key: String, fallback: Double) -> Double {
        guard defaults.object(forKey: key) != nil else { return fallback }
        let value = defaults.double(forKey: key)
        return value.isFinite ? value : fallback
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
}
