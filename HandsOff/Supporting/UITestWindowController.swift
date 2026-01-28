#if DEBUG
import AppKit
import SwiftUI

final class UITestWindowController: NSWindowController {
    static let shared = UITestWindowController()

    private var hostingView: NSView?

    func show(appState: AppState) {
        if let window, hostingView != nil {
            window.makeKeyAndOrderFront(nil)
            return
        }

        let contentView = MenuBarView(appState: appState)
            .frame(width: 340)
        let hostingView = NSHostingView(rootView: AnyView(contentView))
        self.hostingView = hostingView

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 640),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Hands Off"
        window.isReleasedWhenClosed = false
        window.contentView = hostingView
        window.center()
        window.makeKeyAndOrderFront(nil)

        self.window = window
    }
}
#endif
