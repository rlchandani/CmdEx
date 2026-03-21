import AppKit
import ComposableArchitecture
import CmdExCore
import SwiftUI

// NOTE: This view receives raw arrays and closures instead of a TCA Store because it is
// rendered inside an NSPanel outside the SwiftUI view hierarchy. The popover is always
// dismissed before any data mutations, so live state observation is not needed.
struct MenuPopoverView: View {
    let shortcuts: [Shortcut]
    let groups: [ShortcutGroup]
    let recentShortcuts: [Shortcut]
    let zones: [TimeZone]
    let onExecute: (Shortcut) -> Void
    let onPreferences: () -> Void
    let onQuit: () -> Void
    let onConvertTime: () -> Void
    let onToggleScreenshot: () -> Void
    let screenshotEnabled: Bool

    @State private var search = ""

    // MARK: - Computed

    private var filteredUngrouped: [Shortcut] {
        filterShortcuts(enabledShortcuts(inGroup: nil))
    }

    private var filteredGroups: [(ShortcutGroup, [Shortcut])] {
        groups.sorted { $0.sortOrder < $1.sortOrder }.compactMap { group in
            let items = filterShortcuts(enabledShortcuts(inGroup: group.id))
            return items.isEmpty ? nil : (group, items)
        }
    }

    private var firstFilteredShortcut: Shortcut? {
        filteredUngrouped.first ?? filteredGroups.first?.1.first
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            timeStrip
            searchField
            labeledDivider("SHORTCUTS")
            shortcutsList
            labeledDivider("TOOLS")
            toolsSection
            Divider()
            footer
        }
        .frame(width: SBConstants.popoverWidth)
    }

    // MARK: - Sections

    // NOTE: Date() is used directly here (not @Dependency(\.date)) because this is view-layer
    // display logic, not reducer state. The time strip shows the current wall-clock time and
    // is not part of the testable state machine.
    private func timeLabel(for tz: TimeZone) -> (abbr: String, time: String) {
        let now = Date()
        let fmt = DateFormatter()
        fmt.timeZone = tz
        fmt.dateFormat = "h:mm a"
        let abbr = tz.abbreviation(for: now) ?? tz.identifier
        return (abbr, fmt.string(from: now))
    }

    @ViewBuilder
    private var timeStrip: some View {
        if zones.count >= 2 {
            let left = timeLabel(for: zones[1])
            let right = timeLabel(for: zones[0])
            HStack {
                Text("\(left.abbr)  \(left.time)")
                    .font(.caption.monospaced().weight(.medium))
                    .foregroundStyle(.secondary)
                Spacer()
                Image(systemName: "arrow.right")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Spacer()
                Text("\(right.abbr)  \(right.time)")
                    .font(.caption.monospaced().weight(.medium))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, SBConstants.rowPaddingH)
            .padding(.vertical, SBConstants.rowPaddingV)
            Divider()
        } else if zones.count == 1 {
            let t = timeLabel(for: zones[0])
            Text("\(t.abbr)  \(t.time)")
                .font(.caption.monospaced().weight(.medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, SBConstants.rowPaddingH)
                .padding(.vertical, SBConstants.rowPaddingV)
            Divider()
        }
    }

    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass").foregroundStyle(.tertiary)
            TextField("Search...", text: $search)
                .textFieldStyle(.plain)
                .font(.body)
                .onSubmit {
                    guard search.count >= 2, let shortcut = firstFilteredShortcut else { return }
                    onExecute(shortcut)
                }
        }
        .padding(.horizontal, SBConstants.rowPaddingH)
        .padding(.vertical, SBConstants.rowPaddingV)
    }

    private var shortcutsList: some View {
        let isEmpty = filteredUngrouped.isEmpty && filteredGroups.isEmpty

        return ScrollView {
            VStack(alignment: .leading, spacing: 4) {
                // Recent shortcuts
                if search.isEmpty && !recentShortcuts.isEmpty {
                    shortcutCard {
                        Text("RECENT")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, SBConstants.rowPaddingH)
                            .padding(.top, 6)
                            .padding(.bottom, 2)
                        ForEach(recentShortcuts) { shortcut in
                            shortcutRow(shortcut)
                        }
                    }
                }

                // Ungrouped shortcuts
                if !filteredUngrouped.isEmpty {
                    shortcutCard {
                        ForEach(filteredUngrouped) { shortcut in
                            shortcutRow(shortcut)
                        }
                    }
                }

                // Grouped shortcuts
                ForEach(filteredGroups, id: \.0.id) { group, items in
                    shortcutCard {
                        Text(group.name)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.tertiary)
                            .textCase(.uppercase)
                            .padding(.horizontal, SBConstants.rowPaddingH)
                            .padding(.top, 6)
                            .padding(.bottom, 2)
                        ForEach(items) { shortcut in
                            shortcutRow(shortcut)
                        }
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
            .padding(.horizontal, 6)
            .padding(.vertical, 0)
        }
        .frame(maxHeight: isEmpty ? 30 : SBConstants.scrollMaxHeight)
    }

    private func shortcutCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            content()
        }
    }

    private var toolsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            toolButton(icon: "clock.arrow.2.circlepath", title: "Convert a time…") { onConvertTime() }
            toolButton(icon: "camera.viewfinder", title: "Screenshot watcher", trailing: screenshotEnabled) { onToggleScreenshot() }
        }
        .padding(.bottom, 4)
    }

    private var footer: some View {
        HStack(spacing: 0) {
            HoverButton(action: onPreferences) {
                Spacer()
                Label("Settings", systemImage: "gear").font(.callout)
                Spacer()
            }
            .accessibilityLabel("Open Preferences")
            Divider().frame(height: 20)
            HoverButton(action: onQuit) {
                Spacer()
                Label("Quit", systemImage: "power").font(.callout)
                Spacer()
            }
            .accessibilityLabel("Quit CmdEx")
        }
        .foregroundStyle(.secondary)
        .padding(.vertical, 4)
    }

    // MARK: - Row Builders

    private func labeledDivider(_ label: String) -> some View {
        HStack(spacing: 8) {
            Rectangle().fill(Color.white.opacity(0.15)).frame(height: 1)
            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.tertiary)
                .textCase(.uppercase)
                .layoutPriority(1)
            Rectangle().fill(Color.white.opacity(0.15)).frame(height: 1)
        }
        .padding(.horizontal, SBConstants.rowPaddingH)
        .padding(.vertical, 0)
    }

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
