import AppKit
import Foundation

enum AppCommand {
    case search(String)
    case launchApplication(String)
    case today
    case chat(String)
}

struct CommandParser {
    func parse(_ input: String) -> AppCommand? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if ["今日は何の日", "今日何の日", "きょうは何の日"].contains(trimmed) {
            return .today
        }

        if let query = trimmed.removingCommandPrefix(["検索", "search", "s"]) {
            return .search(query)
        }

        if let applicationName = trimmed.removingCommandPrefix(["起動", "open", "launch"]) {
            return .launchApplication(applicationName)
        }

        return .chat(trimmed)
    }
}

extension String {
    var trimmedNonEmpty: String? {
        let value = trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    func removingCommandPrefix(_ prefixes: [String]) -> String? {
        for prefix in prefixes {
            if self == prefix {
                return ""
            }

            for separator in [" ", "　", ":", "："] {
                let marker = prefix + separator
                if hasPrefix(marker) {
                    return String(dropFirst(marker.count)).trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
        }
        return nil
    }
}

enum CommandResult {
    case handled(String, CharacterExpression)
    case showToday
    case passToConversation
}

enum CommandRouterError: Error {
    case invalidSearchURL
    case applicationNotFound(String)
}

@MainActor
struct CommandRouter {
    func run(_ command: AppCommand) async throws -> CommandResult {
        switch command {
        case .search(let query):
            return try openSearch(query)
        case .launchApplication(let applicationName):
            return try launchApplication(applicationName)
        case .today:
            return .showToday
        case .chat:
            return .passToConversation
        }
    }

    private func openSearch(_ query: String) throws -> CommandResult {
        let finalQuery = query.isEmpty ? "伺か" : query
        var components = URLComponents(string: "https://www.google.com/search")
        components?.queryItems = [URLQueryItem(name: "q", value: finalQuery)]

        guard let url = components?.url else {
            throw CommandRouterError.invalidSearchURL
        }

        NSWorkspace.shared.open(url)
        return .handled("「\(finalQuery)」を検索します。", .happy)
    }

    private func launchApplication(_ applicationName: String) throws -> CommandResult {
        let finalName = applicationName.isEmpty ? "Safari" : applicationName
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-a", finalName]
        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw CommandRouterError.applicationNotFound(finalName)
        }

        return .handled("「\(finalName)」を起動しました。", .happy)
    }
}
