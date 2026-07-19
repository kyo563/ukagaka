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

    init(apiKey: String, model: String = "gpt-5", session: URLSession = .shared) {
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
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload(
            userInput: userInput,
            recentLines: recentLines,
            characters: characters
        ))

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw OpenAIResponsesError.requestFailed(String(data: data, encoding: .utf8) ?? "")
        }

        let text = try extractOutputText(from: data)
        return parseLines(from: text, fallbackSpeakerID: characters.first?.id ?? "character_a")
    }

    private func payload(
        userInput: String,
        recentLines: [CharacterLine],
        characters: [CompanionCharacter]
    ) -> [String: Any] {
        [
            "model": model,
            "max_output_tokens": 500,
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
        2名のキャラクターが短く自然に掛け合います。

        \(profiles)

        必ず次のJSON配列だけを返してください。
        [{"speakerID":"character_a","text":"短いセリフ","expression":"happy","gesture":"wave"}]

        expressionは neutral, happy, angry, sad, fun, sleep のいずれかです。
        gestureは default, wave, point, think, emphasize, sleep のいずれかです。
        """
    }

    private func extractOutputText(from data: Data) throws -> String {
        let object = try JSONSerialization.jsonObject(with: data)
        guard let dictionary = object as? [String: Any] else {
            throw OpenAIResponsesError.invalidResponse
        }

        if let outputText = dictionary["output_text"] as? String {
            return outputText
        }

        if let output = dictionary["output"] as? [[String: Any]] {
            let text = output.flatMap { item -> [String] in
                guard let content = item["content"] as? [[String: Any]] else { return [] }
                return content.compactMap { contentItem in
                    contentItem["text"] as? String
                }
            }.joined(separator: "\n")

            if !text.isEmpty {
                return text
            }
        }

        throw OpenAIResponsesError.invalidResponse
    }

    private func parseLines(from text: String, fallbackSpeakerID: String) -> [CharacterLine] {
        guard let data = text.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([GeneratedLine].self, from: data) else {
            return [CharacterLine(
                speakerID: fallbackSpeakerID,
                text: text.trimmingCharacters(in: .whitespacesAndNewlines),
                expression: .neutral
            )]
        }

        return decoded.map { line in
            let expression = line.expression.flatMap(CharacterExpression.init(rawValue:)) ?? .neutral
            let gesture = line.gesture.flatMap(CharacterGesture.init(rawValue:))
            return CharacterLine(
                speakerID: line.speakerID,
                text: line.text,
                expression: expression,
                gesture: gesture
            )
        }
    }
}

private struct GeneratedLine: Decodable {
    let speakerID: String
    let text: String
    let expression: String?
    let gesture: String?
}

enum OpenAIResponsesError: Error {
    case invalidURL
    case invalidResponse
    case requestFailed(String)
}
