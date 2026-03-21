import AppKit
import SwiftUI

struct AboutView: View {
    private let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    private let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("About").font(.title2.bold())

                settingsCard {
                    VStack(spacing: 0) {
                        settingsRow {
                            HStack {
                                Image(systemName: "info.circle")
                                    .foregroundStyle(.secondary).frame(width: 20)
                                Text("Version")
                                Spacer()
                                Text("\(version) (\(build))")
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Divider().padding(.horizontal, 12)

                        settingsRow {
                            HStack {
                                Image(systemName: "doc.text")
                                    .foregroundStyle(.secondary).frame(width: 20)
                                Text("Changelog")
                                Spacer()
                                Button("Show Changelog") { openChangelogWindow() }
                                    .controlSize(.small)
                            }
                        }

                        Divider().padding(.horizontal, 12)

                        settingsRow {
                            HStack {
                                Image(systemName: "curlybraces.square")
                                    .foregroundStyle(.secondary).frame(width: 20)
                                Text("CmdEx is open source")
                                Spacer()
                                Link("Visit GitHub", destination: URL(string: "https://github.com/rlchandani")!)
                                    .font(.callout)
                            }
                        }

                        Divider().padding(.horizontal, 12)

                        settingsRow {
                            HStack {
                                Image(systemName: "person.circle")
                                    .foregroundStyle(.secondary).frame(width: 20)
                                Text("Created by")
                                Spacer()
                                Link("Rohit Chandani", destination: URL(string: "https://rlchandani.dev/")!)
                                    .font(.callout)
                            }
                        }
                    }
                }
            }
            .padding(24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func openChangelogWindow() {
        guard let parentWindow = NSApp.keyWindow else { return }

        var sheetRef: NSPanel?

        let content = VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("v1.0.0").font(.headline)
                    changelogItem("Initial release")
                    changelogItem("Menu bar shortcut manager with groups and submenus")
                    changelogItem("App, shell, terminal, URL, file/folder, and editor commands")
                    changelogItem("Placeholder parameters with last-used memory")
                    changelogItem("iTerm2 support with Terminal.app fallback")
                    changelogItem("Configurable new tab / new window for terminal commands")
                    changelogItem("Drag-and-drop reordering for shortcuts and groups")
                    changelogItem("App icons and SF Symbol fallbacks in menu")
                    changelogItem("Configurable default terminal, browser, and text editor")
                    changelogItem("Launch at login support")
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            Divider()
            HStack {
                Spacer()
                Button("Close") {
                    if let sheet = sheetRef {
                        parentWindow.endSheet(sheet)
                    }
                }
                .keyboardShortcut(.cancelAction)
                .controlSize(.large)
            }
            .padding(12)
        }

        let sheet = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 450, height: 400),
            styleMask: [.titled, .utilityWindow],
            backing: .buffered, defer: false
        )
        sheet.title = "Changelog"
        sheetRef = sheet
        sheet.contentView = NSHostingView(rootView: content)

        parentWindow.beginSheet(sheet) { _ in }
    }

    private func changelogItem(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Text("•").foregroundStyle(.secondary)
            Text(text).font(.body).foregroundStyle(.secondary)
        }
    }
}
