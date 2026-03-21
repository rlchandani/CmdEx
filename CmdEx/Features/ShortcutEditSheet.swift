import ComposableArchitecture
import CmdExCore
import SwiftUI

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
