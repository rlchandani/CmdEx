import ComposableArchitecture
import CmdExCore
import SwiftUI

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
