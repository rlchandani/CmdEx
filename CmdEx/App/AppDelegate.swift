import Cocoa
import ComposableArchitecture
import CmdExCore
import ServiceManagement
import Sparkle
import SwiftUI

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    static let updaterController = SPUStandardUpdaterController(
        startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil
    )

    static let appStore: Store<AppFeature.State, AppFeature.Action> = {
        ScreenshotClient.liveValue = ScreenshotClient(
            start: { ScreenshotWatcher.instance.start() },
            stop: { ScreenshotWatcher.instance.stop() },
            setEnabled: { ScreenshotWatcher.instance.enabled = $0 },
            isEnabled: { ScreenshotWatcher.instance.enabled }
        )
        ToastClient.liveValue = ToastClient(
            show: { ToastWindow.instance.showToast($0) }
        )
        ClipboardClient.liveValue = ClipboardClient(
            copyString: { string in
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(string, forType: .string)
            }
        )
        return Store(initialState: AppFeature.State()) { AppFeature() }
    }()

    private var menuBarManager: MenuBarManager?
    private var dashboardWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        SBLog.app.info("Application did finish launching")
        DiagnosticsLogging.bootstrapIfNeeded()

        menuBarManager = MenuBarManager(store: Self.appStore)
        Self.appStore.send(.task)

        ScreenshotWatcher.instance.onScreenshotDetected = { path in
            Self.appStore.send(.shortcuts(.screenshotDetected(path: path)))
        }
        ScreenshotWatcher.instance.startIfEnabled()

        // Apply dock icon preference
        @Shared(.appSettings) var settings
        NSApp.setActivationPolicy(settings.showDockIcon ? .regular : .accessory)

        // Show settings window on launch if enabled
        if settings.showSettingsOnLaunch {
            openDashboard()
        }
    }

    @objc func openDashboard() {
        @Shared(.appSettings) var settings
        if settings.showDockIcon {
            NSApp.setActivationPolicy(.regular)
        }

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

    // MARK: - NSWindowDelegate

    nonisolated func windowWillClose(_ notification: Notification) {
        Task { @MainActor in
            @Shared(.appSettings) var settings
            if !settings.showDockIcon {
                NSApp.setActivationPolicy(.accessory)
            }
        }
    }
}
