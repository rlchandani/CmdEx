import CmdExCore
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

    private var title: String {
        // Extract filename if message contains ":"
        if message.contains(":") {
            return String(message.prefix(while: { $0 != ":" }))
        }
        return message
    }

    private var detail: String? {
        guard let colonIndex = message.firstIndex(of: ":") else { return nil }
        let after = message[message.index(after: colonIndex)...]
        let trimmed = after.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? nil : trimmed
    }

    var body: some View {
        VStack {
            Spacer()
                .frame(height: SBConstants.toastTopPadding)

            if isVisible {
                VStack(alignment: .leading, spacing: 6) {
                    // App header
                    HStack(spacing: 6) {
                        Image(systemName: "command")
                            .font(.caption.bold())
                            .foregroundStyle(.white.opacity(0.6))
                        Text("CmdEx")
                            .font(.caption.bold())
                            .foregroundStyle(.white.opacity(0.6))
                        Spacer()
                        Text("now")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.3))
                    }

                    // Message
                    HStack(spacing: 6) {
                        Text("📋")
                            .font(.callout)
                        Text(title)
                            .font(.callout.weight(.semibold))
                            .foregroundStyle(.white)
                    }

                    // Detail (filename)
                    if let detail {
                        Text(detail)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.7))
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
                .padding(14)
                .frame(width: 320, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(.ultraThinMaterial)
                        .environment(\.colorScheme, .dark)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(.white.opacity(0.1), lineWidth: 0.5)
                )
                .shadow(color: .black.opacity(0.4), radius: 16, y: 4)
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .padding(.trailing, 16)
        .animation(.spring(duration: 0.35, bounce: 0.2), value: isVisible)
    }
}

// MARK: - Toast Controller

@MainActor
final class ToastWindow {
    static let instance = ToastWindow()

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
        instance.showToast(text)
    }

    func showToast(_ text: String) {
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
