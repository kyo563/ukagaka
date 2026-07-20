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

    func testRejectsMalformedStructuredOutput() {
        XCTAssertTrue(
            OpenAIResponsesService.parseLines(
                from: "not-json",
                fallbackSpeakerID: "character_a",
                allowedSpeakerIDs: ["character_a", "character_b"]
            ).isEmpty
        )
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
            recentTurns: [],
            characters: characters
        )

        let text = payload["text"] as? [String: Any]
        let format = text?["format"] as? [String: Any]
        XCTAssertEqual(format?["type"] as? String, "json_schema")
        XCTAssertEqual(format?["strict"] as? Bool, true)
        XCTAssertEqual(payload["store"] as? Bool, false)
    }

    @MainActor
    func testPayloadIncludesUserAndCharacterHistory() {
        let settings = CompanionSettings(
            defaults: UserDefaults(suiteName: UUID().uuidString)!,
            credentialStore: MemoryCredentialStore()
        )
        let characters = CharacterProfiles.make(settings: settings)
        let turns = [
            ConversationTurn(role: .user, text: "前の条件です"),
            ConversationTurn(role: .character("character_a"), text: "承知しました")
        ]

        let payload = OpenAIResponsesService(apiKey: "test").makePayload(
            userInput: "続けてください",
            recentTurns: turns,
            characters: characters
        )
        let input = payload["input"] as? [[String: Any]]

        XCTAssertEqual(input?.count, 4)
        XCTAssertEqual(input?[1]["role"] as? String, "user")
        XCTAssertEqual(input?[1]["content"] as? String, "前の条件です")
        XCTAssertEqual(input?[2]["role"] as? String, "assistant")
        XCTAssertEqual(input?[3]["content"] as? String, "続けてください")
    }

    func testFiltersModelListForConversationModels() throws {
        let data = try JSONSerialization.data(withJSONObject: [
            "data": [
                ["id": "gpt-5-mini"],
                ["id": "gpt-5-nano"],
                ["id": "gpt-realtime"],
                ["id": "text-embedding-3-small"]
            ]
        ])

        XCTAssertEqual(
            try OpenAIModelService.selectableModelIDs(from: data),
            ["gpt-5-mini", "gpt-5-nano"]
        )
    }

    func testClassifiesCommonAPIErrors() {
        XCTAssertEqual(
            OpenAIResponsesError.requestFailed(
                statusCode: 401,
                code: "invalid_api_key",
                message: "bad key"
            ).kind,
            .invalidAPIKey
        )
        XCTAssertEqual(
            OpenAIResponsesError.requestFailed(
                statusCode: 404,
                code: "model_not_found",
                message: "missing"
            ).kind,
            .modelNotFound
        )
        XCTAssertEqual(
            OpenAIResponsesError.requestFailed(
                statusCode: 429,
                code: "insufficient_quota",
                message: "quota"
            ).kind,
            .quotaExceeded
        )
    }

    func testConnectionPayloadDisablesResponseStorage() {
        let requestBody = OpenAIModelService.connectionTestPayload(model: "gpt-5-mini")

        XCTAssertEqual(requestBody["model"] as? String, "gpt-5-mini")
        XCTAssertEqual(requestBody["store"] as? Bool, false)
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
