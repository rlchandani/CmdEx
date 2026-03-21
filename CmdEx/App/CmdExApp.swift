import SwiftUI
import ComposableArchitecture
import CmdExCore

@main
struct CmdExApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // No visible window — menu bar only. Suppress default window.
        WindowGroup { }.defaultLaunchBehavior(.suppressed)
    }
}
