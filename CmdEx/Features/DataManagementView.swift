import AppKit
import ComposableArchitecture
import CmdExCore
import SwiftUI

struct DataManagementView: View {
    let store: StoreOf<AppFeature>
    @State private var importResult: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Data Management").font(.title2.bold())

                // Export
                SettingsComponents.card {
                    VStack(spacing: 0) {
                        SettingsComponents.row {
                            HStack {
                                Image(systemName: "square.and.arrow.up")
                                    .foregroundStyle(.secondary).frame(width: 20)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Export Shortcuts")
                                    Text("Save all shortcuts and groups to a JSON file")
                                        .font(.caption).foregroundStyle(.tertiary)
                                }
                                Spacer()
                                Button("Export…") { exportToFile() }
                                    .controlSize(.small)
                            }
                        }

                        Divider().padding(.horizontal, 12)

                        SettingsComponents.row {
                            HStack {
                                Image(systemName: "doc.on.clipboard")
                                    .foregroundStyle(.secondary).frame(width: 20)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Copy to Clipboard")
                                    Text("Copy shortcuts as JSON to the clipboard")
                                        .font(.caption).foregroundStyle(.tertiary)
                                }
                                Spacer()
                                Button("Copy") { copyToClipboard() }
                                    .controlSize(.small)
                            }
                        }
                    }
                }

                // Import
                SettingsComponents.card {
                    VStack(spacing: 0) {
                        SettingsComponents.row {
                            HStack {
                                Image(systemName: "square.and.arrow.down")
                                    .foregroundStyle(.secondary).frame(width: 20)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Import Shortcuts")
                                    Text("Load shortcuts and groups from a JSON file")
                                        .font(.caption).foregroundStyle(.tertiary)
                                }
                                Spacer()
                                Button("Import…") { importFromFile() }
                                    .controlSize(.small)
                            }
                        }

                        if let importResult {
                            SettingsComponents.row {
                                HStack {
                                    Image(systemName: importResult.hasPrefix("✓") ? "checkmark.circle.fill" : "xmark.circle.fill")
                                        .foregroundStyle(importResult.hasPrefix("✓") ? .green : .red)
                                    Text(importResult)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }

                // Info
                SettingsComponents.card {
                    SettingsComponents.row {
                        HStack {
                            Image(systemName: "info.circle")
                                .foregroundStyle(.secondary).frame(width: 20)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Current Data")
                                let s = store.shortcuts
                                Text("\(s.shortcuts.count) shortcuts · \(s.groups.count) groups")
                                    .font(.caption).foregroundStyle(.tertiary)
                            }
                            Spacer()
                        }
                    }
                }
            }
            .padding(24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: - Export

    private func exportToFile() {
        let panel = NSSavePanel()
        panel.title = "Export Shortcuts"
        panel.nameFieldStringValue = "shortcuts.json"
        panel.allowedContentTypes = [.json]

        guard panel.runModal() == .OK, let url = panel.url else { return }

        let data = StoreData(
            shortcuts: Array(store.shortcuts.shortcuts),
            groups: Array(store.shortcuts.groups),
            lastUsedValues: store.shortcuts.lastUsedValues
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let json = try? encoder.encode(data) {
            try? json.write(to: url)
        }
    }

    private func copyToClipboard() {
        store.send(.shortcuts(.exportJSON))
    }

    // MARK: - Import

    private func importFromFile() {
        let panel = NSOpenPanel()
        panel.title = "Import Shortcuts"
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            let data = try Data(contentsOf: url)
            let storeData = try JSONDecoder().decode(StoreData.self, from: data)

            // Add imported items (merge, don't replace)
            for shortcut in storeData.shortcuts {
                store.send(.shortcuts(.addShortcut(shortcut)))
            }
            for group in storeData.groups {
                store.send(.shortcuts(.addGroup(group)))
            }

            importResult = "✓ Imported \(storeData.shortcuts.count) shortcuts, \(storeData.groups.count) groups"
        } catch {
            importResult = "✗ Failed: \(error.localizedDescription)"
        }
    }
}
