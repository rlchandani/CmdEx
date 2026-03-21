import ComposableArchitecture
import ShortcutBarCore
import SwiftUI

struct MainWindowView: View {
    let store: StoreOf<AppFeature>

    var body: some View {
        TabView {
            DashboardView(store: store.scope(state: \.shortcuts, action: \.shortcuts))
                .tabItem { Text("Shortcuts") }
            SettingsContainerView(store: store)
                .tabItem { Text("Preferences") }
        }
        .frame(minWidth: 750, minHeight: 500)
    }
}

// MARK: - Settings Container (sidebar + content)

enum SettingsTab: String, CaseIterable, Identifiable {
    case general = "General"
    case apps = "Default Apps"
    case timeZones = "Time Zones"
    case dataManagement = "Data"
    case about = "About"

    var id: String { rawValue }
    var icon: String {
        switch self {
        case .general: "gearshape"
        case .apps: "app.badge"
        case .timeZones: "clock"
        case .dataManagement: "square.and.arrow.up.on.square"
        case .about: "info.circle"
        }
    }
}

struct SettingsContainerView: View {
    let store: StoreOf<AppFeature>
    @State private var selectedTab: SettingsTab = .general

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
                ForEach(SettingsTab.allCases) { tab in
                    Button {
                        selectedTab = tab
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: tab.icon)
                                .frame(width: 20)
                                .foregroundStyle(selectedTab == tab ? .white : .secondary)
                            Text(tab.rawValue)
                                .foregroundStyle(selectedTab == tab ? .white : .primary)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(selectedTab == tab ? Color.accentColor : Color.clear)
                        )
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }
            .padding(12)
            .frame(width: 160)
            .background(Color(nsColor: .windowBackgroundColor))

            Divider()

            Group {
                switch selectedTab {
                case .general: GeneralSettingsView()
                case .apps: DefaultAppsSettingsView()
                case .timeZones: TimeZoneSettingsView()
                case .dataManagement: DataManagementView(store: store)
                case .about: AboutView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
