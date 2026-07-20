import Foundation

enum AppDefaults {
    static let bundleIdentifier = "jp.kyo563.ukagaka-reproduction-project"
    static let openAIModel = "gpt-5-mini"
    static let selectableModels = ["gpt-5-mini", "gpt-5-nano", "gpt-5.1"]
    static let characterOpacity = 1.0
    static let bubbleOpacity = 1.0
    static let bubbleBackgroundOpacity = 0.88
    static let characterAScale = 1.0
    static let characterBScale = 1.0
    static let idleBanterInterval = 300.0
    static let automaticAIBanterInterval = 3_600.0
    static let automaticAIDailyLimit = 12
    static let bubbleDisplayDuration = 15.0

    static let minimumCharacterOpacity = 0.35
    static let minimumBubbleOpacity = 0.5
    static let minimumBubbleBackgroundOpacity = 0.55
    static let minimumCharacterScale = 0.5
    static let maximumCharacterScale = 1.5
    static let minimumIdleBanterInterval = 180.0
    static let maximumIdleBanterInterval = 600.0
    static let minimumAutomaticAIBanterInterval = 1_800.0
    static let maximumAutomaticAIBanterInterval = 3_600.0
    static let maximumAutomaticAIDailyLimit = 48
    static let minimumBubbleDisplayDuration = 5.0
    static let maximumBubbleDisplayDuration = 60.0

}

enum DesktopPanelMetrics {
    static func width(characterAScale: Double, characterBScale: Double) -> Double {
        max(360, (205 * characterAScale) + (145 * characterBScale) + 48)
    }

    static func characterContentHeight(characterAScale: Double, characterBScale: Double) -> Double {
        max(225 * characterAScale, 155 * characterBScale) + 24
    }

    static func height(characterAScale: Double, characterBScale: Double, bubbleVisible: Bool) -> Double {
        let characterHeight = characterContentHeight(
            characterAScale: characterAScale,
            characterBScale: characterBScale
        )
        return characterHeight + (bubbleVisible ? 142 : 12)
    }
}
