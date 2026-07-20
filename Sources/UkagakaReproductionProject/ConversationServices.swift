import Foundation

protocol ConversationGenerating {
    func generateReply(
        userInput: String,
        recentLines: [CharacterLine],
        characters: [CompanionCharacter]
    ) async throws -> [CharacterLine]
}

struct LocalConversationService: ConversationGenerating {
    func generateReply(
        userInput: String,
        recentLines: [CharacterLine],
        characters: [CompanionCharacter]
    ) async throws -> [CharacterLine] {
        guard characters.count >= 2 else { return [] }

        return [
            CharacterLine(
                speakerID: characters[0].id,
                text: "「\(userInput)」ですね。まずは状況を整理してみましょう。",
                expression: .neutral
            ),
            CharacterLine(
                speakerID: characters[1].id,
                text: "ChatGPT連携は初回設定か設定画面でAPIキーを入れると有効になります。",
                expression: .happy
            )
        ]
    }
}

struct OpenAIResponsesService: ConversationGenerating {
    private let apiKey: String
    private let model: String
    private let session: URLSession

    init(
        apiKey: String,
        model: String = AppDefaults.openAIModel,
        session: URLSession = .shared
    ) {
        self.apiKey = apiKey
        self.model = model
        self.session = session
    }

    func generateReply(
        userInput: String,
        recentLines: [CharacterLine],
        characters: [CompanionCharacter]
    ) async throws -> [CharacterLine] {
        guard let url = URL(string: "https://api.openai.com/v1/responses") else {
            throw OpenAIResponsesError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 60
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: makePayload(
            userInput: userInput,
            recentLines: recentLines,
            characters: characters
        ))

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenAIResponsesError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw OpenAIResponsesError.requestFailed(
                statusCode: httpResponse.statusCode,
                message: Self.extractErrorMessage(from: data)
            )
        }

        let text = try Self.extractOutputText(from: data)
        let lines = Self.parseLines(
            from: text,
            fallbackSpeakerID: characters.first?.id ?? "character_a",
            allowedSpeakerIDs: Set(characters.map(\.id))
        )
        guard !lines.isEmpty else {
            throw OpenAIResponsesError.invalidResponse
        }
        return lines
    }

    func makePayload(
        userInput: String,
        recentLines: [CharacterLine],
        characters: [CompanionCharacter]
    ) -> [String: Any] {
        [
            "model": model,
            "max_output_tokens": 800,
            "input": [
                [
                    "role": "developer",
                    "content": systemPrompt(characters: characters)
                ],
                [
                    "role": "user",
                    "content": """
                    ユーザー入力:
                    \(userInput)

                    直近の会話:
                    \(recentLines.suffix(6).map { "\($0.speakerID): \($0.text)" }.joined(separator: "\n"))
                    """
                ]
            ],
            "text": [
                "format": [
                    "type": "json_schema",
                    "name": "character_dialogue",
                    "strict": true,
                    "schema": responseSchema(speakerIDs: characters.map(\.id))
                ]
            ]
        ]
    }

    private func systemPrompt(characters: [CompanionCharacter]) -> String {
        let profiles = characters.map { character in
            """
            ID: \(character.id)
            名前: \(character.displayName)
            設定:
            \(character.profilePrompt)
            """
        }.joined(separator: "\n\n")

        return """
        あなたはmacOSデスクトップ常駐アクセサリ「伺か再現プロジェクト」の会話エンジンです。
        2名のキャラクターが日本語で短く自然に掛け合います。ユーザーの操作を勝手に実行せず、会話だけを生成してください。

        \(profiles)

        linesには1件か2件の短いセリフを入れてください。
        expressionは neutral, happy, angry, sad, fun, sleep のいずれかです。
        gestureは default, wave, point, think, emphasize, sleep のいずれかです。
        """
    }

    private func responseSchema(speakerIDs: [String]) -> [String: Any] {
        [
            "type": "object",
            "properties": [
                "lines": [
                    "type": "array",
                    "minItems": 1,
                    "maxItems": 2,
                    "items": [
                        "type": "object",
                        "properties": [
                            "speakerID": ["type": "string", "enum": speakerIDs],
                            "text": ["type": "string", "minLength": 1, "maxLength": 180],
                            "expression": [
                                "type": "string",
                                "enum": CharacterExpression.allCases.map(\.rawValue)
                            ],
                            "gesture": [
                                "type": "string",
                                "enum": CharacterGesture.allCases.map(\.rawValue)
                            ]
                        ],
                        "required": ["speakerID", "text", "expression", "gesture"],
                        "additionalProperties": false
                    ]
                ]
            ],
            "required": ["lines"],
            "additionalProperties": false
        ]
    }

    static func extractOutputText(from data: Data) throws -> String {
        let object = try JSONSerialization.jsonObject(with: data)
        guard let dictionary = object as? [String: Any] else {
            throw OpenAIResponsesError.invalidResponse
        }

        if let outputText = dictionary["output_text"] as? String, !outputText.isEmpty {
            return outputText
        }

        if let output = dictionary["output"] as? [[String: Any]] {
            let text = output.flatMap { item -> [String] in
                guard let content = item["content"] as? [[String: Any]] else { return [] }
                return content.compactMap { contentItem in
                    guard contentItem["type"] as? String == "output_text" else { return nil }
                    return contentItem["text"] as? String
                }
            }.joined(separator: "\n")

            if !text.isEmpty {
                return text
            }
        }

        throw OpenAIResponsesError.invalidResponse
    }

    static func parseLines(
        from text: String,
        fallbackSpeakerID: String,
        allowedSpeakerIDs: Set<String>
    ) -> [CharacterLine] {
        let cleanedText = text
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let data = cleanedText.data(using: .utf8) else { return [] }
        let decoder = JSONDecoder()
        let generatedLines: [GeneratedLine]

        if let response = try? decoder.decode(GeneratedResponse.self, from: data) {
            generatedLines = response.lines
        } else if let legacyLines = try? decoder.decode([GeneratedLine].self, from: data) {
            generatedLines = legacyLines
        } else {
            return [CharacterLine(
                speakerID: fallbackSpeakerID,
                text: cleanedText,
                expression: .neutral
            )]
        }

        return generatedLines.prefix(2).compactMap { line in
            let trimmedText = line.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedText.isEmpty else { return nil }

            let speakerID = allowedSpeakerIDs.contains(line.speakerID) ? line.speakerID : fallbackSpeakerID
            let expression = line.expression.flatMap(CharacterExpression.init(rawValue:)) ?? .neutral
            let gesture = line.gesture.flatMap(CharacterGesture.init(rawValue:))
            return CharacterLine(
                speakerID: speakerID,
                text: trimmedText,
                expression: expression,
                gesture: gesture
            )
        }
    }

    private static func extractErrorMessage(from data: Data) -> String {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let error = object["error"] as? [String: Any],
              let message = error["message"] as? String else {
            return "OpenAI APIからエラーが返されました。"
        }
        return message
    }
}

private struct GeneratedResponse: Decodable {
    let lines: [GeneratedLine]
}

private struct GeneratedLine: Decodable {
    let speakerID: String
    let text: String
    let expression: String?
    let gesture: String?
}

enum OpenAIResponsesError: LocalizedError {
    case invalidURL
    case invalidResponse
    case requestFailed(statusCode: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "OpenAI APIのURLを作成できませんでした。"
        case .invalidResponse:
            return "OpenAI APIの応答を読み取れませんでした。"
        case .requestFailed(let statusCode, let message):
            return "OpenAI APIエラー (\(statusCode)): \(message)"
        }
    }
}
