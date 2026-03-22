import AppKit
import ComposableArchitecture
import CmdExCore
import SwiftUI

@MainActor
final class MenuBarManager: NSObject {
    private var statusItem: NSStatusItem?
    private let store: StoreOf<AppFeature>
    private let converterController = TimeConverterWindowController()
    private let popover = PopoverManager()
    // SAFETY: Only written once in registerHotKey() on the main actor, read in deinit
    // which runs on the main actor for @MainActor classes. The nonisolated(unsafe) is
    // required because deinit is technically nonisolated in Swift 6.
    private nonisolated(unsafe) var hotKeyMonitor: Any?
    // SAFETY: Same as hotKeyMonitor — written once in registerHotKey(), read in deinit.
    private nonisolated(unsafe) var localHotKeyMonitor: Any?

    init(store: StoreOf<AppFeature>) {
        self.store = store
        super.init()
        setupStatusItem()
        registerHotKey()
    }

    deinit {
        if let monitor = hotKeyMonitor { NSEvent.removeMonitor(monitor) }
        if let monitor = localHotKeyMonitor { NSEvent.removeMonitor(monitor) }
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "command", accessibilityDescription: "CmdEx")
            button.target = self
            button.action = #selector(statusItemClicked(_:))
            button.sendAction(on: [.leftMouseUp])
        }
    }

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        showPopover()
    }

    /// Registers Cmd+Shift+K as a global hotkey to toggle the popover.
    private func registerHotKey() {
        // Global monitor — works when app is not focused (requires Accessibility permission)
        hotKeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.modifierFlags.contains([.command, .shift]),
                  event.keyCode == 40 else { return }
            Task { @MainActor [weak self] in
                self?.showPopover()
            }
        }

        // Local monitor — works when app is focused
        localHotKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.modifierFlags.contains([.command, .shift]),
                  event.keyCode == 40 else { return event }
            Task { @MainActor [weak self] in
                self?.showPopover()
            }
            return nil
        }

        // Prompt for Accessibility permissions if not granted
        if !AXIsProcessTrusted() {
            // "AXTrustedCheckOptionPrompt" is the string value of kAXTrustedCheckOptionPrompt.
            // Using the literal avoids Swift 6 concurrency warnings on the C global.
            let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
            AXIsProcessTrustedWithOptions(options)
        }
    }

    // MARK: - Popover

    private func showPopover() {
        guard let button = statusItem?.button else { return }
        if popover.isShown { popover.close(); return }

        let shortcutsState = store.state.shortcuts
        let settings = store.state.settings
        let zones = settings.timeZoneIdentifiers.compactMap { TimeZone(identifier: $0) }

        let view = MenuPopoverView(
            shortcuts: Array(shortcutsState.shortcuts),
            groups: Array(shortcutsState.groups),
            recentShortcuts: shortcutsState.recentShortcuts,
            zones: zones,
            onExecute: { [weak self] shortcut in
                self?.popover.close()
                self?.executeShortcut(shortcut)
            },
            onPreferences: { [weak self] in
                self?.popover.close()
                NSApp.sendAction(#selector(AppDelegate.openDashboard), to: nil, from: nil)
            },
            onQuit: { NSApp.terminate(nil) },
            onConvertTime: { [weak self] in
                self?.popover.close()
                Task { @MainActor [weak self] in
                    try? await Task.sleep(for: .milliseconds(100))
                    guard let self else { return }
                    self.converterController.toggle(near: self.statusItem, zones: zones)
                    NSApp.activate(ignoringOtherApps: true)
                }
            },
            onToggleScreenshot: { [weak self] in
                self?.store.send(.shortcuts(.toggleScreenshotWatcher))
                self?.popover.close()
            },
            screenshotEnabled: settings.screenshotWatcherEnabled
        )
        popover.show(
            content: view,
            size: NSSize(width: SBConstants.popoverWidth, height: 0),
            from: button
        )
    }

    // MARK: - Execution

    private func executeShortcut(_ shortcut: Shortcut) {
        if shortcut.placeholders.isEmpty {
            store.send(.shortcuts(.executeShortcut(shortcut, resolvedCommand: shortcut.command)))
            flashIcon()
        } else {
            promptForPlaceholders(shortcut: shortcut)
        }
    }

    private func promptForPlaceholders(shortcut: Shortcut) {
        let lastUsed = store.state.shortcuts.getLastUsed(for: shortcut.id)
        let alert = NSAlert()
        alert.messageText = shortcut.title
        alert.informativeText = "Enter values for parameters:"
        alert.addButton(withTitle: "Run")
        alert.addButton(withTitle: "Cancel")

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 8
        var fields: [(String, NSTextField)] = []

        for name in shortcut.placeholders {
            let label = NSTextField(labelWithString: "{\(name)}:")
            let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 250, height: 24))
            field.stringValue = lastUsed[name] ?? ""
            field.placeholderString = name
            let row = NSStackView(views: [label, field])
            row.orientation = .horizontal
            row.spacing = 8
            field.widthAnchor.constraint(greaterThanOrEqualToConstant: 200).isActive = true
            stack.addArrangedSubview(row)
            fields.append((name, field))
        }

        alert.accessoryView = stack
        alert.window.initialFirstResponder = fields.first?.1
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        var values: [String: String] = [:]
        for (name, field) in fields { values[name] = field.stringValue }
        store.send(.shortcuts(.saveLastUsed(shortcut.id, values)))
        let resolved: String
        switch shortcut.commandType {
        case .shell, .terminal:
            resolved = shortcut.resolvedCommandShellEscaped(with: values)
        case .app, .url, .fileOrFolder, .editor:
            resolved = shortcut.resolvedCommand(with: values)
        }
        store.send(.shortcuts(.executeShortcut(shortcut, resolvedCommand: resolved)))
        flashIcon()
    }

    private func flashIcon() {
        guard let button = statusItem?.button else { return }
        let original = button.image
        button.image = NSImage(systemSymbolName: "checkmark.circle.fill", accessibilityDescription: "Done")
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(SBConstants.iconFlashDuration))
            button.image = original
        }
    }
}
