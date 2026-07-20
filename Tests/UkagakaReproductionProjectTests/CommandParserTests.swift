import XCTest
@testable import UkagakaReproductionProject

final class CommandParserTests: XCTestCase {
    func testParsesJapaneseSearchCommand() {
        let command = CommandParser().parse("検索: 伺か")
        guard case .search(let query) = command else {
            return XCTFail("検索コマンドとして解析されませんでした")
        }
        XCTAssertEqual(query, "伺か")
    }

    func testParsesApplicationLaunchCommand() {
        let command = CommandParser().parse("起動 Safari")
        guard case .launchApplication(let name) = command else {
            return XCTFail("起動コマンドとして解析されませんでした")
        }
        XCTAssertEqual(name, "Safari")
    }

    func testParsesTodayQuestionWithoutSendingItToAPI() {
        let command = CommandParser().parse("今日は何の日")
        guard case .today = command else {
            return XCTFail("今日の情報コマンドとして解析されませんでした")
        }
    }

    func testTreatsRegularTextAsChat() {
        let command = CommandParser().parse("今日の予定を整理して")
        guard case .chat(let text) = command else {
            return XCTFail("会話として解析されませんでした")
        }
        XCTAssertEqual(text, "今日の予定を整理して")
    }
}
