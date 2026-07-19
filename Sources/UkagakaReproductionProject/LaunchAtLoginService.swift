import Foundation
import ServiceManagement

@MainActor
enum LaunchAtLoginService {
    static func apply(enabled: Bool) -> String {
        do {
            if enabled {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            }
            return statusMessage
        } catch {
            return "ログイン時起動の更新に失敗しました: \(error.localizedDescription)"
        }
    }

    static var statusMessage: String {
        switch SMAppService.mainApp.status {
        case .enabled:
            return "ログイン時に自動起動します。"
        case .notRegistered:
            return "ログイン時起動は未登録です。"
        case .requiresApproval:
            return "macOSのログイン項目設定で承認が必要です。"
        case .notFound:
            return "アプリバンドルから起動したときに有効化できます。"
        @unknown default:
            return "ログイン時起動の状態を確認できません。"
        }
    }
}
