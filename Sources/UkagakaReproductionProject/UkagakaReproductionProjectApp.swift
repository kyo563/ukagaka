import AppKit
import SwiftUI

@main
struct UkagakaReproductionProjectApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("伺か再現プロジェクト", systemImage: "sparkles") {
            Button("表示") {
                appDelegate.showAccessory()
            }
            Button("隠す") {
                appDelegate.hideAccessory()
            }
            Button("設定...") {
                appDelegate.showSettings()
            }
            Divider()
            Button("再起動") {
                appDelegate.restartApplication()
            }
            Button("終了") {
                appDelegate.quitApplication()
            }
            Divider()
            Button("アンインストール...") {
                appDelegate.uninstallApplication()
            }
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let appState = CompanionAppState.bootstrap()

    private var accessoryController: DesktopAccessoryController?
    private var onboardingController: NSWindowController?
    private var settingsController: NSWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        appState.restorePersistedSettings()
        accessoryController = DesktopAccessoryController(
            state: appState,
            actions: CompanionWindowActions(
                openSettings: { [weak self] in self?.showSettings() },
                hide: { [weak self] in self?.hideAccessory() },
                restart: { [weak self] in self?.restartApplication() },
                quit: { [weak self] in self?.quitApplication() },
                uninstall: { [weak self] in self?.uninstallApplication() }
            )
        )
        showAccessory()
        appState.start()

        if !appState.settings.didCompleteInitialSetup {
            showInitialSetup()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        appState.saveSettingsForTermination()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showAccessory()
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func showAccessory() {
        accessoryController?.show()
    }

    func hideAccessory() {
        accessoryController?.hide()
    }

    func showSettings() {
        if let settingsController {
            settingsController.window?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 620, height: 700),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "伺か再現プロジェクト 設定"
        window.sharingType = .readOnly
        window.center()
        window.minSize = NSSize(width: 560, height: 560)
        window.contentView = NSHostingView(
            rootView: SettingsRootView(
                state: appState,
                uninstall: { [weak self] in self?.uninstallApplication() }
            )
        )

        let controller = NSWindowController(window: window)
        settingsController = controller
        controller.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func showInitialSetup() {
        if let onboardingController {
            onboardingController.window?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 620, height: 600),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "伺か再現プロジェクト 初回設定"
        window.sharingType = .readOnly
        window.center()
        window.contentView = NSHostingView(
            rootView: OnboardingView(state: appState) { [weak self] in
                self?.onboardingController?.close()
                self?.onboardingController = nil
            }
        )

        let controller = NSWindowController(window: window)
        onboardingController = controller
        controller.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func restartApplication() {
        let process = Process()

        if Bundle.main.bundleURL.pathExtension == "app" {
            process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
            process.arguments = ["-n", Bundle.main.bundleURL.path]
        } else if let executableURL = Bundle.main.executableURL {
            process.executableURL = executableURL
        } else {
            showError(title: "再起動できません", message: "実行ファイルを確認できませんでした。")
            return
        }

        do {
            try process.run()
            quitApplication()
        } catch {
            showError(title: "再起動できません", message: error.localizedDescription)
        }
    }

    func quitApplication() {
        appState.saveSettingsForTermination()
        NSApplication.shared.terminate(nil)
    }

    func uninstallApplication() {
        let alert = NSAlert()
        alert.alertStyle = .critical
        alert.messageText = "伺か再現プロジェクトをアンインストールしますか？"
        alert.informativeText = "ログイン時起動を解除し、設定とOpenAI APIキーを削除して、アプリをゴミ箱へ移動します。外部のモデル画像フォルダは削除しません。"
        alert.addButton(withTitle: "アンインストール")
        alert.addButton(withTitle: "キャンセル")

        guard alert.runModal() == .alertFirstButtonReturn else { return }

        do {
            try appState.settings.eraseAllStoredData()
        } catch {
            showError(title: "アンインストールを完了できません", message: error.localizedDescription)
            return
        }

        let appURL = Bundle.main.bundleURL
        guard appURL.pathExtension == "app" else {
            showError(
                title: "アプリデータを削除しました",
                message: "開発用実行ファイルのため本体は移動していません。アプリを終了します。"
            )
            NSApplication.shared.terminate(nil)
            return
        }

        NSWorkspace.shared.recycle([appURL]) { [weak self] _, error in
            Task { @MainActor in
                if let error {
                    self?.showError(title: "アプリをゴミ箱へ移動できません", message: error.localizedDescription)
                } else {
                    NSApplication.shared.terminate(nil)
                }
            }
        }
    }

    private func showError(title: String, message: String) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
