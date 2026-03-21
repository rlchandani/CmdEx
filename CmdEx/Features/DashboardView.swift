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

// MARK: - Shortcut Edit Sheet

struct ShortcutEditSheet: View {
    let store: StoreOf<ShortcutsFeature>
    let shortcut: Shortcut?
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var command = ""
    @State private var commandType: CommandType = .shell
    @State private var groupId: UUID?
    @State private var isEnabled = true
    @State private var terminalBehavior: TerminalBehavior = .newTab

    private var isEditing: Bool { shortcut != nil }

    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: isEditing ? "pencil.circle.fill" : "plus.circle.fill")
                    .font(.title2)
                    .foregroundStyle(Color.accentColor)
                Text(isEditing ? "Edit Shortcut" : "New Shortcut")
                    .font(.title3.bold())
            }
            .padding(.top, 4)

            // Input fields card
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Title").font(.caption).foregroundStyle(.secondary)
                    TextField("My SSH Server", text: $title)
                        .textFieldStyle(.roundedBorder)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Command").font(.caption).foregroundStyle(.secondary)
                    TextField("ssh {user}@{host}", text: $command)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                }
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 10).fill(.quaternary.opacity(0.5)))

            // Options card
            VStack(spacing: 0) {
                optionRow {
                    Text("Type")
                    Spacer()
                    Picker("", selection: $commandType) {
                        ForEach(CommandType.allCases) { Text($0.label).tag($0) }
                    }
                    .labelsHidden().frame(width: 180)
                }

                Divider().padding(.horizontal, 12)

                optionRow {
                    Text("Group")
                    Spacer()
                    Picker("", selection: $groupId) {
                        Text("None").tag(UUID?.none)
                        ForEach(store.sortedGroups) { Text($0.name).tag(Optional($0.id)) }
                    }
                    .labelsHidden().frame(width: 180)
                }

                if commandType == .terminal {
                    Divider().padding(.horizontal, 12)
                    optionRow {
                        Text("Opens In")
                        Spacer()
                        Picker("", selection: $terminalBehavior) {
                            ForEach(TerminalBehavior.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                        }
                        .labelsHidden().frame(width: 180)
                    }
                }

                Divider().padding(.horizontal, 12)

                optionRow {
                    Text("Enabled")
                    Spacer()
                    Toggle("", isOn: $isEnabled)
                        .labelsHidden().toggleStyle(.switch)
                }
            }
            .background(RoundedRectangle(cornerRadius: 10).fill(.quaternary.opacity(0.5)))

            // Buttons
            HStack(spacing: 12) {
                Button("Cancel") { dismiss() }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                Spacer()
                Button(isEditing ? "Save" : "Add") { save(); dismiss() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(title.isEmpty || command.isEmpty)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 440)
        .onAppear {
            if let s = shortcut {
                title = s.title; command = s.command; commandType = s.commandType
                groupId = s.groupId; isEnabled = s.isEnabled; terminalBehavior = s.terminalBehavior
            }
        }
    }

    private func optionRow<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        HStack { content() }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
    }

    private func save() {
        if var s = shortcut {
            s.title = title; s.command = command; s.commandType = commandType
            s.groupId = groupId; s.isEnabled = isEnabled; s.terminalBehavior = terminalBehavior
            store.send(.updateShortcut(s))
        } else {
            store.send(.addShortcut(Shortcut(
                title: title, command: command, commandType: commandType,
                isEnabled: isEnabled, groupId: groupId, terminalBehavior: terminalBehavior
            )))
        }
    }
}

// MARK: - Group Edit Sheet

struct GroupEditSheet: View {
    let store: StoreOf<ShortcutsFeature>
    let group: ShortcutGroup?
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""

    var body: some View {
        VStack(spacing: 16) {
            Text(group == nil ? "New Group" : "Edit Group").font(.headline)
            TextField("Group Name", text: $name).textFieldStyle(.roundedBorder)
            HStack {
                Button("Cancel") { dismiss() }
                Spacer()
                Button(group == nil ? "Add" : "Save") { save(); dismiss() }
                    .disabled(name.isEmpty)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(width: 300)
        .onAppear { if let g = group { name = g.name } }
    }

    private func save() {
        if var g = group { g.name = name; store.send(.updateGroup(g)) }
        else { store.send(.addGroup(ShortcutGroup(name: name))) }
    }
}
