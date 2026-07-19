import AppKit
import Combine
import Foundation

@MainActor
final class CompanionSettings: ObservableObject {
    private enum Keys {
        static let apiKey = "settings.openai.apiKey"
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
    }

    private let defaults: UserDefaults

    @Published var apiKey = "" {
        didSet { defaults.set(apiKey, forKey: Keys.apiKey) }
    }
    @Published var model = "gpt-5" {
        didSet { defaults.set(model, forKey: Keys.model) }
    }
    @Published var characterAName = "キャラクターA" {
        didSet { defaults.set(characterAName, forKey: Keys.characterAName) }
    }
    @Published var characterBName = "キャラクターB" {
        didSet { defaults.set(characterBName, forKey: Keys.characterBName) }
    }
    @Published var characterAPrompt = CharacterPromptDefaults.characterA {
        didSet { defaults.set(characterAPrompt, forKey: Keys.characterAPrompt) }
    }
    @Published var characterBPrompt = CharacterPromptDefaults.characterB {
        didSet { defaults.set(characterBPrompt, forKey: Keys.characterBPrompt) }
    }
    @Published var characterAssetRootPath = "" {
        didSet { defaults.set(characterAssetRootPath, forKey: Keys.characterAssetRootPath) }
    }
    @Published var stageOpacity = 1.0 {
        didSet { defaults.set(stageOpacity, forKey: Keys.stageOpacity) }
    }
    @Published var idleBanterInterval = 90.0 {
        didSet { defaults.set(idleBanterInterval, forKey: Keys.idleBanterInterval) }
    }
    @Published var launchAtLogin = false {
        didSet {
            defaults.set(launchAtLogin, forKey: Keys.launchAtLogin)
            launchAtLoginStatusMessage = LaunchAtLoginService.apply(enabled: launchAtLogin)
        }
    }
    @Published var didCompleteInitialSetup = false {
        didSet { defaults.set(didCompleteInitialSetup, forKey: Keys.didCompleteInitialSetup) }
    }
    @Published private(set) var launchAtLoginStatusMessage = LaunchAtLoginService.statusMessage

    var isChatGPTEnabled: Bool {
        apiKey.trimmedNonEmpty != nil
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        apiKey = defaults.string(forKey: Keys.apiKey) ?? ""
        model = defaults.string(forKey: Keys.model) ?? "gpt-5"
        characterAName = defaults.string(forKey: Keys.characterAName) ?? "キャラクターA"
        characterBName = defaults.string(forKey: Keys.characterBName) ?? "キャラクターB"
        characterAPrompt = defaults.string(forKey: Keys.characterAPrompt) ?? CharacterPromptDefaults.characterA
        characterBPrompt = defaults.string(forKey: Keys.characterBPrompt) ?? CharacterPromptDefaults.characterB
        characterAssetRootPath = defaults.string(forKey: Keys.characterAssetRootPath) ?? ""

        let storedOpacity = defaults.double(forKey: Keys.stageOpacity)
        stageOpacity = storedOpacity == 0 ? 1.0 : storedOpacity

        let storedInterval = defaults.double(forKey: Keys.idleBanterInterval)
        idleBanterInterval = storedInterval == 0 ? 90.0 : storedInterval

        launchAtLogin = defaults.bool(forKey: Keys.launchAtLogin)
        didCompleteInitialSetup = defaults.bool(forKey: Keys.didCompleteInitialSetup)
    }

    func completeInitialSetup() {
        didCompleteInitialSetup = true
        save()
    }

    func restoreForLaunch() {
        reload()
        launchAtLoginStatusMessage = LaunchAtLoginService.apply(enabled: launchAtLogin)
    }

    func reload() {
        apiKey = defaults.string(forKey: Keys.apiKey) ?? ""
        model = defaults.string(forKey: Keys.model) ?? "gpt-5"
        characterAName = defaults.string(forKey: Keys.characterAName) ?? "キャラクターA"
        characterBName = defaults.string(forKey: Keys.characterBName) ?? "キャラクターB"
        characterAPrompt = defaults.string(forKey: Keys.characterAPrompt) ?? CharacterPromptDefaults.characterA
        characterBPrompt = defaults.string(forKey: Keys.characterBPrompt) ?? CharacterPromptDefaults.characterB
        characterAssetRootPath = defaults.string(forKey: Keys.characterAssetRootPath) ?? ""

        let storedOpacity = defaults.double(forKey: Keys.stageOpacity)
        stageOpacity = storedOpacity == 0 ? 1.0 : storedOpacity

        let storedInterval = defaults.double(forKey: Keys.idleBanterInterval)
        idleBanterInterval = storedInterval == 0 ? 90.0 : storedInterval

        launchAtLogin = defaults.bool(forKey: Keys.launchAtLogin)
        didCompleteInitialSetup = defaults.bool(forKey: Keys.didCompleteInitialSetup)
        launchAtLoginStatusMessage = LaunchAtLoginService.statusMessage
    }

    func save() {
        defaults.set(apiKey, forKey: Keys.apiKey)
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
        synchronize()
    }

    func synchronize() {
        defaults.synchronize()
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
}
