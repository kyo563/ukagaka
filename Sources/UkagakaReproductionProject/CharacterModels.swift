import Foundation
import SwiftUI

struct CompanionCharacter: Identifiable, Equatable {
    let id: String
    let displayName: String
    let assetNamePrefix: String
    let assetRootPath: String?
    let accentColor: Color
    let profilePrompt: String
}

enum CharacterExpression: String, Codable, CaseIterable {
    case neutral
    case happy
    case angry
    case sad
    case fun
    case sleep
}

enum CharacterGesture: String, Codable, CaseIterable {
    case `default`
    case wave
    case point
    case think
    case emphasize
    case sleep

    static func suggested(for expression: CharacterExpression) -> CharacterGesture {
        switch expression {
        case .happy:
            return .wave
        case .angry:
            return .emphasize
        case .sad:
            return .default
        case .fun:
            return .think
        case .sleep:
            return .sleep
        case .neutral:
            return .default
        }
    }
}

struct CharacterLine: Identifiable, Codable, Equatable {
    let id: UUID
    let speakerID: String
    let text: String
    let expression: CharacterExpression
    let gesture: CharacterGesture
    let createdAt: Date

    init(
        id: UUID = UUID(),
        speakerID: String,
        text: String,
        expression: CharacterExpression = .neutral,
        gesture: CharacterGesture? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.speakerID = speakerID
        self.text = text
        self.expression = expression
        self.gesture = gesture ?? CharacterGesture.suggested(for: expression)
        self.createdAt = createdAt
    }
}

enum ConversationRole: Equatable {
    case user
    case character(String)
}

struct ConversationTurn: Identifiable, Equatable {
    let id: UUID
    let role: ConversationRole
    let text: String
    let createdAt: Date

    init(
        id: UUID = UUID(),
        role: ConversationRole,
        text: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.role = role
        self.text = text
        self.createdAt = createdAt
    }
}

enum CharacterPromptDefaults {
    static let characterA = """
    あなたは人型のメインキャラクターAで、デスクトップ常駐コンシェルジュの主役です。
    観察力があり、落ち着いた口調で、ユーザーの作業をさりげなく助けます。
    返答は短く、左側にいるマスコットBとの掛け合いでは少しだけ茶目っ気を出します。
    """

    static let characterB = """
    あなたは左側に座るマスコットキャラクターBです。
    明るくテンポがよく、気づいたことを軽やかに話します。
    右側にいる人型のAの説明を補足しつつ、ユーザーが次に動きやすい一言を添えます。
    """
}

enum CharacterProfiles {
    @MainActor
    static func make(settings: CompanionSettings) -> [CompanionCharacter] {
        [
            CompanionCharacter(
                id: "character_a",
                displayName: settings.characterAName.trimmedNonEmpty ?? "キャラクターA",
                assetNamePrefix: "character_a",
                assetRootPath: settings.characterAssetRootPath.trimmedNonEmpty,
                accentColor: .teal,
                profilePrompt: settings.characterAPrompt.trimmedNonEmpty ?? CharacterPromptDefaults.characterA
            ),
            CompanionCharacter(
                id: "character_b",
                displayName: settings.characterBName.trimmedNonEmpty ?? "キャラクターB",
                assetNamePrefix: "character_b",
                assetRootPath: settings.characterAssetRootPath.trimmedNonEmpty,
                accentColor: .pink,
                profilePrompt: settings.characterBPrompt.trimmedNonEmpty ?? CharacterPromptDefaults.characterB
            )
        ]
    }
}
