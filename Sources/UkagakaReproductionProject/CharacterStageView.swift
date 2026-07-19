import SwiftUI

struct CharacterStageView: View {
    @ObservedObject var state: CompanionAppState
    let actions: CompanionWindowActions

    var body: some View {
        VStack(spacing: 12) {
            SpeechBubbleView(state: state)
                .frame(maxWidth: 620)

            HStack(alignment: .bottom, spacing: 8) {
                ForEach(state.characters) { character in
                    CharacterView(
                        character: character,
                        expression: state.expression(for: character),
                        gesture: state.gesture(for: character)
                    )
                }
            }
            .frame(height: 300)
        }
        .padding(18)
        .frame(width: 700, height: 480)
        .background(Color.clear)
        .opacity(state.settings.stageOpacity)
        .contextMenu {
            Button("設定") { actions.openSettings() }
            Button("隠す") { actions.hide() }
            Divider()
            Button("再起動") { actions.restart() }
            Button("終了") { actions.quit() }
        }
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
