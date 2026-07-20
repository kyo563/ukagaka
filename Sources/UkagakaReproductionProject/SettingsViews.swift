import SwiftUI

struct SettingsRootView: View {
    @ObservedObject var state: CompanionAppState
    @ObservedObject var settings: CompanionSettings
    let uninstall: () -> Void

    init(state: CompanionAppState, uninstall: @escaping () -> Void) {
        self.state = state
        self.settings = state.settings
        self.uninstall = uninstall
    }

    var body: some View {
        Form {
            Section("ChatGPT連携") {
                SecureField("OpenAI API Key", text: $settings.apiKey)
                TextField("モデル", text: $settings.model)
                Label(
                    settings.isChatGPTEnabled ? "APIキー設定済み" : "APIキー未設定: ローカル応答で動作します",
                    systemImage: settings.isChatGPTEnabled ? "checkmark.circle" : "exclamationmark.circle"
                )
                .foregroundStyle(settings.isChatGPTEnabled ? .green : .secondary)

                Text(settings.credentialStatusMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
                    }

                    Button("同梱画像に戻す") {
                        settings.clearCharacterAssetRootPath()
                    }
                    .disabled(settings.characterAssetRootPath.trimmedNonEmpty == nil)
                }

                Text("character_a / character_b フォルダを含む場所、または Characters フォルダを指定できます。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("表示と独り言") {
                VStack(alignment: .leading) {
                    Text("透過度: \(Int(settings.stageOpacity * 100))%")
                    Slider(
                        value: $settings.stageOpacity,
                        in: AppDefaults.minimumStageOpacity...1.0
                    )
                }

                VStack(alignment: .leading) {
                    Text("独り言の更新間隔: \(Int(settings.idleBanterInterval))秒")
                    Slider(
                        value: $settings.idleBanterInterval,
                        in: AppDefaults.minimumIdleBanterInterval...AppDefaults.maximumIdleBanterInterval,
                        step: 30
                    )
                }
            }

            Section("常駐と保存") {
                Toggle("ログイン時に自動起動", isOn: $settings.launchAtLogin)

                Label(settings.launchAtLoginStatusMessage, systemImage: "power.circle")
                    .foregroundStyle(.secondary)

                Button("ログイン項目のシステム設定を開く") {
                    settings.openLoginItemsSettings()
                }

                HStack {
                    Button("設定を保存") {
                        state.applySettingsChanges()
                    }

                    Button("保存済み設定を再読み込み") {
                        state.restorePersistedSettings()
                    }
                }
            }

            Section("アンインストール") {
                Text("ログイン時起動、保存設定、KeychainのAPIキーを削除し、アプリ本体をゴミ箱へ移動します。外部モデル画像は残ります。")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button("このMacからアンインストール...", role: .destructive) {
                    uninstall()
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .frame(minWidth: 560, idealWidth: 620, minHeight: 560, idealHeight: 700)
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

            Text("ChatGPT連携とキャラクターの性格を最初に設定します。APIキーは後から追加・変更できます。")
                .foregroundStyle(.secondary)

            GroupBox("ChatGPT連携") {
                VStack(alignment: .leading, spacing: 8) {
                    SecureField("OpenAI API Key", text: $settings.apiKey)
                    TextField("モデル", text: $settings.model)
                    Text(settings.isChatGPTEnabled ? "APIキーはmacOS Keychainに保存されます。" : "未設定でもローカル応答で試せます。")
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
                    finishSetup()
                }
                Button("開始") {
                    finishSetup()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 620)
    }

    private func finishSetup() {
        settings.completeInitialSetup()
        state.applySettingsChanges()
        onFinish()
    }
}
