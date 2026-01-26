import AppKit

final class BlurOverlayController {
    private var windows: [NSWindow] = []
    private var isVisible = false
    private var screenObserver: NSObjectProtocol?
    private var flashTimer: Timer?
    private var isFlashOn = false
    private let flashInterval: TimeInterval = 0.5
    private let flashAlpha: CGFloat = 0.4

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
        startFlashing()
    }

    func hide() {
        guard isVisible else { return }
        isVisible = false
        stopFlashing()
        windows.forEach { $0.orderOut(nil) }
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
            applyFlashState()
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
        window.backgroundColor = .systemRed
        window.alphaValue = 0.0
        window.ignoresMouseEvents = true
        window.hasShadow = false
        window.level = .screenSaver
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        window.isReleasedWhenClosed = false
        return window
    }

    private func startFlashing() {
        stopFlashing()
        isFlashOn = true
        applyFlashState()
        flashTimer = Timer.scheduledTimer(withTimeInterval: flashInterval, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.isFlashOn.toggle()
            self.applyFlashState()
        }
        if let flashTimer {
            RunLoop.main.add(flashTimer, forMode: .common)
        }
    }

    private func stopFlashing() {
        flashTimer?.invalidate()
        flashTimer = nil
        isFlashOn = false
        applyFlashState()
    }

    private func applyFlashState() {
        let alpha = isFlashOn ? flashAlpha : 0.0
        windows.forEach { $0.alphaValue = alpha }
    }
}
