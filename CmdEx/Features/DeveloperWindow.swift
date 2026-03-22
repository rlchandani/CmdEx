import AppKit
import CmdExCore
import SwiftUI

@MainActor
enum DeveloperWindow {
    private static var window: NSWindow?

    static func show() {
        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 220),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered, defer: false
        )
        window.title = "Developer"
        window.titleVisibility = .visible
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: DeveloperView())
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.window = window
    }
}

private struct DeveloperView: View {
    @State private var copied = false

    private var resetCommand: String {
        let bundleId = Bundle.main.bundleIdentifier ?? SBConstants.bundleIdentifier
        let processName = ProcessInfo.processInfo.processName
        let appPath = Bundle.main.bundlePath
        let services = ["Accessibility", "AppleEvents", "ListenEvent", "SystemPolicyAllFiles"]
        let resets = services.map { "tccutil reset \($0) \(bundleId)" }.joined(separator: " && ")
        return "killall \"\(processName)\" 2>/dev/null; \(resets) && open \"\(appPath)\""
    }

    var body: some View {
        Form {
            Section("Permissions") {
                HStack(alignment: .center, spacing: 8) {
                    Image(systemName: "arrow.counterclockwise.circle").settingsIcon()
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Reset All Permissions")
                            .font(.body.weight(.medium))
                        Text("Paste in Terminal to reset TCC permissions and relaunch the app.")
                            .settingsCaption()
                    }
                    Spacer()
                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(resetCommand, forType: .string)
                        copied = true
                        Task {
                            try? await Task.sleep(for: .seconds(2))
                            copied = false
                        }
                    } label: {
                        Label(
                            copied ? "Copied!" : "Copy Command",
                            systemImage: copied ? "checkmark.circle.fill" : "doc.on.doc"
                        )
                    }
                    .controlSize(.small)
                    .tint(copied ? .green : nil)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 420, height: 220)
    }
}
