import Cocoa
import ComposableArchitecture
import CmdExCore
import ServiceManagement
import SwiftUI
import UserNotifications

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    static let appStore: Store<AppFeature.State, AppFeature.Action> = {
        // Register live clients BEFORE store creation so TCA captures them
        ScreenshotClient.liveValue = ScreenshotClient(
            start: { ScreenshotWatcher.instance.start() },
            stop: { ScreenshotWatcher.instance.stop() },
            setEnabled: { ScreenshotWatcher.instance.enabled = $0 },
            isEnabled: { ScreenshotWatcher.instance.enabled }
        )
        ToastClient.liveValue = ToastClient(
            show: { ToastWindow.instance.showToast($0) }
        )
        return Store(initialState: AppFeature.State()) { AppFeature() }
    }()

    private var menuBarManager: MenuBarManager!
    private var dashboardWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        SBLog.app.info("Application did finish launching")
        DiagnosticsLogging.bootstrapIfNeeded()

        if Bundle.main.bundleIdentifier != nil {
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
        }

        menuBarManager = MenuBarManager(store: Self.appStore)
        Self.appStore.send(.task)

        syncLaunchAtLogin()
        ScreenshotWatcher.instance.startIfEnabled()
    }

    @objc func openDashboard() {
        // Show in Dock and Cmd+Tab when preferences window is open
        NSApp.setActivationPolicy(.regular)

        if let window = dashboardWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let content = MainWindowView(store: Self.appStore)
            .frame(minWidth: 750, minHeight: 500)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 750, height: 520),
            styleMask: [.titled, .closable, .resizable, .miniaturizable, .fullSizeContentView],
            backing: .buffered, defer: false
        )
        window.title = "CmdEx"
        window.titleVisibility = .visible
        window.toolbarStyle = .unified
        window.contentView = NSHostingView(rootView: content)
        window.center()
        window.makeKeyAndOrderFront(nil)
        window.isReleasedWhenClosed = false
        window.delegate = self
        NSApp.activate(ignoringOtherApps: true)
        dashboardWindow = window
    }

    private func syncLaunchAtLogin() {
        @Shared(.appSettings) var settings
        if settings.launchAtLogin {
            try? SMAppService.mainApp.register()
        } else {
            try? SMAppService.mainApp.unregister()
        }
    }

    // MARK: - NSWindowDelegate

    nonisolated func windowWillClose(_ notification: Notification) {
        Task { @MainActor in
            // Hide from Dock and Cmd+Tab when window closes
            NSApp.setActivationPolicy(.accessory)
        }
    }
}
