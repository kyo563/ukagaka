import AppKit
import Foundation

enum AppCommand {
    case search(String)
    case launchApplication(String)
    case chat(String)
}

struct CommandParser {
    func parse(_ input: String) -> AppCommand? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

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
    case passToConversation
}

enum CommandRouterError: Error {
    case invalidSearchURL
}

@MainActor
struct CommandRouter {
    func run(_ command: AppCommand) async throws -> CommandResult {
        switch command {
        case .search(let query):
            return try openSearch(query)
        case .launchApplication(let applicationName):
            return launchApplication(applicationName)
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

    private func launchApplication(_ applicationName: String) -> CommandResult {
        let finalName = applicationName.isEmpty ? "Safari" : applicationName
        let appURL = URL(fileURLWithPath: "/Applications/\(finalName).app")

        if FileManager.default.fileExists(atPath: appURL.path) {
            NSWorkspace.shared.openApplication(
                at: appURL,
                configuration: NSWorkspace.OpenConfiguration(),
                completionHandler: nil
            )
        } else {
            NSWorkspace.shared.launchApplication(finalName)
        }

        return .handled("「\(finalName)」を起動してみます。", .happy)
    }
}
