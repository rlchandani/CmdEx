import AppKit
import SwiftUI

@MainActor
final class TimeConverterWindowController: NSObject, NSTextFieldDelegate {
    private var panel: NSPanel?
    private var resultLabels: [NSTextField] = []
    private var zones: [TimeZone] = []

    func toggle(near statusItem: NSStatusItem?, zones: [TimeZone]) {
        if let panel, panel.isVisible {
            panel.close()
            self.panel = nil
            return
        }
        self.zones = zones

        let rowHeight: CGFloat = 20
        let padding: CGFloat = 10
        let width: CGFloat = 260
        let height = padding + 28 + 20 + (rowHeight * CGFloat(zones.count)) + padding

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: width, height: height),
            styleMask: [.titled, .fullSizeContentView],
            backing: .buffered, defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.isReleasedWhenClosed = false
        panel.hasShadow = true

        let container = NSView(frame: NSRect(x: 0, y: 0, width: width, height: height))

        // Input field
        let input = NSTextField(frame: NSRect(x: padding, y: height - padding - 28, width: width - padding * 2, height: 24))
        input.placeholderString = "2024-01-15T14:00:00Z"
        input.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        input.bezelStyle = .roundedBezel
        input.delegate = self
        input.target = self
        input.action = #selector(inputChanged(_:))
        container.addSubview(input)

        // Format hint
        let hint = NSTextField(labelWithString: "14:00Z · 2:00 PM · 2024-01-15T14:00Z")
        hint.frame = NSRect(x: padding, y: height - padding - 28 - 16, width: width - padding * 2, height: 14)
        hint.font = .systemFont(ofSize: 10)
        hint.textColor = .tertiaryLabelColor
        container.addSubview(hint)

        // Result rows
        resultLabels = []
        for (i, tz) in zones.enumerated() {
            let y = height - padding - 28 - 20 - (rowHeight * CGFloat(i + 1))
            let label = NSTextField(labelWithString: formatCurrentTime(tz))
            label.frame = NSRect(x: padding, y: y, width: width - padding * 2, height: rowHeight)
            label.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
            container.addSubview(label)
            resultLabels.append(label)
        }

        panel.contentView = container

        // Position near menu bar
        if let button = statusItem?.button, let bWindow = button.window {
            let rect = button.convert(button.bounds, to: nil)
            let screen = bWindow.convertToScreen(rect)
            panel.setFrameTopLeftPoint(NSPoint(x: screen.midX - width / 2, y: screen.minY - 4))
        } else {
            panel.center()
        }

        panel.makeKeyAndOrderFront(nil)
        input.becomeFirstResponder()
        self.panel = panel
    }

    @objc private func inputChanged(_ sender: NSTextField) {
        updateResults(sender.stringValue)
    }

    func controlTextDidChange(_ obj: Notification) {
        guard let field = obj.object as? NSTextField else { return }
        updateResults(field.stringValue)
    }

    private func updateResults(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespaces)

        if trimmed.isEmpty {
            for (i, tz) in zones.enumerated() {
                resultLabels[i].stringValue = formatCurrentTime(tz)
            }
            return
        }

        guard let date = parseInput(trimmed) else {
            for label in resultLabels {
                label.stringValue = ""
            }
            resultLabels.first?.stringValue = "Invalid format"
            resultLabels.first?.textColor = .systemRed
            return
        }

        let fmt = DateFormatter()
        fmt.dateFormat = "h:mm a"
        let utcDay = Calendar.current.dateComponents(in: .gmt, from: date).day ?? 0
        for (i, tz) in zones.enumerated() {
            fmt.timeZone = tz
            let comps = Calendar.current.dateComponents(in: tz, from: date)
            let hour = comps.hour ?? 0
            let tzDay = comps.day ?? 0
            let dayDiff = tzDay - utcDay
            let abbr = (tz.abbreviation(for: date) ?? tz.identifier).padding(toLength: 5, withPad: " ", startingAt: 0)
            let indicator: String = switch hour {
            case 9..<18: "🟢"
            case 7..<9, 18..<21: "🟡"
            default: "🌙"
            }
            let dayLabel: String
            if dayDiff > 0 { dayLabel = "  +\(dayDiff)d" }
            else if dayDiff < 0 { dayLabel = "  \(dayDiff)d" }
            else { dayLabel = "" }
            resultLabels[i].stringValue = "\(indicator)  \(abbr)  \(fmt.string(from: date))\(dayLabel)"
            resultLabels[i].textColor = .labelColor
        }
    }

    private func parseInput(_ text: String) -> Date? {
        let formats: [(String, TimeZone)] = [
            ("yyyy-MM-dd'T'HH:mm:ss'Z'", .gmt),
            ("yyyy-MM-dd'T'HH:mm'Z'", .gmt),
            ("HH:mm:ss'Z'", .gmt),
            ("HH:mm'Z'", .gmt),
            ("HH:mm", .gmt),
            ("h:mm a", .gmt),
        ]
        let today = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        for (fmt, tz) in formats {
            let p = DateFormatter()
            p.dateFormat = fmt
            p.timeZone = tz
            if let d = p.date(from: text) {
                if !fmt.contains("yyyy") {
                    var c = Calendar.current.dateComponents(in: tz, from: d)
                    c.year = today.year; c.month = today.month; c.day = today.day
                    return Calendar.current.date(from: c)
                }
                return d
            }
        }
        return nil
    }

    private func formatCurrentTime(_ tz: TimeZone) -> String {
        let now = Date()
        let fmt = DateFormatter()
        fmt.timeZone = tz
        fmt.dateFormat = "h:mm a"
        let abbr = (tz.abbreviation(for: now) ?? tz.identifier).padding(toLength: 5, withPad: " ", startingAt: 0)
        let hour = Calendar.current.dateComponents(in: tz, from: now).hour ?? 0
        let indicator: String = switch hour {
        case 9..<18: "🟢"
        case 7..<9, 18..<21: "🟡"
        default: "🌙"
        }
        return "\(indicator)  \(abbr)  \(fmt.string(from: now))"
    }
}
