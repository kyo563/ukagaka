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
            Button("設定") {
                appDelegate.showSettings()
            }
            Divider()
            Button("再起動") {
                appDelegate.restartApplication()
            }
            Button("終了") {
                appDelegate.quitApplication()
            }
        }

        Settings {
            SettingsRootView(state: appDelegate.appState)
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let appState = CompanionAppState.bootstrap()

    private var accessoryController: DesktopAccessoryController?
    private var onboardingController: NSWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        appState.restorePersistedSettings()
        accessoryController = DesktopAccessoryController(
            state: appState,
            actions: CompanionWindowActions(
                openSettings: { [weak self] in self?.showSettings() },
                hide: { [weak self] in self?.hideAccessory() },
                restart: { [weak self] in self?.restartApplication() },
                quit: { [weak self] in self?.quitApplication() }
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
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func showInitialSetup() {
        if let onboardingController {
            onboardingController.window?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 620, height: 560),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "伺か再現プロジェクト 初回設定"
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
        guard let executableURL = Bundle.main.executableURL else {
            quitApplication()
            return
        }

        let process = Process()
        process.executableURL = executableURL
        try? process.run()
        quitApplication()
    }

    func quitApplication() {
        appState.saveSettingsForTermination()
        NSApplication.shared.terminate(nil)
    }
}
