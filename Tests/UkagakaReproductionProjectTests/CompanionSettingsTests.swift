import XCTest
@testable import UkagakaReproductionProject

@MainActor
final class CompanionSettingsTests: XCTestCase {
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

        XCTAssertEqual(settings.stageOpacity, AppDefaults.minimumStageOpacity)
        XCTAssertEqual(settings.idleBanterInterval, AppDefaults.maximumIdleBanterInterval)
    }
}
