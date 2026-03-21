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

    init(store: StoreOf<AppFeature>) {
        self.store = store
        super.init()
        setupStatusItem()
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
        store.send(.shortcuts(.executeShortcut(shortcut, resolvedCommand: shortcut.resolvedCommand(with: values))))
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
