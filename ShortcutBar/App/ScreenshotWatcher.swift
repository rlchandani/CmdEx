import AppKit
import ComposableArchitecture
import Foundation
import ShortcutBarCore

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
    static let shared = ScreenshotWatcher()

    private var stream: FSEventStreamRef?
    private var isRunning = false
    private var lastKnownFiles: Set<String> = []

    var enabled: Bool {
        get {
            @Shared(.appSettings) var settings
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
                ScreenshotWatcher.shared.handleFSEvent()
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
            let timestamp = DateFormatter.screenshotFormatter.string(from: Date())
            let renamed = "Screenshot-\(timestamp).\(ext)"
            let renamedPath = (dir as NSString).appendingPathComponent(renamed)

            if renamed != newest {
                try? FileManager.default.moveItem(atPath: originalPath, toPath: renamedPath)
                lastKnownFiles.remove(newest)
                lastKnownFiles.insert(renamed)
            }

            let finalPath = FileManager.default.fileExists(atPath: renamedPath) ? renamedPath : originalPath
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(finalPath, forType: .string)
            ToastWindow.show("Path copied: \((finalPath as NSString).lastPathComponent)")
            SBLog.app.info("Screenshot path copied: \(finalPath)")
        }
    }
}
