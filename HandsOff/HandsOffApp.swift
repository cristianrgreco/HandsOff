import SwiftUI

@main
struct HandsOffApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(appState: appState)
        } label: {
            Image(systemName: appState.isMonitoring ? "hand.raised.fill" : "hand.raised")
        }
        .menuBarExtraStyle(.window)
    }
}
