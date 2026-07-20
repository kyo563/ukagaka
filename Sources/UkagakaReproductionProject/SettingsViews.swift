import SwiftUI

struct SettingsRootView: View {
    @ObservedObject var state: CompanionAppState
    @ObservedObject var settings: CompanionSettings
    @State private var draft: CompanionSettingsDraft
    @State private var isSaving = false
    let uninstall: () -> Void

    init(state: CompanionAppState, uninstall: @escaping () -> Void) {
        self.state = state
        self.settings = state.settings
        self._draft = State(initialValue: CompanionSettingsDraft(settings: state.settings))
        self.uninstall = uninstall
    }

    var body: some View {
        Form {
            Section("ChatGPT連携") {
                SecureField("OpenAI API Key", text: $draft.apiKey)

                Picker("モデル", selection: $draft.model) {
                    ForEach(state.availableModels, id: \.self) { model in
                        Text(model).tag(model)
                    }
                }
                .pickerStyle(.menu)

                HStack {
                    Button("モデル一覧を取得") {
                        Task { await state.refreshAvailableModels(apiKey: draft.apiKey) }
                    }
                    Button("接続テスト") {
                        Task {
                            _ = await state.testOpenAIConnection(apiKey: draft.apiKey, model: draft.model)
                        }
                    }
                    .disabled(draft.apiKey.trimmedNonEmpty == nil || draft.model.trimmedNonEmpty == nil)
                }

                ConnectionStatusView(status: state.connectionStatus)

                Text("APIキーとモデルは「設定を保存」を押すまで反映されません。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("キャラクター") {
                TextField("人型キャラクターAの名前", text: $draft.characterAName)
                TextEditor(text: $draft.characterAPrompt)
                    .font(.system(size: 12))
                    .frame(height: 74)

                TextField("マスコットBの名前", text: $draft.characterBName)
                TextEditor(text: $draft.characterBPrompt)
                    .font(.system(size: 12))
                    .frame(height: 74)
            }

            Section("モデル画像") {
                TextField("画像フォルダのパス", text: $draft.characterAssetRootPath)
                HStack {
                    Button("選択...") {
                        if let path = settings.chooseCharacterAssetRootPath() {
                            draft.characterAssetRootPath = path
                        }
                    }
                    Button("同梱画像に戻す") {
                        draft.characterAssetRootPath = ""
                    }
                    .disabled(draft.characterAssetRootPath.trimmedNonEmpty == nil)
                }
            }

            Section("キャラクター表示") {
                SettingSlider(
                    title: "キャラクター透過度",
                    value: $draft.characterOpacity,
                    range: AppDefaults.minimumCharacterOpacity...1,
                    display: { "\(Int($0 * 100))%" }
                )
                SettingSlider(
                    title: "Aのサイズ",
                    value: $draft.characterAScale,
                    range: AppDefaults.minimumCharacterScale...AppDefaults.maximumCharacterScale,
                    display: { "\(Int($0 * 100))%" }
                )
                SettingSlider(
                    title: "Bのサイズ",
                    value: $draft.characterBScale,
                    range: AppDefaults.minimumCharacterScale...AppDefaults.maximumCharacterScale,
                    display: { "\(Int($0 * 100))%" }
                )
            }

            Section("吹き出し") {
                SettingSlider(
                    title: "吹き出し透過度",
                    value: $draft.bubbleOpacity,
                    range: AppDefaults.minimumBubbleOpacity...1,
                    display: { "\(Int($0 * 100))%" }
                )
                SettingSlider(
                    title: "背景の濃さ",
                    value: $draft.bubbleBackgroundOpacity,
                    range: AppDefaults.minimumBubbleBackgroundOpacity...1,
                    display: { "\(Int($0 * 100))%" }
                )
                SettingSlider(
                    title: "自動で閉じるまで",
                    value: $draft.bubbleDisplayDuration,
                    range: AppDefaults.minimumBubbleDisplayDuration...AppDefaults.maximumBubbleDisplayDuration,
                    step: 5,
                    display: { "\(Int($0))秒" }
                )
            }

            Section("独り言とAPI利用") {
                SettingSlider(
                    title: "定型会話の間隔",
                    value: $draft.idleBanterInterval,
                    range: AppDefaults.minimumIdleBanterInterval...AppDefaults.maximumIdleBanterInterval,
                    step: 60,
                    display: { "\(Int($0 / 60))分" }
                )

                Toggle("AIで独り言を生成", isOn: $draft.aiIdleBanterEnabled)

                if draft.aiIdleBanterEnabled {
                    SettingSlider(
                        title: "AI独り言の最短間隔",
                        value: $draft.automaticAIBanterInterval,
                        range: AppDefaults.minimumAutomaticAIBanterInterval...AppDefaults.maximumAutomaticAIBanterInterval,
                        step: 300,
                        display: { "\(Int($0 / 60))分" }
                    )
                    Stepper(
                        "AI独り言の1日上限: \(draft.automaticAIDailyLimit)回",
                        value: $draft.automaticAIDailyLimit,
                        in: 1...AppDefaults.maximumAutomaticAIDailyLimit
                    )
                }

                LabeledContent("本日のAPIリクエスト", value: "\(settings.dailyAPIRequestCount)回")
                LabeledContent("うちAI独り言", value: "\(settings.dailyAutomaticAPIRequestCount)回")
            }

            Section("デスクトップ動作") {
                Toggle("クリックを透過する", isOn: $draft.clickThrough)
                Toggle("常に手前に表示", isOn: $draft.alwaysOnTop)
                Toggle("ログイン時に自動起動", isOn: $draft.launchAtLogin)

                Label(settings.launchAtLoginStatusMessage, systemImage: "power.circle")
                    .foregroundStyle(.secondary)

                Button("ログイン項目のシステム設定を開く") {
                    settings.openLoginItemsSettings()
                }
            }

            if let error = state.lastAPIError {
                Section("直近のAPIエラー") {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                        .textSelection(.enabled)
                }
            }

            Section("設定") {
                HStack {
                    Button("設定を保存") {
                        saveDraft()
                    }
                    .keyboardShortcut(.defaultAction)
                    .disabled(isSaving)

                    Button("保存済み設定を再読み込み") {
                        state.restorePersistedSettings()
                        draft = CompanionSettingsDraft(settings: settings)
                    }
                    .disabled(isSaving)

                    if isSaving {
                        ProgressView().controlSize(.small)
                    }
                }
            }

            Section("アンインストール") {
                Button("このMacからアンインストール...", role: .destructive) {
                    uninstall()
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .frame(minWidth: 620, idealWidth: 700, minHeight: 680, idealHeight: 820)
    }

    private func saveDraft() {
        isSaving = true
        Task {
            let saved = await state.validateAndApplySettings(draft)
            if saved {
                draft = CompanionSettingsDraft(settings: settings)
            }
            isSaving = false
        }
    }
}

struct OnboardingView: View {
    @ObservedObject var state: CompanionAppState
    @ObservedObject var settings: CompanionSettings
    @State private var draft: CompanionSettingsDraft
    @State private var isSaving = false
    let onFinish: () -> Void

    init(state: CompanionAppState, onFinish: @escaping () -> Void) {
        self.state = state
        self.settings = state.settings
        self._draft = State(initialValue: CompanionSettingsDraft(settings: state.settings))
        self.onFinish = onFinish
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("伺か再現プロジェクト")
                .font(.largeTitle.weight(.semibold))

            GroupBox("ChatGPT連携") {
                VStack(alignment: .leading, spacing: 8) {
                    SecureField("OpenAI API Key", text: $draft.apiKey)
                    Picker("モデル", selection: $draft.model) {
                        ForEach(state.availableModels, id: \.self) { model in
                            Text(model).tag(model)
                        }
                    }
                    .pickerStyle(.menu)

                    HStack {
                        Button("モデル一覧を取得") {
                            Task { await state.refreshAvailableModels(apiKey: draft.apiKey) }
                        }
                        Button("接続テスト") {
                            Task {
                                _ = await state.testOpenAIConnection(apiKey: draft.apiKey, model: draft.model)
                            }
                        }
                        .disabled(draft.apiKey.trimmedNonEmpty == nil)
                    }
                    ConnectionStatusView(status: state.connectionStatus)
                }
                .padding(.vertical, 4)
            }

            GroupBox("キャラクター") {
                VStack(alignment: .leading, spacing: 8) {
                    TextField("人型キャラクターAの名前", text: $draft.characterAName)
                    TextEditor(text: $draft.characterAPrompt)
                        .font(.system(size: 12))
                        .frame(height: 70)

                    TextField("マスコットBの名前", text: $draft.characterBName)
                    TextEditor(text: $draft.characterBPrompt)
                        .font(.system(size: 12))
                        .frame(height: 70)
                }
                .padding(.vertical, 4)
            }

            Toggle("ログイン時に自動起動", isOn: $draft.launchAtLogin)
                .toggleStyle(.checkbox)

            HStack {
                Spacer()
                Button("API連携なしで開始") {
                    draft.apiKey = ""
                    finishSetup()
                }
                Button("開始") {
                    finishSetup()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(isSaving)

                if isSaving {
                    ProgressView().controlSize(.small)
                }
            }
        }
        .padding(24)
        .frame(width: 680)
    }

    private func finishSetup() {
        isSaving = true
        Task {
            if await state.completeInitialSetup(with: draft) {
                onFinish()
            }
            isSaving = false
        }
    }
}

private struct ConnectionStatusView: View {
    let status: OpenAIConnectionStatus

    var body: some View {
        switch status {
        case .idle:
            EmptyView()
        case .checking(let message):
            Label(message, systemImage: "arrow.triangle.2.circlepath")
                .font(.caption)
                .foregroundStyle(.secondary)
        case .success(let message):
            Label(message, systemImage: "checkmark.circle")
                .font(.caption)
                .foregroundStyle(.green)
        case .failure(let message):
            Label(message, systemImage: "exclamationmark.triangle")
                .font(.caption)
                .foregroundStyle(.red)
        }
    }
}

private struct SettingSlider: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    var step: Double?
    let display: (Double) -> String

    init(
        title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double? = nil,
        display: @escaping (Double) -> String
    ) {
        self.title = title
        self._value = value
        self.range = range
        self.step = step
        self.display = display
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            LabeledContent(title, value: display(value))
            if let step {
                Slider(value: $value, in: range, step: step)
            } else {
                Slider(value: $value, in: range)
            }
        }
    }
}
