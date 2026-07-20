import Foundation
import ServiceManagement

@MainActor
enum LaunchAtLoginService {
    static func apply(enabled: Bool) -> String {
        do {
            if enabled {
                if SMAppService.mainApp.status == .notFound {
                    return "アプリとしてインストールした後に有効化できます。"
                }
                if SMAppService.mainApp.status == .notRegistered {
                    try SMAppService.mainApp.register()
                }
            } else {
                try unregisterIfNeeded()
            }
            return statusMessage
        } catch {
            return "ログイン時起動の更新に失敗しました: \(error.localizedDescription)"
        }
    }

    static func reconcile(preferredEnabled: Bool) -> String {
        if preferredEnabled, SMAppService.mainApp.status == .notRegistered {
            return apply(enabled: true)
        }
        return statusMessage
    }

    static func unregisterForRemoval() throws {
        try unregisterIfNeeded()
    }

    static func openSystemSettings() {
        SMAppService.openSystemSettingsLoginItems()
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
            return "アプリとしてインストールした後に有効化できます。"
        @unknown default:
            return "ログイン時起動の状態を確認できません。"
        }
    }

    private static func unregisterIfNeeded() throws {
        switch SMAppService.mainApp.status {
        case .enabled, .requiresApproval:
            try SMAppService.mainApp.unregister()
        case .notRegistered, .notFound:
            break
        @unknown default:
            try SMAppService.mainApp.unregister()
        }
    }
}
