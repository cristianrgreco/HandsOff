import Foundation
import SwiftUI

@main
struct HandsOffApp: App {
    @StateObject private var appState: AppState

    init() {
        if Self.isUITesting {
            let state = AppState(dependencies: .uiTest())
            _appState = StateObject(wrappedValue: state)
#if DEBUG
            UITestWindowController.shared.show(appState: state)
#endif
        } else {
            _appState = StateObject(wrappedValue: AppState())
        }
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(appState: appState)
        } label: {
            Image(systemName: menuBarSymbolName)
                .accessibilityLabel("Hands Off")
        }
        .menuBarExtraStyle(.window)
    }

    private var menuBarSymbolName: String {
        MenuBarStatus.menuBarSymbolName(
            isMonitoring: appState.isMonitoring,
            isStarting: appState.isStarting,
            isAwaitingCamera: appState.isAwaitingCamera,
            isSnoozed: appState.isSnoozed
        )
    }

    private static let isUITesting = ProcessInfo.processInfo.arguments.contains("UI_TESTING")
        || ProcessInfo.processInfo.environment["UITEST"] == "1"
}
