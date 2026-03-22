import ComposableArchitecture
import CmdExCore
import SwiftUI

struct TimeZoneSettingsView: View {
    @Shared(.appSettings) var settings
    @State private var showingAddSheet = false

    private func removeZone(at index: Int) {
        $settings.withLock { $0.timeZoneIdentifiers.remove(at: index) }
    }

    private func addZone(_ id: String) {
        $settings.withLock { $0.timeZoneIdentifiers.append(id) }
    }

    var body: some View {
        Form {
            Section("Configured Zones") {
                ForEach(Array(settings.timeZoneIdentifiers.enumerated()), id: \.offset) { index, id in
                    HStack(alignment: .center, spacing: 8) {
                        Image(systemName: "clock").settingsIcon()
                        VStack(alignment: .leading, spacing: 2) {
                            Text(friendlyName(id))
                            Text("\(TimeZone(identifier: id)?.abbreviation() ?? id) · \(workingHoursIndicator(for: TimeZone(identifier: id)))")
                                .settingsCaption()
                        }
                        Spacer()
                        if settings.timeZoneIdentifiers.count > 1 {
                            Button {
                                removeZone(at: index)
                            } label: {
                                Image(systemName: "minus.circle.fill").settingsIcon()
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Button { showingAddSheet = true } label: {
                    Label {
                        Text("Add Time Zone")
                    } icon: {
                        Image(systemName: "plus.circle.fill").settingsIcon()
                    }
                }
                .buttonStyle(.plain)
            }

            Section("Legend") {
                HStack(alignment: .center, spacing: 8) {
                    Image(systemName: "info.circle").settingsIcon()
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Working Hours Indicators")
                        HStack(spacing: 16) {
                            Text("🟢 Working (9a–6p)").settingsCaption()
                            Text("🟡 Early/Late").settingsCaption()
                            Text("🌙 Night").settingsCaption()
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .sheet(isPresented: $showingAddSheet) {
            TimeZonePickerSheet(onAdd: { id in addZone(id) })
        }
    }

    private func friendlyName(_ id: String) -> String {
        id.replacingOccurrences(of: "_", with: " ").components(separatedBy: "/").last ?? id
    }

    private func workingHoursIndicator(for tz: TimeZone?) -> String {
        guard let tz else { return "❓" }
        let hour = Calendar.current.dateComponents(in: tz, from: Date()).hour ?? 0
        return switch hour {
        case 9..<18: "🟢 Working"
        case 7..<9, 18..<21: "🟡 Early/Late"
        default: "🌙 Night"
        }
    }
}

struct TimeZonePickerSheet: View {
    let onAdd: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    private var filteredZones: [String] {
        let all = TimeZone.knownTimeZoneIdentifiers
        if searchText.isEmpty { return all }
        let q = searchText.lowercased()
        return all.filter {
            $0.lowercased().contains(q)
            || (TimeZone(identifier: $0)?.abbreviation()?.lowercased().contains(q) ?? false)
        }
    }

    var body: some View {
        VStack(spacing: 12) {
            Text("Add Time Zone").font(.headline)
            TextField("Search zones...", text: $searchText).textFieldStyle(.roundedBorder)
            List(filteredZones, id: \.self) { id in
                Button {
                    onAdd(id)
                    dismiss()
                } label: {
                    HStack {
                        Text(TimeZone(identifier: id)?.abbreviation() ?? "")
                            .font(.system(.body, design: .monospaced))
                            .frame(width: 50, alignment: .leading)
                        Text(id.replacingOccurrences(of: "_", with: " "))
                        Spacer()
                    }
                }
                .buttonStyle(.plain)
            }
            .frame(height: 300)
            Button("Cancel") { dismiss() }
        }
        .padding()
        .frame(width: 400)
    }
}
