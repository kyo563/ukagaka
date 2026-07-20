import AppKit
import Combine
import SwiftUI

struct CompanionWindowActions {
    let openSettings: () -> Void
    let hide: () -> Void
    let toggleClickThrough: () -> Void
    let restart: () -> Void
    let quit: () -> Void
    let uninstall: () -> Void
}

@MainActor
final class DesktopAccessoryController: NSObject, NSWindowDelegate {
    private let panel: DesktopAccessoryPanel
    private let state: CompanionAppState
    private let settings: CompanionSettings
    private var observers: Set<AnyCancellable> = []
    private var snapWorkItem: DispatchWorkItem?
    private var isUpdatingFrame = false
    private var stableFrame = NSRect.zero
    private var ignoreMoveNotificationsUntil = Date.distantPast

    init(state: CompanionAppState, actions: CompanionWindowActions) {
        self.state = state
        self.settings = state.settings

        let visibleFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1280, height: 800)
        let size = Self.panelSize(state: state, settings: state.settings)
        let origin = NSPoint(x: visibleFrame.maxX - size.width - 24, y: visibleFrame.minY + 18)

        panel = DesktopAccessoryPanel(
            contentRect: NSRect(origin: origin, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        super.init()

        panel.title = "伺か再現プロジェクト"
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.sharingType = .readOnly
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.isMovableByWindowBackground = true
        panel.delegate = self
        panel.contentView = NSHostingView(rootView: CharacterStageView(state: state, actions: actions))

        restoreFrameForCurrentDisplay()
        stableFrame = panel.frame
        applyWindowBehavior()
        observeState()
    }

    func show() {
        updatePanelSize(animated: false)
        panel.orderFrontRegardless()
    }

    func hide() {
        saveFrameForCurrentDisplay()
        panel.orderOut(nil)
    }

    func windowDidMove(_ notification: Notification) {
        guard !isUpdatingFrame, Date() >= ignoreMoveNotificationsUntil else { return }
        snapWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.snapToNearestEdge()
        }
        snapWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18, execute: workItem)
    }

    func windowDidEndLiveResize(_ notification: Notification) {
        snapToNearestEdge()
    }

    private func observeState() {
        state.$isBubbleVisible
            .dropFirst()
            .sink { [weak self] _ in
                DispatchQueue.main.async { self?.updatePanelSize(animated: true) }
            }
            .store(in: &observers)

        Publishers.CombineLatest(settings.$characterAScale, settings.$characterBScale)
            .dropFirst()
            .sink { [weak self] _ in
                DispatchQueue.main.async { self?.updatePanelSize(animated: true) }
            }
            .store(in: &observers)

        Publishers.CombineLatest(settings.$clickThrough, settings.$alwaysOnTop)
            .sink { [weak self] _ in
                DispatchQueue.main.async { self?.applyWindowBehavior() }
            }
            .store(in: &observers)
    }

    private func applyWindowBehavior() {
        panel.ignoresMouseEvents = settings.clickThrough
        panel.level = settings.alwaysOnTop ? .floating : .normal
    }

    private func updatePanelSize(animated: Bool) {
        snapWorkItem?.cancel()
        snapWorkItem = nil
        let size = Self.panelSize(state: state, settings: settings)
        let referenceFrame = stableFrame == .zero ? panel.frame : stableFrame

        var newFrame = NSRect(
            x: referenceFrame.maxX - size.width,
            y: referenceFrame.minY,
            width: size.width,
            height: size.height
        )
        if let screen = panel.screen ?? NSScreen.main {
            newFrame = constrained(newFrame, to: screen.visibleFrame)
        }
        guard panel.frame != newFrame else { return }

        ignoreMoveNotificationsUntil = Date().addingTimeInterval(animated ? 0.35 : 0.05)
        isUpdatingFrame = true
        panel.setFrame(newFrame, display: true, animate: animated)
        isUpdatingFrame = false
        stableFrame = newFrame
        saveFrameForCurrentDisplay()

        let delay = animated ? 0.25 : 0
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.enforceStableFrame(newFrame)
        }
    }

    private func enforceStableFrame(_ expectedFrame: NSRect) {
        guard stableFrame == expectedFrame, panel.frame != expectedFrame else { return }
        isUpdatingFrame = true
        panel.setFrame(expectedFrame, display: true, animate: false)
        isUpdatingFrame = false
        saveFrameForCurrentDisplay()
    }

    private func snapToNearestEdge() {
        guard let screen = panel.screen ?? NSScreen.main else { return }
        let visibleFrame = screen.visibleFrame
        var frame = constrained(panel.frame, to: visibleFrame)
        let threshold: CGFloat = 24

        if abs(frame.minX - visibleFrame.minX) <= threshold {
            frame.origin.x = visibleFrame.minX
        } else if abs(frame.maxX - visibleFrame.maxX) <= threshold {
            frame.origin.x = visibleFrame.maxX - frame.width
        }

        if abs(frame.minY - visibleFrame.minY) <= threshold {
            frame.origin.y = visibleFrame.minY
        } else if abs(frame.maxY - visibleFrame.maxY) <= threshold {
            frame.origin.y = visibleFrame.maxY - frame.height
        }

        ignoreMoveNotificationsUntil = Date().addingTimeInterval(0.35)
        isUpdatingFrame = true
        panel.setFrame(frame, display: true, animate: true)
        isUpdatingFrame = false
        stableFrame = frame
        saveFrameForCurrentDisplay()
    }

    private func constrained(_ frame: NSRect, to visibleFrame: NSRect) -> NSRect {
        var result = frame
        result.origin.x = min(max(result.origin.x, visibleFrame.minX), visibleFrame.maxX - result.width)
        result.origin.y = min(max(result.origin.y, visibleFrame.minY), visibleFrame.maxY - result.height)
        return result
    }

    private func restoreFrameForCurrentDisplay() {
        guard let screen = NSScreen.main,
              let saved = UserDefaults.standard.string(forKey: frameKey(for: screen)) else {
            return
        }
        let frame = NSRectFromString(saved)
        guard frame.width > 0, frame.height > 0, frame.intersects(screen.visibleFrame) else { return }
        let size = Self.panelSize(state: state, settings: settings)
        panel.setFrame(
            constrained(NSRect(origin: frame.origin, size: size), to: screen.visibleFrame),
            display: false
        )
    }

    private func saveFrameForCurrentDisplay() {
        guard let screen = panel.screen ?? NSScreen.main else { return }
        UserDefaults.standard.set(NSStringFromRect(panel.frame), forKey: frameKey(for: screen))
    }

    private func frameKey(for screen: NSScreen) -> String {
        let screenNumber = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber
        return "DesktopAccessoryPanelFrame.\(screenNumber?.stringValue ?? screen.localizedName)"
    }

    private static func panelSize(state: CompanionAppState, settings: CompanionSettings) -> NSSize {
        NSSize(
            width: DesktopPanelMetrics.width(
                characterAScale: settings.characterAScale,
                characterBScale: settings.characterBScale
            ),
            height: DesktopPanelMetrics.height(
                characterAScale: settings.characterAScale,
                characterBScale: settings.characterBScale,
                bubbleVisible: state.isBubbleVisible
            )
        )
    }
}

final class DesktopAccessoryPanel: NSPanel {
    override var canBecomeKey: Bool { !ignoresMouseEvents }
    override var canBecomeMain: Bool { false }
}
