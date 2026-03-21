import ShortcutBarCore
import AppKit
import SwiftUI

// MARK: - Invisible Window (matches Hex's pattern)

class InvisibleWindow: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    private var currentScreen: NSScreen?
    private nonisolated(unsafe) var mouseMonitor: Any?

    init() {
        let screen = NSScreen.main ?? NSScreen.screens[0]
        super.init(
            contentRect: screen.frame,
            styleMask: [.fullSizeContentView, .borderless, .utilityWindow, .nonactivatingPanel],
            backing: .buffered, defer: false
        )
        level = .statusBar
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        hidesOnDeactivate = false
        canHide = false
        ignoresMouseEvents = true
        collectionBehavior = [.fullScreenAuxiliary, .canJoinAllSpaces, .stationary, .ignoresCycle]

        updateToScreenWithMouse()

        NotificationCenter.default.addObserver(self, selector: #selector(screenDidChange),
                                               name: NSApplication.didChangeScreenParametersNotification, object: nil)
        mouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { [weak self] _ in
            self?.checkForScreenChange()
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        if let monitor = mouseMonitor { NSEvent.removeMonitor(monitor) }
    }

    private func updateToScreenWithMouse() {
        let loc = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(loc) }) else { return }
        currentScreen = screen
        setFrame(screen.frame, display: true)
    }

    private func checkForScreenChange() {
        let loc = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(loc) }),
              screen !== currentScreen else { return }
        currentScreen = screen
        setFrame(screen.frame, display: true)
    }

    @objc private func screenDidChange(_ n: Notification) { updateToScreenWithMouse() }

    static func fromView<V: View>(_ view: V) -> InvisibleWindow {
        let w = InvisibleWindow()
        w.contentView = NSHostingView(rootView: view)
        return w
    }
}

// MARK: - Toast SwiftUI View

struct ToastOverlay: View {
    @Binding var message: String
    @Binding var isVisible: Bool

    var body: some View {
        VStack {
            if isVisible {
                HStack(spacing: 6) {
                    Text("📋")
                    Text(message)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(.ultraThinMaterial)
                        .environment(\.colorScheme, .dark)
                )
                .shadow(color: .black.opacity(0.3), radius: 8, y: 2)
                .transition(.move(edge: .top).combined(with: .opacity))
                .padding(.top, SBConstants.toastTopPadding)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .animation(.spring(duration: SBConstants.toastFadeInDuration), value: isVisible)
    }
}

// MARK: - Toast Controller

@MainActor
final class ToastWindow {
    static let shared = ToastWindow()

    private var window: InvisibleWindow?
    private var message = ""
    private var isVisible = false
    private var hideTask: Task<Void, Never>?

    // Bindings for SwiftUI
    private var messageBinding: Binding<String> {
        Binding(get: { [weak self] in self?.message ?? "" },
                set: { [weak self] in self?.message = $0 })
    }
    private var visibleBinding: Binding<Bool> {
        Binding(get: { [weak self] in self?.isVisible ?? false },
                set: { [weak self] in self?.isVisible = $0 })
    }

    private func ensureWindow() {
        guard window == nil else { return }
        let overlay = ToastOverlay(message: messageBinding, isVisible: visibleBinding)
        window = InvisibleWindow.fromView(overlay)
        window?.makeKeyAndOrderFront(nil)
    }

    static func show(_ text: String) {
        shared.showToast(text)
    }

    private func showToast(_ text: String) {
        ensureWindow()
        hideTask?.cancel()
        message = text
        isVisible = true
        // Force SwiftUI update
        refreshView()

        hideTask = Task {
            try? await Task.sleep(for: .seconds(SBConstants.toastDisplayDuration))
            guard !Task.isCancelled else { return }
            isVisible = false
            refreshView()
        }
    }

    private func refreshView() {
        let overlay = ToastOverlay(message: messageBinding, isVisible: visibleBinding)
        window?.contentView = NSHostingView(rootView: overlay)
    }
}
