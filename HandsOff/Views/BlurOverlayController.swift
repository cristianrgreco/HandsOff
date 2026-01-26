import AppKit

final class BlurOverlayController {
    private var windows: [NSWindow] = []
    private var isVisible = false
    private var screenObserver: NSObjectProtocol?
    private var blurAlpha: CGFloat = 0.75

    init() {
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.rebuildWindows()
        }
        rebuildWindows()
    }

    deinit {
        if let screenObserver {
            NotificationCenter.default.removeObserver(screenObserver)
        }
    }

    func show() {
        guard !isVisible else { return }
        isVisible = true
        ensureWindows()
        windows.forEach { $0.orderFrontRegardless() }
    }

    func hide() {
        guard isVisible else { return }
        isVisible = false
        windows.forEach { $0.orderOut(nil) }
    }

    func setIntensity(_ value: Double) {
        let clamped = max(0.0, min(1.0, value))
        blurAlpha = CGFloat(clamped)
        windows.forEach { $0.alphaValue = blurAlpha }
    }

    private func ensureWindows() {
        if windows.count != NSScreen.screens.count {
            rebuildWindows()
        }
    }

    private func rebuildWindows() {
        windows.forEach { $0.orderOut(nil) }
        windows = NSScreen.screens.map { makeWindow(for: $0) }
        if isVisible {
            windows.forEach { $0.orderFrontRegardless() }
        }
    }

    private func makeWindow(for screen: NSScreen) -> NSWindow {
        let window = NSWindow(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false,
            screen: screen
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.alphaValue = blurAlpha
        window.ignoresMouseEvents = true
        window.hasShadow = false
        window.level = .screenSaver
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        window.isReleasedWhenClosed = false

        let effectView = NSVisualEffectView(frame: window.contentView?.bounds ?? screen.frame)
        effectView.autoresizingMask = [.width, .height]
        effectView.blendingMode = .behindWindow
        effectView.material = .fullScreenUI
        effectView.state = .active
        window.contentView = effectView

        return window
    }
}
