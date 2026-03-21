import AppKit
import ShortcutBarCore
import SwiftUI

/// Shared panel manager — custom NSPanel with controlled corner radius.
@MainActor
final class PopoverManager {
    private var panel: NSPanel?
    private var eventMonitor: Any?

    var isShown: Bool { panel?.isVisible ?? false }

    func show<V: View>(content: V, size: NSSize, from button: NSStatusBarButton) {
        close()

        let hosting = NSHostingView(rootView: content)
        hosting.frame = NSRect(origin: .zero, size: NSSize(width: SBConstants.popoverWidth, height: 1))
        hosting.setFrameSize(hosting.fittingSize)

        let contentSize = hosting.fittingSize
        let panelSize = NSSize(width: max(contentSize.width, SBConstants.popoverWidth), height: contentSize.height)

        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: panelSize),
            styleMask: [.nonactivatingPanel, .fullSizeContentView],
            backing: .buffered, defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .popUpMenu
        panel.hasShadow = true
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.isMovableByWindowBackground = false
        panel.isReleasedWhenClosed = false
        panel.becomesKeyOnlyIfNeeded = false

        let bg = NSVisualEffectView(frame: NSRect(origin: .zero, size: panelSize))
        bg.material = .popover
        bg.state = .active
        bg.wantsLayer = true
        bg.layer?.cornerRadius = 10
        bg.layer?.masksToBounds = true
        bg.addSubview(hosting)
        hosting.frame = bg.bounds
        hosting.autoresizingMask = [.width, .height]

        panel.contentView = bg

        if let buttonWindow = button.window {
            let buttonRect = button.convert(button.bounds, to: nil)
            let screenRect = buttonWindow.convertToScreen(buttonRect)
            let x = screenRect.midX - panelSize.width / 2
            let y = screenRect.minY - panelSize.height - 4
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        }

        panel.makeKeyAndOrderFront(nil)
        self.panel = panel

        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.close()
        }
    }

    func close() {
        panel?.close()
        panel = nil
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }
}
