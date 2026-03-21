import ComposableArchitecture
import CmdExCore
import SwiftUI

struct DashboardView: View {
    let store: StoreOf<ShortcutsFeature>
    @State private var showingAddShortcut = false
    @State private var showingAddGroup = false
    @State private var editingShortcut: Shortcut?
    @State private var editingGroup: ShortcutGroup?
    @State private var deletingShortcut: Shortcut?
    @State private var deletingGroup: ShortcutGroup?

    // MARK: - Computed

    private var enabledCount: Int { store.shortcuts.filter(\.isEnabled).count }
    private var ungrouped: [Shortcut] {
        store.shortcuts.filter { $0.groupId == nil }.sorted { $0.sortOrder < $1.sortOrder }
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                statsHeader
                if !ungrouped.isEmpty { groupCard(name: "Ungrouped", shortcuts: ungrouped, group: nil) }
                ForEach(store.sortedGroups) { group in
                    let items = store.shortcuts.filter { $0.groupId == group.id }.sorted { $0.sortOrder < $1.sortOrder }
                    groupCard(name: group.name, shortcuts: items, group: group)
                }
            }
            .padding(24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .sheet(isPresented: $showingAddShortcut) { ShortcutEditSheet(store: store, shortcut: nil) }
        .sheet(isPresented: $showingAddGroup) { GroupEditSheet(store: store, group: nil) }
        .sheet(item: $editingShortcut) { s in ShortcutEditSheet(store: store, shortcut: s) }
        .sheet(item: $editingGroup) { g in GroupEditSheet(store: store, group: g) }
        .alert("Delete Shortcut?", isPresented: .init(
            get: { deletingShortcut != nil },
            set: { if !$0 { deletingShortcut = nil } }
        )) {
            Button("Cancel", role: .cancel) { deletingShortcut = nil }
            Button("Delete", role: .destructive) {
                if let s = deletingShortcut { store.send(.deleteShortcut(s.id)) }
                deletingShortcut = nil
            }
        } message: {
            Text("Delete \"\(deletingShortcut?.title ?? "")\"? This cannot be undone.")
        }
        .alert("Delete Group?", isPresented: .init(
            get: { deletingGroup != nil },
            set: { if !$0 { deletingGroup = nil } }
        )) {
            Button("Cancel", role: .cancel) { deletingGroup = nil }
            Button("Delete", role: .destructive) {
                if let g = deletingGroup { store.send(.deleteGroup(g.id)) }
                deletingGroup = nil
            }
        } message: {
            Text("Delete group \"\(deletingGroup?.name ?? "")\"? Shortcuts will become ungrouped.")
        }
    }

    // MARK: - Stats Header

    private var statsHeader: some View {
        HStack(spacing: 12) {
            Image(systemName: "command")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("\(store.shortcuts.count) shortcuts")
                .font(.callout).foregroundStyle(.secondary)
            Text("·").foregroundStyle(.quaternary)
            Text("\(store.groups.count) groups")
                .font(.callout).foregroundStyle(.secondary)
            Text("·").foregroundStyle(.quaternary)
            Text("\(enabledCount) enabled")
                .font(.callout).foregroundStyle(.green)
            Text("·").foregroundStyle(.quaternary)
            Text("\(store.shortcuts.count - enabledCount) disabled")
                .font(.callout).foregroundStyle(.orange)

            Spacer()

            Button { showingAddShortcut = true } label: {
                Label("Add Shortcut", systemImage: "plus.circle.fill")
                    .font(.callout)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)

            Button { showingAddGroup = true } label: {
                Label("Add Group", systemImage: "folder.badge.plus")
                    .font(.callout)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }

    // MARK: - Group Card

    private func groupCard(name: String, shortcuts: [Shortcut], group: ShortcutGroup?) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Card header
            HStack {
                Text(name)
                    .font(.caption.weight(.semibold))
                    .textCase(.uppercase)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(shortcuts.count) item\(shortcuts.count == 1 ? "" : "s")")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .contextMenu {
                if let group {
                    Button("Edit Group") { editingGroup = group }
                    Button("Delete Group", role: .destructive) { deletingGroup = group }
                }
            }

            Divider().padding(.horizontal, 14)

            // Shortcut rows
            ForEach(shortcuts) { shortcut in
                if shortcut.id != shortcuts.first?.id {
                    Divider().padding(.horizontal, 14).opacity(0.5)
                }
                shortcutRow(shortcut)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(.quaternary.opacity(0.5))
        )
    }

    // MARK: - Shortcut Row

    private func shortcutRow(_ shortcut: Shortcut) -> some View {
        HStack(spacing: 10) {
            // Status dot
            Circle()
                .fill(shortcut.isEnabled ? Color.green : Color.gray.opacity(0.4))
                .frame(width: 14, height: 14)
                .padding(4)
                .contentShape(Circle().size(width: 28, height: 28))
                .onTapGesture {
                    var s = shortcut
                    s.isEnabled.toggle()
                    store.send(.updateShortcut(s))
                }
                .accessibilityLabel(shortcut.isEnabled ? "Enabled" : "Disabled")

            // Type icon
            Image(systemName: SBIcon.forCommandType(shortcut.commandType))
                .foregroundStyle(.secondary)
                .frame(width: 16)

            // Name
            Text(shortcut.title)
                .font(.body)
                .lineLimit(1)

            Spacer()

            // Type badge
            Text(shortcut.commandType.label)
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Capsule().fill(.quaternary.opacity(0.5)))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .contextMenu {
            Button("Edit") { editingShortcut = shortcut }
            Button("Delete", role: .destructive) { deletingShortcut = shortcut }
        }
        .accessibilityLabel("\(shortcut.title), \(shortcut.commandType.label)")
        .accessibilityHint("Right-click to edit or delete")
    }

}
