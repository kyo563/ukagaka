import XCTest
@testable import UkagakaReproductionProject

final class OpenAIResponsesServiceTests: XCTestCase {
    func testExtractsOutputTextFromResponsesAPIMessage() throws {
        let data = try JSONSerialization.data(withJSONObject: [
            "output": [[
                "type": "message",
                "content": [[
                    "type": "output_text",
                    "text": "{\"lines\":[]}"
                ]]
            ]]
        ])

        let text = try OpenAIResponsesService.extractOutputText(from: data)
        XCTAssertEqual(text, "{\"lines\":[]}")
    }

    func testParsesStructuredCharacterLinesAndRejectsUnknownSpeaker() {
        let json = """
        {
          "lines": [
            {"speakerID":"unknown","text":" こんにちは ","expression":"happy","gesture":"wave"}
          ]
        }
        """

        let lines = OpenAIResponsesService.parseLines(
            from: json,
            fallbackSpeakerID: "character_a",
            allowedSpeakerIDs: ["character_a", "character_b"]
        )

        XCTAssertEqual(lines.count, 1)
        XCTAssertEqual(lines[0].speakerID, "character_a")
        XCTAssertEqual(lines[0].text, "こんにちは")
        XCTAssertEqual(lines[0].expression, .happy)
        XCTAssertEqual(lines[0].gesture, .wave)
    }

    @MainActor
    func testPayloadUsesStrictJSONSchema() {
        let settings = CompanionSettings(
            defaults: UserDefaults(suiteName: UUID().uuidString)!,
            credentialStore: MemoryCredentialStore()
        )
        let characters = CharacterProfiles.make(settings: settings)
        let payload = OpenAIResponsesService(apiKey: "test").makePayload(
            userInput: "こんにちは",
            recentLines: [],
            characters: characters
        )

        let text = payload["text"] as? [String: Any]
        let format = text?["format"] as? [String: Any]
        XCTAssertEqual(format?["type"] as? String, "json_schema")
        XCTAssertEqual(format?["strict"] as? Bool, true)
    }
}

final class MemoryCredentialStore: CredentialStoring {
    var values: [String: String] = [:]

    func read(key: String) throws -> String? {
        values[key]
    }

    func write(_ value: String, key: String) throws {
        values[key] = value
    }

    func delete(key: String) throws {
        values.removeValue(forKey: key)
    }
}
