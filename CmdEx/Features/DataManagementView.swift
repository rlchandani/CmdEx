import AppKit
import ComposableArchitecture
import CmdExCore
import SwiftUI

struct DataManagementView: View {
    let store: StoreOf<AppFeature>

    var body: some View {
        Form {
            Section("Export") {
                HStack(alignment: .center, spacing: 8) {
                    Image(systemName: "square.and.arrow.up").settingsIcon()
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Export Shortcuts")
                        Text("Save all shortcuts and groups to a JSON file").settingsCaption()
                    }
                    Spacer()
                    Button("Export…") { exportToFile() }
                        .controlSize(.small)
                }

                HStack(alignment: .center, spacing: 8) {
                    Image(systemName: "doc.on.clipboard").settingsIcon()
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Copy to Clipboard")
                        Text("Copy shortcuts as JSON to the clipboard").settingsCaption()
                    }
                    Spacer()
                    Button("Copy") { store.send(.shortcuts(.exportJSON)) }
                        .controlSize(.small)
                }
            }

            Section("Import") {
                HStack(alignment: .center, spacing: 8) {
                    Image(systemName: "square.and.arrow.down").settingsIcon()
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Import Shortcuts")
                        Text("Load shortcuts and groups from a JSON file").settingsCaption()
                    }
                    Spacer()
                    Button("Import…") { importFromFile() }
                        .controlSize(.small)
                }
            }

            Section("Summary") {
                HStack(alignment: .center, spacing: 8) {
                    Image(systemName: "info.circle").settingsIcon()
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Current Data")
                        let s = store.shortcuts
                        Text("\(s.shortcuts.count) shortcuts · \(s.groups.count) groups").settingsCaption()
                    }
                    Spacer()
                }
            }
        }
        .formStyle(.grouped)
    }

    private func exportToFile() {
        let panel = NSSavePanel()
        panel.title = "Export Shortcuts"
        panel.nameFieldStringValue = "shortcuts.json"
        panel.allowedContentTypes = [.json]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        store.send(.shortcuts(.exportToFile(url)))
    }

    private func importFromFile() {
        let panel = NSOpenPanel()
        panel.title = "Import Shortcuts"
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        store.send(.shortcuts(.importFromFile(url)))
    }
}
