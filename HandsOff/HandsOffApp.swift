import SwiftUI

@main
struct HandsOffApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(appState: appState)
        } label: {
            Image(systemName: menuBarSymbolName)
        }
        .menuBarExtraStyle(.window)
    }

    private var menuBarSymbolName: String {
        if !appState.isMonitoring {
            return "hand.raised"
        }
        if appState.isSnoozed {
            return "hand.raised.slash.fill"
        }
        return "hand.raised.fill"
    }
}
