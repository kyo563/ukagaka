import AppKit
import SwiftUI

struct CharacterView: View {
    let character: CompanionCharacter
    let expression: CharacterExpression
    let gesture: CharacterGesture
    let scale: Double
    let baseSize: CGSize

    var body: some View {
        VStack(spacing: 4) {
            if let sprite = CharacterImageLoader.sprite(for: character, expression: expression, gesture: gesture) {
                LayeredSpriteView(sprite: sprite)
                    .frame(width: baseSize.width * scale, height: baseSize.height * scale)
            } else {
                PlaceholderCharacterView(character: character, expression: expression)
                    .frame(width: baseSize.width * scale, height: baseSize.height * scale)
            }
        }
        .frame(maxHeight: .infinity, alignment: .bottom)
    }
}

struct CharacterSprite {
    let images: [NSImage]
}

private struct LayeredSpriteView: View {
    let sprite: CharacterSprite

    var body: some View {
        ZStack {
            ForEach(sprite.images.indices, id: \.self) { index in
                Image(nsImage: sprite.images[index])
                    .resizable()
                    .scaledToFit()
            }
        }
    }
}

private struct PlaceholderCharacterView: View {
    let character: CompanionCharacter
    let expression: CharacterExpression

    var body: some View {
        ZStack {
            Capsule()
                .fill(character.accentColor.opacity(0.22))
                .frame(width: 90, height: 130)
                .offset(y: 30)

            Circle()
                .fill(character.accentColor.opacity(0.32))
                .frame(width: 72, height: 72)
                .offset(y: -42)

            expressionFace
                .scaleEffect(0.65)
                .offset(y: -42)

            Text(character.displayName)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(.regularMaterial, in: Capsule())
                .offset(y: 72)
        }
        .shadow(color: character.accentColor.opacity(0.24), radius: 18, y: 8)
    }

    @ViewBuilder
    private var expressionFace: some View {
        switch expression {
        case .neutral:
            FaceView(mouthCurve: 0, eyebrowTilt: 0)
        case .happy:
            FaceView(mouthCurve: 12, eyebrowTilt: 0)
        case .angry:
            FaceView(mouthCurve: -4, eyebrowTilt: -8)
        case .sad:
            FaceView(mouthCurve: -10, eyebrowTilt: 3)
        case .fun:
            FunFaceView()
        case .sleep:
            SleepFaceView()
        }
    }
}

private struct FaceView: View {
    let mouthCurve: CGFloat
    let eyebrowTilt: CGFloat

    var body: some View {
        ZStack {
            HStack(spacing: 28) {
                Circle().frame(width: 8, height: 8)
                Circle().frame(width: 8, height: 8)
            }
            .offset(y: -10)

            HStack(spacing: 20) {
                Capsule()
                    .frame(width: 22, height: 4)
                    .rotationEffect(.degrees(eyebrowTilt))
                Capsule()
                    .frame(width: 22, height: 4)
                    .rotationEffect(.degrees(-eyebrowTilt))
            }
            .offset(y: -28)

            Path { path in
                path.move(to: CGPoint(x: 72, y: 68))
                path.addQuadCurve(
                    to: CGPoint(x: 112, y: 68),
                    control: CGPoint(x: 92, y: 68 + mouthCurve)
                )
            }
            .stroke(.primary, style: StrokeStyle(lineWidth: 4, lineCap: .round))
            .frame(width: 184, height: 130)
        }
        .foregroundStyle(.primary.opacity(0.72))
    }
}

private struct FunFaceView: View {
    var body: some View {
        ZStack {
            HStack(spacing: 28) {
                Capsule().frame(width: 22, height: 4)
                Capsule().frame(width: 22, height: 4)
            }
            .offset(y: -12)

            Path { path in
                path.move(to: CGPoint(x: 70, y: 66))
                path.addQuadCurve(to: CGPoint(x: 114, y: 66), control: CGPoint(x: 92, y: 86))
            }
            .stroke(.primary, style: StrokeStyle(lineWidth: 4, lineCap: .round))
            .frame(width: 184, height: 130)
        }
        .foregroundStyle(.primary.opacity(0.72))
    }
}

private struct SleepFaceView: View {
    var body: some View {
        ZStack {
            Text("Zzz")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .offset(x: 44, y: -38)

            FaceView(mouthCurve: -2, eyebrowTilt: 0)
        }
        .foregroundStyle(.primary.opacity(0.72))
    }
}
