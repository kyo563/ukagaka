import SwiftUI

struct SettingsRootView: View {
    @ObservedObject var state: CompanionAppState
    @ObservedObject var settings: CompanionSettings

    init(state: CompanionAppState) {
        self.state = state
        self.settings = state.settings
    }

    var body: some View {
        Form {
            Section("ChatGPT連携") {
                SecureField("OpenAI API Key", text: $settings.apiKey)
                TextField("モデル", text: $settings.model)
                Label(settings.isChatGPTEnabled ? "APIキー設定済み" : "APIキー未設定: ローカル応答で動作します", systemImage: settings.isChatGPTEnabled ? "checkmark.circle" : "exclamationmark.circle")
                    .foregroundStyle(settings.isChatGPTEnabled ? .green : .secondary)
            }

            Section("キャラクター") {
                TextField("キャラクターAの名前", text: $settings.characterAName)
                TextEditor(text: $settings.characterAPrompt)
                    .font(.system(size: 12))
                    .frame(height: 80)

                TextField("キャラクターBの名前", text: $settings.characterBName)
                TextEditor(text: $settings.characterBPrompt)
                    .font(.system(size: 12))
                    .frame(height: 80)
            }

            Section("モデル画像") {
                TextField("画像フォルダのパス", text: $settings.characterAssetRootPath)

                HStack {
                    Button("選択...") {
                        settings.selectCharacterAssetRootPath()
                        state.applySettingsChanges()
                    }

                    Button("同梱画像に戻す") {
                        settings.clearCharacterAssetRootPath()
                        state.applySettingsChanges()
                    }
                    .disabled(settings.characterAssetRootPath.trimmedNonEmpty == nil)
                }

                Text("character_a / character_b フォルダを含む場所、または Characters フォルダを指定できます。未指定の場合はアプリ同梱画像を使います。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("表示と独り言") {
                VStack(alignment: .leading) {
                    Text("透過度: \(Int(settings.stageOpacity * 100))%")
                    Slider(value: $settings.stageOpacity, in: 0.35...1.0)
                }

                VStack(alignment: .leading) {
                    Text("独り言の更新間隔: \(Int(settings.idleBanterInterval))秒")
                    Slider(value: $settings.idleBanterInterval, in: 30...300, step: 5)
                }
            }

            Section("常駐と保存") {
                Toggle("ログイン時に自動起動", isOn: $settings.launchAtLogin)

                Label(settings.launchAtLoginStatusMessage, systemImage: "power.circle")
                    .foregroundStyle(.secondary)

                HStack {
                    Button("設定を保存") {
                        settings.save()
                    }

                    Button("保存済み設定を再読み込み") {
                        state.restorePersistedSettings()
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .frame(width: 560)
        .onChange(of: settings.characterAName) { state.applySettingsChanges() }
        .onChange(of: settings.characterBName) { state.applySettingsChanges() }
        .onChange(of: settings.characterAPrompt) { state.applySettingsChanges() }
        .onChange(of: settings.characterBPrompt) { state.applySettingsChanges() }
        .onChange(of: settings.characterAssetRootPath) { state.applySettingsChanges() }
        .onChange(of: settings.idleBanterInterval) { state.applySettingsChanges() }
        .onChange(of: settings.launchAtLogin) { settings.save() }
    }
}

struct OnboardingView: View {
    @ObservedObject var state: CompanionAppState
    @ObservedObject var settings: CompanionSettings
    let onFinish: () -> Void

    init(state: CompanionAppState, onFinish: @escaping () -> Void) {
        self.state = state
        self.settings = state.settings
        self.onFinish = onFinish
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("伺か再現プロジェクト")
                .font(.largeTitle.weight(.semibold))

            Text("ChatGPT連携とキャラクターの性格を最初に軽く設定します。APIキーは後から設定画面で追加・変更できます。")
                .foregroundStyle(.secondary)

            GroupBox("ChatGPT連携") {
                VStack(alignment: .leading, spacing: 8) {
                    SecureField("OpenAI API Key", text: $settings.apiKey)
                    TextField("モデル", text: $settings.model)
                    Text(settings.isChatGPTEnabled ? "ChatGPT連携を使います。" : "未設定でもローカル応答で試せます。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }

            GroupBox("キャラクターの性格") {
                VStack(alignment: .leading, spacing: 8) {
                    TextField("キャラクターAの名前", text: $settings.characterAName)
                    TextEditor(text: $settings.characterAPrompt)
                        .font(.system(size: 12))
                        .frame(height: 72)

                    TextField("キャラクターBの名前", text: $settings.characterBName)
                    TextEditor(text: $settings.characterBPrompt)
                        .font(.system(size: 12))
                        .frame(height: 72)
                }
                .padding(.vertical, 4)
            }

            Toggle("ログイン時に自動起動", isOn: $settings.launchAtLogin)
                .toggleStyle(.checkbox)

            HStack {
                Spacer()
                Button("あとで設定") {
                    settings.completeInitialSetup()
                    state.applySettingsChanges()
                    onFinish()
                }
                Button("開始") {
                    settings.completeInitialSetup()
                    state.applySettingsChanges()
                    onFinish()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 620)
    }
}
