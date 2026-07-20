import Foundation

protocol ConversationGenerating {
    func generateReply(
        userInput: String,
        recentTurns: [ConversationTurn],
        characters: [CompanionCharacter]
    ) async throws -> [CharacterLine]
}

struct LocalConversationService: ConversationGenerating {
    func generateReply(
        userInput: String,
        recentTurns: [ConversationTurn],
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

struct OpenAIModelService {
    private let apiKey: String
    private let session: URLSession

    init(apiKey: String, session: URLSession = .shared) {
        self.apiKey = apiKey
        self.session = session
    }

    func listModels() async throws -> [String] {
        guard let url = URL(string: "https://api.openai.com/v1/models") else {
            throw OpenAIResponsesError.invalidURL
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 30
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        let data = try await OpenAIRequestExecutor.perform(request, session: session)
        return try Self.selectableModelIDs(from: data)
    }

    func testConnection(model: String) async throws {
        guard let url = URL(string: "https://api.openai.com/v1/responses") else {
            throw OpenAIResponsesError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 45
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: Self.connectionTestPayload(model: model))
        _ = try await OpenAIRequestExecutor.perform(request, session: session)
    }

    static func connectionTestPayload(model: String) -> [String: Any] {
        [
            "model": model,
            "store": false,
            "max_output_tokens": 64,
            "input": "接続確認です。okをtrueにしてください。",
            "text": [
                "format": [
                    "type": "json_schema",
                    "name": "connection_test",
                    "strict": true,
                    "schema": [
                        "type": "object",
                        "properties": ["ok": ["type": "boolean"]],
                        "required": ["ok"],
                        "additionalProperties": false
                    ]
                ]
            ]
        ]
    }

    static func selectableModelIDs(from data: Data) throws -> [String] {
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let models = object["data"] as? [[String: Any]] else {
            throw OpenAIResponsesError.invalidResponse
        }

        let excludedFragments = [
            "audio", "realtime", "transcribe", "tts", "image", "search",
            "codex", "embedding", "moderation", "instruct", "chat-latest"
        ]
        return models.compactMap { $0["id"] as? String }
            .filter { id in
                id.hasPrefix("gpt-") && !excludedFragments.contains(where: id.contains)
            }
            .sorted(by: Self.modelSort)
    }

    private static func modelSort(_ lhs: String, _ rhs: String) -> Bool {
        let preferred = AppDefaults.selectableModels
        let leftIndex = preferred.firstIndex(of: lhs)
        let rightIndex = preferred.firstIndex(of: rhs)
        switch (leftIndex, rightIndex) {
        case let (.some(left), .some(right)):
            return left < right
        case (.some, .none):
            return true
        case (.none, .some):
            return false
        case (.none, .none):
            return lhs.localizedStandardCompare(rhs) == .orderedAscending
        }
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
        recentTurns: [ConversationTurn],
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
            recentTurns: recentTurns,
            characters: characters
        ))

        let data = try await OpenAIRequestExecutor.perform(request, session: session)
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
        recentTurns: [ConversationTurn],
        characters: [CompanionCharacter]
    ) -> [String: Any] {
        var input: [[String: Any]] = [[
            "role": "developer",
            "content": systemPrompt(characters: characters)
        ]]

        let names = Dictionary(uniqueKeysWithValues: characters.map { ($0.id, $0.displayName) })
        input.append(contentsOf: recentTurns.suffix(12).map { turn in
            switch turn.role {
            case .user:
                return ["role": "user", "content": turn.text]
            case .character(let characterID):
                let name = names[characterID] ?? characterID
                return ["role": "assistant", "content": "[\(name)] \(turn.text)"]
            }
        })

        let lastTurnMatchesInput = recentTurns.last.map { turn in
            turn.role == .user && turn.text == userInput
        } ?? false
        if !lastTurnMatchesInput {
            input.append(["role": "user", "content": userInput])
        }

        return [
            "model": model,
            "store": false,
            "max_output_tokens": 400,
            "input": input,
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
        人型のメインキャラクターAと、マスコットキャラクターBが日本語で短く自然に掛け合います。
        ユーザーの操作を勝手に実行せず、会話だけを生成してください。

        \(profiles)

        linesには1件か2件の短いセリフを入れてください。
        各セリフは180文字以内です。
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
            return []
        }

        return generatedLines.prefix(2).compactMap { line in
            let trimmedText = line.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedText.isEmpty else { return nil }

            let speakerID = allowedSpeakerIDs.contains(line.speakerID) ? line.speakerID : fallbackSpeakerID
            let expression = line.expression.flatMap(CharacterExpression.init(rawValue:)) ?? .neutral
            let gesture = line.gesture.flatMap(CharacterGesture.init(rawValue:))
            return CharacterLine(
                speakerID: speakerID,
                text: String(trimmedText.prefix(180)),
                expression: expression,
                gesture: gesture
            )
        }
    }

}

private enum OpenAIRequestExecutor {
    static func perform(_ request: URLRequest, session: URLSession) async throws -> Data {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError {
            if error.code == .timedOut {
                throw OpenAIResponsesError.timeout
            }
            throw OpenAIResponsesError.network(code: error.code)
        } catch {
            throw OpenAIResponsesError.network(code: .unknown)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenAIResponsesError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            let details = Self.extractErrorDetails(from: data)
            throw OpenAIResponsesError.requestFailed(
                statusCode: httpResponse.statusCode,
                code: details.code,
                message: details.message
            )
        }
        return data
    }

    private static func extractErrorDetails(from data: Data) -> (code: String?, message: String) {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let error = object["error"] as? [String: Any] else {
            return (nil, "OpenAI APIからエラーが返されました。")
        }
        return (
            error["code"] as? String ?? error["type"] as? String,
            error["message"] as? String ?? "OpenAI APIからエラーが返されました。"
        )
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

enum OpenAIErrorKind: String, Equatable {
    case invalidAPIKey
    case modelNotFound
    case quotaExceeded
    case rateLimited
    case network
    case timeout
    case decoding
    case serviceUnavailable
    case unknown
}

enum OpenAIResponsesError: LocalizedError {
    case invalidURL
    case invalidResponse
    case timeout
    case network(code: URLError.Code)
    case requestFailed(statusCode: Int, code: String?, message: String)

    var kind: OpenAIErrorKind {
        switch self {
        case .invalidURL:
            return .unknown
        case .invalidResponse:
            return .decoding
        case .timeout:
            return .timeout
        case .network:
            return .network
        case .requestFailed(let statusCode, let code, let message):
            let normalized = "\(code ?? "") \(message)".lowercased()
            if statusCode == 401 || normalized.contains("api key") {
                return .invalidAPIKey
            }
            if statusCode == 404 || normalized.contains("model_not_found") || normalized.contains("does not exist") {
                return .modelNotFound
            }
            if normalized.contains("insufficient_quota") || normalized.contains("quota") || normalized.contains("billing") {
                return .quotaExceeded
            }
            if statusCode == 429 {
                return .rateLimited
            }
            if statusCode >= 500 {
                return .serviceUnavailable
            }
            return .unknown
        }
    }

    var userFacingDescription: String {
        switch kind {
        case .invalidAPIKey:
            return "APIキーが無効です。OpenAI Platformでキーを確認してください。"
        case .modelNotFound:
            return "選択したモデルを利用できません。モデル一覧を更新してください。"
        case .quotaExceeded:
            return "OpenAI APIの利用枠または支払い設定を確認してください。"
        case .rateLimited:
            return "OpenAI APIのレート制限に達しました。少し待って再試行してください。"
        case .network:
            return "ネットワークに接続できません。通信状態を確認してください。"
        case .timeout:
            return "OpenAI APIへの接続がタイムアウトしました。"
        case .decoding:
            return "OpenAI APIの応答形式を読み取れませんでした。"
        case .serviceUnavailable:
            return "OpenAI APIで一時的な障害が発生しています。"
        case .unknown:
            return errorDescription ?? "OpenAI APIで不明なエラーが発生しました。"
        }
    }

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "OpenAI APIのURLを作成できませんでした。"
        case .invalidResponse:
            return "OpenAI APIの応答を読み取れませんでした。"
        case .timeout:
            return "OpenAI APIへの接続がタイムアウトしました。"
        case .network(let code):
            return "ネットワークエラー: \(code.rawValue)"
        case .requestFailed(let statusCode, _, let message):
            return "OpenAI APIエラー (\(statusCode)): \(message)"
        }
    }
}

enum OpenAIErrorPresenter {
    static func message(for error: Error) -> String {
        if let openAIError = error as? OpenAIResponsesError {
            return openAIError.userFacingDescription
        }
        if let urlError = error as? URLError {
            return urlError.code == .timedOut
                ? "OpenAI APIへの接続がタイムアウトしました。"
                : "ネットワークに接続できません。通信状態を確認してください。"
        }
        return error.localizedDescription
    }
}
