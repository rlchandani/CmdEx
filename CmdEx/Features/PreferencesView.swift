import AppKit
import ComposableArchitecture
import CmdExCore
import ServiceManagement
import Sparkle
import SwiftUI

// MARK: - General Settings

struct GeneralSettingsView: View {
    @Shared(.appSettings) var settings
    let permissionStatus: PermissionStatus
    @Binding var scrollToPermissions: Bool
    @State private var highlightPermissions = false
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var devTapCount = 0

    private let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    private let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"

    private func makeBinding<T>(_ keyPath: WritableKeyPath<AppSettings, T>) -> Binding<T> {
        Binding<T>(
            get: { settings[keyPath: keyPath] },
            set: { val in $settings.withLock { $0[keyPath: keyPath] = val } }
        )
    }

    var body: some View {
        ScrollViewReader { proxy in
            Form {
                // MARK: - Behavior

                Section("Behavior") {
                    HStack(alignment: .center, spacing: 8) {
                        Image(systemName: "power").settingsIcon()
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Open on Login")
                            Text("Start CmdEx when you log in to your Mac").settingsCaption()
                        }
                        Spacer()
                        Toggle("", isOn: Binding(
                            get: { launchAtLogin },
                            set: { newValue in
                                if newValue {
                                    try? SMAppService.mainApp.register()
                                } else {
                                    try? SMAppService.mainApp.unregister()
                                }
                                launchAtLogin = SMAppService.mainApp.status == .enabled
                            }
                        ))
                        .labelsHidden().toggleStyle(.switch).controlSize(.small)
                    }

                    HStack(alignment: .center, spacing: 8) {
                        Image(systemName: "dock.rectangle").settingsIcon()
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Show Dock Icon")
                            Text("Show CmdEx in the Dock and Cmd+Tab switcher").settingsCaption()
                        }
                        Spacer()
                        Toggle("", isOn: Binding(
                            get: { settings.showDockIcon },
                            set: { newValue in
                                $settings.withLock { $0.showDockIcon = newValue }
                                NSApp.setActivationPolicy(newValue ? .regular : .accessory)
                            }
                        ))
                        .labelsHidden().toggleStyle(.switch).controlSize(.small)
                    }

                    HStack(alignment: .center, spacing: 8) {
                        Image(systemName: "macwindow").settingsIcon()
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Show Settings on Launch")
                            Text("Open the settings window when CmdEx starts").settingsCaption()
                        }
                        Spacer()
                        Toggle("", isOn: makeBinding(\.showSettingsOnLaunch))
                            .labelsHidden().toggleStyle(.switch).controlSize(.small)
                    }

                    HStack(alignment: .center, spacing: 8) {
                        Image(systemName: "camera.viewfinder").settingsIcon()
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Copy Screenshot Path to Clipboard")
                            Text("Watches for new screenshots and copies the file path").settingsCaption()
                        }
                        Spacer()
                        Toggle("", isOn: makeBinding(\.screenshotWatcherEnabled))
                            .labelsHidden().toggleStyle(.switch).controlSize(.small)
                    }
                }

                // MARK: - Permissions

                Section("Permissions") {
                    permissionRow(
                        icon: "hand.raised",
                        title: "Accessibility",
                        detail: permissionStatus.accessibility
                            ? "Required for global hotkey (⌘⇧K)"
                            : "Required for global hotkey (⌘⇧K). Toggle CmdEx on in System Settings.",
                        granted: permissionStatus.accessibility,
                        action: {
                            let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
                            AXIsProcessTrustedWithOptions(options)
                            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
                        }
                    )

                    permissionRow(
                        icon: "gearshape.2",
                        title: "Automation",
                        detail: permissionStatus.automation
                            ? "Required to send commands to Terminal and iTerm2"
                            : "Run a terminal shortcut once — macOS will prompt you to allow it",
                        granted: permissionStatus.automation,
                        buttonLabel: "Open…",
                        action: {
                            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation")!)
                        }
                    )

                    permissionRow(
                        icon: "folder.badge.gearshape",
                        title: "Full Disk Access",
                        detail: permissionStatus.fullDiskAccess
                            ? "Recommended for shell commands accessing protected paths"
                            : "Click Open, then toggle CmdEx on (or click + to add it)",
                        granted: permissionStatus.fullDiskAccess,
                        buttonLabel: "Open…",
                        action: {
                            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!)
                        }
                    )
                }
                .id("permissionsSection")
                .listRowBackground(
                    highlightPermissions
                        ? Color.orange.opacity(0.08)
                        : Color.clear
                )

                // MARK: - About

                Section("About") {
                    Label {
                        HStack {
                            Text("Version")
                            Spacer()
                            Text("\(version) (\(build))")
                                .foregroundStyle(.secondary)
                                .onTapGesture {
                                    devTapCount += 1
                                    if devTapCount == 7 {
                                        DeveloperWindow.show()
                                        devTapCount = 0
                                    }
                                }
                        }
                    } icon: {
                        Image(systemName: "info.circle").settingsIcon()
                    }

                    Label {
                        HStack {
                            Text("Updates")
                            Spacer()
                            Button("Check for Updates") {
                                AppDelegate.updaterController.checkForUpdates(nil)
                            }
                            .controlSize(.small)
                        }
                    } icon: {
                        Image(systemName: "arrow.triangle.2.circlepath").settingsIcon()
                    }

                    Label {
                        HStack {
                            Text("Changelog")
                            Spacer()
                            Button("Show Changelog") { openChangelogWindow() }
                                .controlSize(.small)
                        }
                    } icon: {
                        Image(systemName: "doc.text").settingsIcon()
                    }

                    Label {
                        HStack {
                            Text("Source Code")
                            Spacer()
                            Link("GitHub", destination: SBURLs.github)
                                .font(.callout)
                        }
                    } icon: {
                        Image(systemName: "curlybraces.square").settingsIcon()
                    }

                    Label {
                        HStack {
                            Text("Created by")
                            Spacer()
                            Link("Rohit Chandani", destination: SBURLs.author)
                                .font(.callout)
                        }
                    } icon: {
                        Image(systemName: "person.circle").settingsIcon()
                    }
                }
            }
            .formStyle(.grouped)
            .onAppear {
                launchAtLogin = SMAppService.mainApp.status == .enabled
            }
            .onChange(of: scrollToPermissions) { _, shouldScroll in
                guard shouldScroll else { return }
                scrollToPermissions = false
                withAnimation { proxy.scrollTo("permissionsSection", anchor: .center) }
                withAnimation(.easeInOut(duration: 0.3)) { highlightPermissions = true }
                Task {
                    try? await Task.sleep(for: .seconds(1.5))
                    withAnimation(.easeInOut(duration: 0.5)) { highlightPermissions = false }
                }
            }
        }
    }

    // MARK: - Permission Row

    private func permissionRow(
        icon: String, title: String, detail: String,
        granted: Bool, buttonLabel: String = "Grant…",
        action: @escaping () -> Void
    ) -> some View {
        HStack(alignment: .center, spacing: 8) {
            Image(systemName: icon).settingsIcon()
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(title)
                    if !granted {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
                Text(detail).settingsCaption()
            }
            Spacer()
            if !granted {
                Button(buttonLabel) { action() }
                    .controlSize(.small)
            } else {
                Label("Granted", systemImage: "checkmark.circle.fill")
                    .font(.callout)
                    .foregroundStyle(.green)
            }
        }
    }

    // MARK: - Changelog

    private func openChangelogWindow() {
        guard let parentWindow = NSApp.keyWindow else { return }

        var sheetRef: NSPanel?

        let content = VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("v\(version)").font(.headline)
                    Text(SBConstants.changelog)
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            Divider()
            HStack {
                Spacer()
                Button("Close") {
                    if let sheet = sheetRef {
                        parentWindow.endSheet(sheet)
                    }
                }
                .keyboardShortcut(.cancelAction)
                .controlSize(.large)
            }
            .padding(12)
        }

        let sheet = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 450, height: 400),
            styleMask: [.titled, .utilityWindow],
            backing: .buffered, defer: false
        )
        sheet.title = "Changelog"
        sheetRef = sheet
        sheet.contentView = NSHostingView(rootView: content)

        parentWindow.beginSheet(sheet) { _ in }
    }
}

// MARK: - Default Apps Settings

struct DefaultAppsSettingsView: View {
    @Shared(.appSettings) var settings

    @State private var terminals: [(String, String)] = []
    @State private var browsers: [(String, String)] = []
    @State private var editors: [(String, String)] = []

    private static let customTag = "__custom__"

    private func makeBinding<T>(_ keyPath: WritableKeyPath<AppSettings, T>) -> Binding<T> {
        Binding<T>(
            get: { settings[keyPath: keyPath] },
            set: { val in $settings.withLock { $0[keyPath: keyPath] = val } }
        )
    }

    var body: some View {
        Form {
            Section("Applications") {
                appPickerRow(
                    icon: "terminal", label: "Terminal",
                    selection: makeBinding(\.preferredTerminal),
                    options: terminals, allowSystemDefault: false
                )
                appPickerRow(
                    icon: "globe", label: "Browser",
                    selection: makeBinding(\.preferredBrowser),
                    options: browsers, allowSystemDefault: true
                )
                appPickerRow(
                    icon: "pencil.line", label: "Text Editor",
                    selection: makeBinding(\.preferredEditor),
                    options: editors, allowSystemDefault: true
                )
            }
        }
        .formStyle(.grouped)
        .onAppear { detectApps() }
    }

    private func appPickerRow(
        icon: String, label: String,
        selection: Binding<String>,
        options: [(String, String)],
        allowSystemDefault: Bool
    ) -> some View {
        Label {
            HStack {
                Text(label)
                Spacer()
                Picker("", selection: Binding(
                    get: { selection.wrappedValue },
                    set: { newValue in
                        if newValue == Self.customTag {
                            browseForApp(selection: selection)
                        } else {
                            selection.wrappedValue = newValue
                        }
                    }
                )) {
                    if allowSystemDefault { Text("System Default").tag("") }
                    ForEach(options, id: \.0) { id, name in Text(name).tag(id) }
                    Divider()
                    Text("Custom…").tag(Self.customTag)
                }
                .labelsHidden()
                .frame(width: 180)
            }
        } icon: {
            Image(systemName: icon).settingsIcon()
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
        browsers = discoverApps(toOpen: SBURLs.browserDiscovery)
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
