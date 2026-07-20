import XCTest
@testable import UkagakaReproductionProject

@MainActor
final class CompanionSettingsTests: XCTestCase {
    func testFreshSettingsUseSafeDefaults() {
        let suiteName = "CompanionSettingsTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let settings = CompanionSettings(
            defaults: defaults,
            credentialStore: MemoryCredentialStore()
        )

        XCTAssertEqual(settings.model, "gpt-5-mini")
        XCTAssertFalse(settings.aiIdleBanterEnabled)
        XCTAssertEqual(settings.idleBanterInterval, 300)
        XCTAssertEqual(settings.automaticAIBanterInterval, 3_600)
        XCTAssertEqual(settings.automaticAIDailyLimit, 12)
    }

    func testMigratesLegacyAPIKeyToCredentialStore() throws {
        let suiteName = "CompanionSettingsTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set("legacy-key", forKey: "settings.openai.apiKey")
        let credentials = MemoryCredentialStore()

        let settings = CompanionSettings(defaults: defaults, credentialStore: credentials)

        XCTAssertEqual(settings.apiKey, "legacy-key")
        XCTAssertNil(defaults.string(forKey: "settings.openai.apiKey"))
        XCTAssertEqual(try credentials.read(key: "openai-api-key"), "legacy-key")
    }

    func testClampsCorruptDisplayAndTimerValues() {
        let suiteName = "CompanionSettingsTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set(-20, forKey: "settings.stage.opacity")
        defaults.set(9_999, forKey: "settings.idleBanter.interval")

        let settings = CompanionSettings(
            defaults: defaults,
            credentialStore: MemoryCredentialStore()
        )

        XCTAssertEqual(settings.characterOpacity, AppDefaults.minimumCharacterOpacity)
        XCTAssertEqual(settings.idleBanterInterval, AppDefaults.maximumIdleBanterInterval)
    }

    func testMigratesPreviousDefaultModelToMini() {
        let suiteName = "CompanionSettingsTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set("gpt-5.6-luna", forKey: "settings.openai.model")

        let settings = CompanionSettings(
            defaults: defaults,
            credentialStore: MemoryCredentialStore()
        )

        XCTAssertEqual(settings.model, "gpt-5-mini")
        XCTAssertFalse(settings.aiIdleBanterEnabled)
    }

    func testDraftDoesNotWriteKeychainUntilApplied() throws {
        let suiteName = "CompanionSettingsTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let credentials = MemoryCredentialStore()
        let settings = CompanionSettings(defaults: defaults, credentialStore: credentials)
        var draft = CompanionSettingsDraft(settings: settings)

        draft.apiKey = "new-key"
        XCTAssertNil(try credentials.read(key: "openai-api-key"))

        settings.apply(draft)
        XCTAssertEqual(try credentials.read(key: "openai-api-key"), "new-key")
    }

    func testTracksDailyAPIUsageAndAutomaticLimit() {
        let suiteName = "CompanionSettingsTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let settings = CompanionSettings(
            defaults: defaults,
            credentialStore: MemoryCredentialStore()
        )

        settings.recordAPIRequest(automatic: false)
        settings.recordAPIRequest(automatic: true)

        XCTAssertEqual(settings.dailyAPIRequestCount, 2)
        XCTAssertEqual(settings.dailyAutomaticAPIRequestCount, 1)
    }

    func testClampsIndependentCharacterSizesWhenApplied() {
        let suiteName = "CompanionSettingsTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let settings = CompanionSettings(
            defaults: defaults,
            credentialStore: MemoryCredentialStore()
        )
        var draft = CompanionSettingsDraft(settings: settings)
        draft.characterAScale = 0.1
        draft.characterBScale = 3

        settings.apply(draft)

        XCTAssertEqual(settings.characterAScale, AppDefaults.minimumCharacterScale)
        XCTAssertEqual(settings.characterBScale, AppDefaults.maximumCharacterScale)
    }

    func testCompactPanelKeepsMascotAndMainCharacterWithinStableBounds() {
        XCTAssertEqual(DesktopPanelMetrics.width(characterAScale: 1, characterBScale: 1), 398)
        XCTAssertEqual(
            DesktopPanelMetrics.height(characterAScale: 1, characterBScale: 1, bubbleVisible: false),
            261
        )
        XCTAssertGreaterThan(
            DesktopPanelMetrics.height(characterAScale: 1, characterBScale: 1, bubbleVisible: true),
            DesktopPanelMetrics.height(characterAScale: 1, characterBScale: 1, bubbleVisible: false)
        )
    }
}
