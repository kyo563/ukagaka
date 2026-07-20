import SwiftUI

struct CharacterStageView: View {
    @ObservedObject var state: CompanionAppState
    @ObservedObject private var settings: CompanionSettings
    let actions: CompanionWindowActions

    init(state: CompanionAppState, actions: CompanionWindowActions) {
        self.state = state
        self.settings = state.settings
        self.actions = actions
    }

    var body: some View {
        VStack(spacing: 6) {
            if state.isBubbleVisible {
                SpeechBubbleView(state: state)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }

            HStack(alignment: .bottom, spacing: 8) {
                if let mascotCharacter {
                    CharacterView(
                        character: mascotCharacter,
                        expression: state.expression(for: mascotCharacter),
                        gesture: state.gesture(for: mascotCharacter),
                        scale: settings.characterBScale,
                        baseSize: CGSize(width: 145, height: 155)
                    )
                }

                if let mainCharacter {
                    CharacterView(
                        character: mainCharacter,
                        expression: state.expression(for: mainCharacter),
                        gesture: state.gesture(for: mainCharacter),
                        scale: settings.characterAScale,
                        baseSize: CGSize(width: 205, height: 225)
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .opacity(settings.characterOpacity)
            .contentShape(Rectangle())
            .onTapGesture {
                state.showBubble()
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .frame(
            width: DesktopPanelMetrics.width(
                characterAScale: settings.characterAScale,
                characterBScale: settings.characterBScale
            ),
            height: DesktopPanelMetrics.height(
                characterAScale: settings.characterAScale,
                characterBScale: settings.characterBScale,
                bubbleVisible: state.isBubbleVisible
            )
        )
        .background(Color.clear)
        .animation(.easeInOut(duration: 0.2), value: state.isBubbleVisible)
        .contextMenu {
            Button(state.isBubbleVisible ? "吹き出しを閉じる" : "吹き出しを表示") {
                state.isBubbleVisible ? state.hideBubble() : state.showBubble()
            }
            Button("設定") { actions.openSettings() }
            Button("隠す") { actions.hide() }
            Divider()
            Button("クリック透過を切り替え") { actions.toggleClickThrough() }
            Button("再起動") { actions.restart() }
            Button("終了") { actions.quit() }
            Divider()
            Button("アンインストール...", role: .destructive) { actions.uninstall() }
        }
    }

    private var mainCharacter: CompanionCharacter? {
        state.characters.first(where: { $0.id == "character_a" })
    }

    private var mascotCharacter: CompanionCharacter? {
        state.characters.first(where: { $0.id == "character_b" })
    }
}

struct SpeechBubbleView: View {
    @ObservedObject var state: CompanionAppState
    @ObservedObject private var settings: CompanionSettings

    init(state: CompanionAppState) {
        self.state = state
        self.settings = state.settings
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(state.lines.suffix(2)) { line in
                    if let character = state.characters.first(where: { $0.id == line.speakerID }) {
                        HStack(alignment: .firstTextBaseline, spacing: 7) {
                            Text(character.displayName)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(character.accentColor)
                                .frame(width: 76, alignment: .leading)

                            Text(line.text)
                                .font(.system(size: 13))
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
            .frame(minHeight: 44, alignment: .topLeading)

            HStack(spacing: 7) {
                TextField("話しかける / 検索 / アプリ起動", text: $state.draftText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .onSubmit {
                        state.submitDraft()
                    }

                Button {
                    state.submitDraft()
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 19))
                }
                .buttonStyle(.plain)
                .disabled(state.draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(.thinMaterial, in: Capsule())
            .overlay {
                Capsule().stroke(.secondary.opacity(0.24), lineWidth: 1)
            }
        }
        .padding(12)
        .background {
            SpeechBubbleShape()
                .fill(Color(nsColor: .windowBackgroundColor).opacity(settings.bubbleBackgroundOpacity))
                .background(.regularMaterial, in: SpeechBubbleShape())
        }
        .overlay {
            SpeechBubbleShape()
                .stroke(.primary.opacity(0.12), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.14), radius: 12, y: 6)
        .opacity(settings.bubbleOpacity)
    }
}

struct SpeechBubbleShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let radius: CGFloat = 14
        let tailWidth: CGFloat = 20
        let tailHeight: CGFloat = 12
        let bubbleRect = CGRect(
            x: rect.minX,
            y: rect.minY,
            width: rect.width,
            height: rect.height - tailHeight
        )

        path.addRoundedRect(in: bubbleRect, cornerSize: CGSize(width: radius, height: radius))
        path.move(to: CGPoint(x: bubbleRect.midX - tailWidth, y: bubbleRect.maxY - 1))
        path.addLine(to: CGPoint(x: bubbleRect.midX - 3, y: rect.maxY))
        path.addLine(to: CGPoint(x: bubbleRect.midX + tailWidth, y: bubbleRect.maxY - 1))
        path.closeSubpath()
        return path
    }
}
