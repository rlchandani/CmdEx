import AppKit
import ComposableArchitecture
import ShortcutBarCore
import SwiftUI

struct MenuPopoverView: View {
    let shortcuts: [Shortcut]
    let groups: [ShortcutGroup]
    let zones: [TimeZone]
    let onExecute: (Shortcut) -> Void
    let onPreferences: () -> Void
    let onQuit: () -> Void
    let onConvertTime: () -> Void
    let onToggleScreenshot: () -> Void
    let screenshotEnabled: Bool

    @State private var search = ""

    // MARK: - Computed

    private var timeString: String {
        let now = Date()
        let fmt = DateFormatter()
        fmt.dateFormat = "h:mm a"
        return zones.map { tz in
            fmt.timeZone = tz
            let abbr = tz.abbreviation(for: now) ?? tz.identifier
            return "\(abbr) \(fmt.string(from: now))"
        }.joined(separator: " · ")
    }

    private var filteredUngrouped: [Shortcut] {
        filterShortcuts(enabledShortcuts(inGroup: nil))
    }

    private var filteredGroups: [(ShortcutGroup, [Shortcut])] {
        groups.sorted { $0.sortOrder < $1.sortOrder }.compactMap { group in
            let items = filterShortcuts(enabledShortcuts(inGroup: group.id))
            return items.isEmpty ? nil : (group, items)
        }
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            timeStrip
            searchField
            shortcutsList
            Divider()
            toolsSection
            Divider()
            footer
        }
        .frame(width: SBConstants.popoverWidth)
    }

    // MARK: - Sections

    @ViewBuilder
    private var timeStrip: some View {
        if !zones.isEmpty {
            Text(timeString)
                .font(.caption.monospaced().weight(.medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, SBConstants.rowPaddingH)
                .padding(.vertical, SBConstants.rowPaddingV)
            Divider()
        }
    }

    private var searchField: some View {
        Group {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass").foregroundStyle(.tertiary)
                TextField("Search...", text: $search)
                    .textFieldStyle(.plain)
                    .font(.body)
            }
            .padding(.horizontal, SBConstants.rowPaddingH)
            .padding(.vertical, SBConstants.rowPaddingV)
            Divider()
        }
    }

    private var shortcutsList: some View {
        let isEmpty = filteredUngrouped.isEmpty && filteredGroups.isEmpty

        return ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(filteredUngrouped) { shortcut in
                    shortcutRow(shortcut)
                }

                let fg = filteredGroups
                if !filteredUngrouped.isEmpty && !fg.isEmpty {
                    Divider().padding(.vertical, 4)
                }

                ForEach(fg, id: \.0.id) { group, items in
                    Text(group.name)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .textCase(.uppercase)
                        .padding(.horizontal, SBConstants.rowPaddingH)
                        .padding(.top, SBConstants.rowPaddingV)
                        .padding(.bottom, 2)
                    ForEach(items) { shortcut in
                        shortcutRow(shortcut)
                    }
                }

                if isEmpty {
                    Text(search.isEmpty ? "No shortcuts" : "No results")
                        .foregroundStyle(.tertiary)
                        .font(.caption)
                        .padding(.horizontal, SBConstants.rowPaddingH)
                        .padding(.vertical, SBConstants.rowPaddingV)
                }
            }
        }
        .frame(maxHeight: isEmpty ? 30 : SBConstants.scrollMaxHeight)
    }

    private var toolsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            toolButton(icon: "clock.arrow.2.circlepath", title: "Convert a time…") { onConvertTime() }
            toolButton(icon: "camera.viewfinder", title: "Screenshot watcher", trailing: screenshotEnabled) { onToggleScreenshot() }
        }
    }

    private var footer: some View {
        HStack {
            Button { onPreferences() } label: {
                Label("Preferences", systemImage: "gear").font(.callout)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Open Preferences")
            Spacer()
            Button { onQuit() } label: {
                Label("Quit", systemImage: "power").font(.callout)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Quit CmdEx")
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, SBConstants.rowPaddingH)
        .padding(.vertical, SBConstants.rowPaddingV)
    }

    // MARK: - Row Builders

    private func shortcutRow(_ shortcut: Shortcut) -> some View {
        HoverButton { onExecute(shortcut) } label: {
            Image(systemName: SBIcon.forCommandType(shortcut.commandType))
                .frame(width: SBConstants.iconFrameWidth)
            Text(shortcut.title)
                .font(.body)
                .lineLimit(1)
            Spacer()
        }
        .accessibilityLabel("Run \(shortcut.title)")
        .accessibilityHint("\(shortcut.commandType.label): \(shortcut.command)")
    }

    private func toolButton(icon: String, title: String, trailing: Bool = false, action: @escaping () -> Void) -> some View {
        HoverButton(action: action) {
            Image(systemName: icon)
                .frame(width: SBConstants.iconFrameWidth)
            Text(title).font(.callout)
            Spacer()
            if trailing {
                Image(systemName: "checkmark")
                    .foregroundStyle(.green)
                    .font(.caption2.bold())
            }
        }
        .accessibilityLabel(title)
    }

    // MARK: - Helpers

    private func enabledShortcuts(inGroup gid: UUID?) -> [Shortcut] {
        shortcuts.filter { $0.isEnabled && $0.groupId == gid }.sorted { $0.sortOrder < $1.sortOrder }
    }

    private func filterShortcuts(_ list: [Shortcut]) -> [Shortcut] {
        guard !search.isEmpty else { return list }
        let q = search.lowercased()
        return list.filter { $0.title.lowercased().contains(q) || $0.command.lowercased().contains(q) }
    }
}
