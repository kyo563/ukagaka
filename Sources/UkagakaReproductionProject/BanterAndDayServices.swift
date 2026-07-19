import Foundation

struct BanterService {
    private let topics = [
        "今日の作業、少しだけ先回りして整えておきたいですね。",
        "デスクトップの端から見ると、締切というものは妙に足音がします。",
        "水分補給の時報も、ある意味では高度なコンシェルジュ機能です。",
        "検索したいことが浮かんだら、ここにそのまま投げてください。",
        "昔の常駐アクセサリ感と今のAI感、ちょうどいい混ざり具合を探しましょう。"
    ]

    func nextBanter(characters: [CompanionCharacter]) -> [CharacterLine] {
        guard characters.count >= 2 else { return [] }
        let topic = topics.randomElement() ?? topics[0]

        return [
            CharacterLine(speakerID: characters[0].id, text: topic, expression: .neutral),
            CharacterLine(speakerID: characters[1].id, text: "了解です。では、邪魔にならない声量で見守ります。", expression: .happy)
        ]
    }
}

struct DayEventService {
    private let eventsByMonthDay: [String: String] = [
        "01-01": "元日",
        "02-22": "猫の日",
        "03-14": "ホワイトデー",
        "04-01": "エイプリルフール",
        "05-05": "こどもの日",
        "07-07": "七夕",
        "08-11": "山の日",
        "09-09": "重陽の節句",
        "10-31": "ハロウィン",
        "11-03": "文化の日",
        "12-25": "クリスマス"
    ]

    func openingLines(on date: Date = Date(), characters: [CompanionCharacter]) -> [CharacterLine] {
        guard characters.count >= 2 else { return [] }

        let dateText = Self.dateFormatter.string(from: date)
        let eventText = eventName(on: date) ?? "記念日データはまだ登録されていない日"

        return [
            CharacterLine(speakerID: characters[0].id, text: "おかえりなさい。今日は\(dateText)です。", expression: .happy),
            CharacterLine(speakerID: characters[1].id, text: "今日のメモは「\(eventText)」。この一覧はあとで増やせます。", expression: .neutral)
        ]
    }

    func hourlyLine(on date: Date = Date(), character: CompanionCharacter) -> CharacterLine {
        let timeText = Self.timeFormatter.string(from: date)
        return CharacterLine(speakerID: character.id, text: "\(timeText)になりました。ひと息入れるなら今です。", expression: .happy)
    }

    private func eventName(on date: Date) -> String? {
        let key = Self.monthDayFormatter.string(from: date)
        return eventsByMonthDay[key]
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateStyle = .full
        formatter.timeStyle = .none
        return formatter
    }()

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "H時"
        return formatter
    }()

    private static let monthDayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "MM-dd"
        return formatter
    }()
}
