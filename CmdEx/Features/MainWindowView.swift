import ComposableArchitecture
import CmdExCore
import SwiftUI

// MARK: - Warning Banner

struct WarningBanner: View {
    let message: String
    let action: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.shield.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.orange)

            VStack(alignment: .leading, spacing: 2) {
                Text("Missing Permissions")
                    .font(.system(size: 12, weight: .semibold))
                Text(message)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("Fix") { action() }
                .buttonStyle(.bordered)
                .controlSize(.small)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10).fill(.thinMaterial))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.orange.opacity(0.35), lineWidth: 1)
        )
    }
}

// MARK: - Pill Tab Bar

enum AppTab: Equatable, Hashable {
    case shortcuts, general, apps, time, data
}

private struct PillTabBar: View {
    @Binding var selection: AppTab
    @Namespace private var pillAnimation

    private let tabs: [(AppTab, String, String)] = [
        (.shortcuts, "command", "Shortcuts"),
        (.general, "gearshape", "General"),
        (.apps, "app.badge", "Apps"),
        (.time, "clock", "Time"),
        (.data, "square.and.arrow.up.on.square", "Data"),
    ]

    var body: some View {
        HStack(spacing: 6) {
            ForEach(tabs, id: \.0) { tab, icon, label in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selection = tab
                    }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: icon)
                            .font(.system(size: 11))
                        Text(label)
                            .font(.system(size: 12, weight: selection == tab ? .semibold : .regular))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .foregroundStyle(selection == tab ? Color.black : .secondary)
                    .background {
                        if selection == tab {
                            Capsule()
                                .fill(Color.white)
                                .shadow(color: .black.opacity(0.15), radius: 3, y: 1)
                                .matchedGeometryEffect(id: "pill", in: pillAnimation)
                        }
                    }
                    .contentShape(Capsule())
                    .accessibilityLabel(label)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
        )
    }
}

// MARK: - Main Window

struct MainWindowView: View {
    let store: StoreOf<AppFeature>
    @State private var activeTab: AppTab = .shortcuts
    @State private var scrollToPermissions = false

    var body: some View {
        VStack(spacing: 0) {
            if let message = store.permissionStatus.missingMessage {
                WarningBanner(message: message) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        activeTab = .general
                    }
                    Task {
                        try? await Task.sleep(for: .milliseconds(150))
                        scrollToPermissions = true
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            PillTabBar(selection: $activeTab)
                .padding(.top, 12)
                .padding(.bottom, 4)

            Group {
                switch activeTab {
                case .shortcuts:
                    DashboardView(store: store.scope(state: \.shortcuts, action: \.shortcuts))
                case .general:
                    GeneralSettingsView(
                        permissionStatus: store.permissionStatus,
                        scrollToPermissions: $scrollToPermissions
                    )
                case .apps:
                    DefaultAppsSettingsView()
                case .time:
                    TimeZoneSettingsView()
                case .data:
                    DataManagementView(store: store)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .animation(.easeInOut(duration: 0.3), value: store.permissionStatus.anyMissing)
        .frame(minWidth: 750, minHeight: 500)
    }
}
