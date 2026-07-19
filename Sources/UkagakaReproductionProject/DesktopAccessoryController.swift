import AppKit
import SwiftUI

struct CompanionWindowActions {
    let openSettings: () -> Void
    let hide: () -> Void
    let restart: () -> Void
    let quit: () -> Void
}

@MainActor
final class DesktopAccessoryController {
    private let panel: DesktopAccessoryPanel

    init(state: CompanionAppState, actions: CompanionWindowActions) {
        let visibleFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1280, height: 800)
        let size = NSSize(width: 700, height: 480)
        let origin = NSPoint(x: visibleFrame.maxX - size.width - 32, y: visibleFrame.minY + 24)

        panel = DesktopAccessoryPanel(
            contentRect: NSRect(origin: origin, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        panel.title = "伺か再現プロジェクト"
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.isMovableByWindowBackground = true
        panel.contentView = NSHostingView(rootView: CharacterStageView(state: state, actions: actions))
    }

    func show() {
        panel.orderFrontRegardless()
    }

    func hide() {
        panel.orderOut(nil)
    }
}

final class DesktopAccessoryPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
