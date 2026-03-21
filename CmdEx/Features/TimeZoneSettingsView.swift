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
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Time Zones").font(.title2.bold())

                SettingsComponents.card {
                    VStack(spacing: 0) {
                        ForEach(Array(settings.timeZoneIdentifiers.enumerated()), id: \.offset) { index, id in
                            if index > 0 { Divider().padding(.horizontal, 12) }
                            SettingsComponents.row {
                                HStack {
                                    let tz = TimeZone(identifier: id)
                                    Text(workingHoursIndicator(for: tz))
                                    Text(tz?.abbreviation() ?? id)
                                        .font(.system(.body, design: .monospaced))
                                        .frame(width: 50, alignment: .leading)
                                    Text(friendlyName(id)).foregroundStyle(.secondary)
                                    Spacer()
                                    if settings.timeZoneIdentifiers.count > 1 {
                                        Button {
                                            removeZone(at: index)
                                        } label: {
                                            Image(systemName: "minus.circle.fill").foregroundStyle(.red)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }

                        Divider().padding(.horizontal, 12)

                        SettingsComponents.row {
                            Button { showingAddSheet = true } label: {
                                HStack {
                                    Image(systemName: "plus.circle.fill").foregroundStyle(.green)
                                    Text("Add Time Zone")
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                SettingsComponents.card {
                    SettingsComponents.row {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Indicators").font(.subheadline.bold())
                            HStack(spacing: 16) {
                                Label("Working (9a–6p)", systemImage: "circle.fill")
                                    .foregroundStyle(.green).font(.caption)
                                Label("Early/Late", systemImage: "circle.fill")
                                    .foregroundStyle(.yellow).font(.caption)
                                Label("Night", systemImage: "moon.fill")
                                    .foregroundStyle(.secondary).font(.caption)
                            }
                        }
                    }
                }
            }
            .padding(24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .sheet(isPresented: $showingAddSheet) {
            TimeZonePickerSheet(onAdd: { id in
                addZone(id)
            })
        }
    }

    private func friendlyName(_ id: String) -> String {
        id.replacingOccurrences(of: "_", with: " ").components(separatedBy: "/").last ?? id
    }

    private func workingHoursIndicator(for tz: TimeZone?) -> String {
        guard let tz else { return "❓" }
        let hour = Calendar.current.dateComponents(in: tz, from: Date()).hour ?? 0
        return switch hour {
        case 9..<18: "🟢"
        case 7..<9, 18..<21: "🟡"
        default: "🌙"
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
