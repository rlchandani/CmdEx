import AppKit
import ComposableArchitecture
import ShortcutBarCore
import SwiftUI

// MARK: - Shared Settings Binding Helper — removed, using makeBinding in each view

// MARK: - General Settings

struct GeneralSettingsView: View {
    @Shared(.appSettings) var settings

    private func makeBinding<T>(_ keyPath: WritableKeyPath<AppSettings, T>) -> Binding<T> {
        Binding<T>(
            get: { settings[keyPath: keyPath] },
            set: { val in $settings.withLock { $0[keyPath: keyPath] = val } }
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("General").font(.title2.bold())

                settingsCard {
                    VStack(spacing: 0) {
                        settingsRow {
                            HStack {
                                Image(systemName: "power")
                                    .foregroundStyle(.secondary).frame(width: 20)
                                Text("Launch at Login")
                                Spacer()
                                Toggle("", isOn: makeBinding(\.launchAtLogin))
                                    .labelsHidden().toggleStyle(.switch)
                            }
                        }

                        Divider().padding(.horizontal, 12)

                        settingsRow {
                            HStack {
                                Image(systemName: "camera.viewfinder")
                                    .foregroundStyle(.secondary).frame(width: 20)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Copy screenshot path to clipboard")
                                    Text("Watches for new screenshots and copies the file path")
                                        .font(.caption).foregroundStyle(.tertiary)
                                }
                                Spacer()
                                Toggle("", isOn: makeBinding(\.screenshotWatcherEnabled))
                                    .labelsHidden().toggleStyle(.switch)
                            }
                        }
                    }
                }
            }
            .padding(24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

// MARK: - Default Apps Settings

struct DefaultAppsSettingsView: View {
    @Shared(.appSettings) var settings

    @State private var terminals: [(String, String)] = []
    @State private var browsers: [(String, String)] = []
    @State private var editors: [(String, String)] = []

    private func makeBinding<T>(_ keyPath: WritableKeyPath<AppSettings, T>) -> Binding<T> {
        Binding<T>(
            get: { settings[keyPath: keyPath] },
            set: { val in $settings.withLock { $0[keyPath: keyPath] = val } }
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Default Applications").font(.title2.bold())

                settingsCard {
                    VStack(spacing: 0) {
                        appPickerRow(
                            icon: "terminal", label: "Terminal",
                            selection: makeBinding(\.preferredTerminal),
                            options: terminals, allowSystemDefault: false
                        )

                        Divider().padding(.horizontal, 12)

                        appPickerRow(
                            icon: "globe", label: "Browser",
                            selection: makeBinding(\.preferredBrowser),
                            options: browsers, allowSystemDefault: true
                        )

                        Divider().padding(.horizontal, 12)

                        appPickerRow(
                            icon: "pencil.line", label: "Text Editor",
                            selection: makeBinding(\.preferredEditor),
                            options: editors, allowSystemDefault: true
                        )
                    }
                }
            }
            .padding(24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear { detectApps() }
    }

    private func appPickerRow(
        icon: String, label: String,
        selection: Binding<String>,
        options: [(String, String)],
        allowSystemDefault: Bool
    ) -> some View {
        settingsRow {
            HStack {
                Image(systemName: icon).foregroundStyle(.secondary).frame(width: 20)
                Text(label)
                Spacer()
                Picker("", selection: selection) {
                    if allowSystemDefault { Text("System Default").tag("") }
                    ForEach(options, id: \.0) { id, name in Text(name).tag(id) }
                }
                .labelsHidden().frame(width: 170)
                Button("Browse…") { browseForApp(selection: selection) }.controlSize(.small)
            }
        }
    }

    private func browseForApp(selection: Binding<String>) {
        let panel = NSOpenPanel()
        panel.title = "Select Application"
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK, let url = panel.url,
              let bundle = Bundle(url: url), let bundleId = bundle.bundleIdentifier else { return }
        let name = bundle.infoDictionary?["CFBundleDisplayName"] as? String
            ?? bundle.infoDictionary?["CFBundleName"] as? String
            ?? url.deletingPathExtension().lastPathComponent
        addIfMissing(bundleId: bundleId, name: name)
        selection.wrappedValue = bundleId
    }

    private func addIfMissing(bundleId: String, name: String) {
        let entry = (bundleId, name)
        if !terminals.contains(where: { $0.0 == bundleId }) { terminals.append(entry) }
        if !browsers.contains(where: { $0.0 == bundleId }) { browsers.append(entry) }
        if !editors.contains(where: { $0.0 == bundleId }) { editors.append(entry) }
    }

    private func detectApps() {
        terminals = detectInstalledApps(matching: [
            "com.googlecode.iterm2", "com.apple.Terminal",
            "dev.warp.Warp-Stable", "io.alacritty",
            "com.github.wez.wezterm", "net.kovidgoyal.kitty", "co.zeit.hyper",
        ])
        browsers = discoverApps(toOpen: URL(string: "https://example.com")!)
        editors = discoverApps(toOpen: URL(fileURLWithPath: "/tmp/dummy.txt"))
    }

    private func discoverApps(toOpen url: URL) -> [(String, String)] {
        NSWorkspace.shared.urlsForApplications(toOpen: url)
            .compactMap { appURL -> (String, String)? in
                guard let bundle = Bundle(url: appURL),
                      let bundleId = bundle.bundleIdentifier else { return nil }
                let name = bundle.infoDictionary?["CFBundleDisplayName"] as? String
                    ?? bundle.infoDictionary?["CFBundleName"] as? String
                    ?? appURL.deletingPathExtension().lastPathComponent
                return (bundleId, name)
            }
            .sorted { $0.1.localizedCaseInsensitiveCompare($1.1) == .orderedAscending }
    }

    private func detectInstalledApps(matching bundleIds: [String]) -> [(String, String)] {
        bundleIds.compactMap { bundleId -> (String, String)? in
            guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) else { return nil }
            let bundle = Bundle(url: url)
            let name = bundle?.infoDictionary?["CFBundleDisplayName"] as? String
                ?? bundle?.infoDictionary?["CFBundleName"] as? String
                ?? url.deletingPathExtension().lastPathComponent
            return (bundleId, name)
        }
    }
}

// MARK: - Shared Components

func settingsCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
    content()
        .background(RoundedRectangle(cornerRadius: 10).fill(.quaternary.opacity(0.5)))
}

func settingsRow<Content: View>(@ViewBuilder content: () -> Content) -> some View {
    content()
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
}
