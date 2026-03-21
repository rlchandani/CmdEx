import AppKit
import ComposableArchitecture
import Foundation
import CmdExCore

private extension DateFormatter {
    static let screenshotFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()
}

@MainActor
final class ScreenshotWatcher {
    var onToast: (@MainActor (String) -> Void)?

    static let instance = ScreenshotWatcher()

    private var stream: FSEventStreamRef?
    private var isRunning = false
    private var lastKnownFiles: Set<String> = []

    var enabled: Bool {
        get {
            // Read directly from the settings file to avoid @Shared timing issues at launch
            let url = URL.applicationSupportDirectory
                .appending(component: "com.cmdex.app")
                .appending(component: "settings.json")
            guard let data = try? Data(contentsOf: url),
                  let settings = try? JSONDecoder().decode(AppSettings.self, from: data) else {
                return false
            }
            return settings.screenshotWatcherEnabled
        }
        set {
            @Shared(.appSettings) var settings
            $settings.withLock { $0.screenshotWatcherEnabled = newValue }
            if newValue { start() } else { stop() }
        }
    }

    var watchPath: String {
        if let domain = UserDefaults(suiteName: "com.apple.screencapture"),
           let location = domain.string(forKey: "location") {
            return (location as NSString).expandingTildeInPath
        }
        return (NSHomeDirectory() as NSString).appendingPathComponent("Desktop")
    }

    func startIfEnabled() {
        if enabled { start() }
    }

    func start() {
        guard !isRunning else { return }
        let path = watchPath

        lastKnownFiles = Set(
            (try? FileManager.default.contentsOfDirectory(atPath: path))?.filter { $0.hasPrefix("Screenshot") || $0.hasPrefix("Screen Shot") } ?? []
        )

        let cfPath = path as CFString
        var context = FSEventStreamContext()

        let callback: FSEventStreamCallback = { _, _, _, _, _, _ in
            Task { @MainActor in
                ScreenshotWatcher.instance.handleFSEvent()
            }
        }

        stream = FSEventStreamCreate(
            nil, callback, &context,
            [cfPath] as CFArray,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            0.1,
            FSEventStreamCreateFlags(kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagUseCFTypes)
        )

        if let stream {
            FSEventStreamScheduleWithRunLoop(stream, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
            FSEventStreamStart(stream)
            isRunning = true
            SBLog.app.info("Screenshot watcher started on \(path)")
        }
    }

    func stop() {
        guard isRunning, let stream else { return }
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
        self.stream = nil
        isRunning = false
        SBLog.app.info("Screenshot watcher stopped")
    }

    private func handleFSEvent() {
        let dir = watchPath
        guard let files = try? FileManager.default.contentsOfDirectory(atPath: dir) else { return }

        let screenshots = files.filter {
            ($0.hasPrefix("Screenshot") || $0.hasPrefix("Screen Shot")) &&
            ($0.hasSuffix(".png") || $0.hasSuffix(".jpg") || $0.hasSuffix(".jpeg"))
        }

        let newFiles = Set(screenshots).subtracting(lastKnownFiles)
        lastKnownFiles = Set(screenshots)

        if let newest = newFiles.sorted().last {
            let originalPath = (dir as NSString).appendingPathComponent(newest)
            let ext = (newest as NSString).pathExtension
            let tmpPath = "/tmp/Screenshot-\(UUID().uuidString).\(ext)"

            try? FileManager.default.copyItem(atPath: originalPath, toPath: tmpPath)

            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(tmpPath, forType: .string)
            ToastWindow.instance.showToast("Path copied: \((tmpPath as NSString).lastPathComponent)")
            SBLog.app.info("Screenshot path copied: \(tmpPath)")
        }
    }
}
