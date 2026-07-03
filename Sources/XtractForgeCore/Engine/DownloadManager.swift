import Foundation
import Observation

public enum DownloadState: Equatable, Sendable {
    case fetchingInfo
    case awaitingOptions
    case downloading
    case paused
    case completed
    case failed(String)
    case cancelled

    public var isActive: Bool {
        self == .downloading || self == .paused || self == .fetchingInfo
    }
}

@Observable
public final class DownloadItem: Identifiable {
    public let id = UUID()
    public let url: String
    public let downloaderId: String

    public var title: String
    public var state: DownloadState = .fetchingInfo
    public var info: MediaInfo?
    public var progress = ProgressUpdate()
    /// Final location after a completed download.
    public var destination: String?
    /// Last few output lines, for error reporting.
    public var recentLines: [String] = []

    init(url: String, downloaderId: String) {
        self.url = url
        self.downloaderId = downloaderId
        self.title = url
    }

    public var downloader: (any Downloader)? {
        DownloaderRegistry.downloader(id: downloaderId)
    }
}

/// Single source of truth for the download queue.
@MainActor
@Observable
public final class DownloadManager {
    public private(set) var items: [DownloadItem] = []
    /// Snapshot provider so the manager always sees current settings.
    public var settingsProvider: () -> AppSettings
    /// Hook for the app layer: completion notification, dock badge, etc.
    public var onStateChange: ((DownloadItem) -> Void)?

    @ObservationIgnored
    private var running: [UUID: RunningProcess] = [:]
    @ObservationIgnored
    private var lastUIUpdate: [UUID: TimeInterval] = [:]

    public init(settingsProvider: @escaping () -> AppSettings = { AppSettings() }) {
        self.settingsProvider = settingsProvider
    }

    public var activeCount: Int {
        items.filter { $0.state == .downloading || $0.state == .fetchingInfo }.count
    }

    // MARK: - Intake

    /// Entry point for every URL. Routes, fetches info, then either starts
    /// directly (simple downloads) or waits for the options sheet.
    public func submit(_ url: String) {
        let settings = settingsProvider()
        guard let downloader = DownloaderRegistry.route(url, disabled: settings.disabledDownloaders) else {
            let item = DownloadItem(url: url, downloaderId: "yt-dlp")
            item.state = .failed("No enabled downloader can handle this URL")
            items.insert(item, at: 0)
            return
        }

        let item = DownloadItem(url: url, downloaderId: downloader.id)
        items.insert(item, at: 0)

        Task {
            do {
                let info = try await downloader.getInfo(url, settings: settings)
                item.info = info
                item.title = info.title
                if info.simpleDownload || (info.formats.isEmpty && info.optionFields.isEmpty) {
                    start(item, options: [:], formatId: nil, audioOnly: false)
                } else {
                    item.state = .awaitingOptions
                }
            } catch {
                item.state = .failed(error.localizedDescription)
                onStateChange?(item)
            }
        }
    }

    // MARK: - Lifecycle

    /// Start (or restart after pause-on-failure) a download with chosen options.
    public func start(_ item: DownloadItem, options pluginOptions: [String: String],
                      formatId: String?, audioOnly: Bool, audioFormat: String = "mp3",
                      resume: Bool = false) {
        guard let downloader = item.downloader else { return }
        let settings = settingsProvider()

        let workFolder: URL
        if settings.stageToTemp {
            workFolder = Staging.stagingDir(for: item.url, downloadFolder: settings.downloadFolder)
        } else {
            workFolder = URL(fileURLWithPath: settings.downloadFolder)
        }

        do {
            try FileManager.default.createDirectory(at: workFolder, withIntermediateDirectories: true)
        } catch {
            item.state = .failed("Cannot create download folder: \(error.localizedDescription)")
            return
        }

        let options = DownloadOptions(
            downloadFolder: workFolder.path,
            formatId: formatId,
            audioOnly: audioOnly,
            audioFormat: audioFormat,
            isPlaylist: item.info?.isPlaylist ?? false,
            resume: resume,
            pluginOptions: pluginOptions
        )
        let command = downloader.buildArgs(item.url, options: options, settings: settings)

        do {
            let proc = try ProcessRunner.run(command, currentDirectory: workFolder)
            running[item.id] = proc
            item.state = .downloading
            onStateChange?(item)

            Task {
                for await line in proc.lines {
                    self.handleLine(line, for: item, downloader: downloader)
                }
                let code = await proc.waitUntilExit()
                self.handleExit(code: code, item: item, stagingDir: settings.stageToTemp ? workFolder : nil)
            }
        } catch {
            item.state = .failed(error.localizedDescription)
            onStateChange?(item)
        }
    }

    public func pause(_ item: DownloadItem) {
        guard let proc = running[item.id], item.state == .downloading else { return }
        if proc.suspend() {
            item.state = .paused
            onStateChange?(item)
        }
    }

    public func resume(_ item: DownloadItem) {
        guard let proc = running[item.id], item.state == .paused else { return }
        if proc.resume() {
            item.state = .downloading
            onStateChange?(item)
        }
    }

    public func cancel(_ item: DownloadItem) {
        if let proc = running[item.id] {
            // Resume first so a paused process can actually receive SIGTERM handling.
            if item.state == .paused { proc.resume() }
            item.state = .cancelled
            proc.terminate()
        } else {
            item.state = .cancelled
        }
        onStateChange?(item)
    }

    /// Retry a failed download; staging dir was left in place, so resumable
    /// tools continue where they stopped.
    public func retry(_ item: DownloadItem) {
        guard case .failed = item.state else { return }
        guard item.info != nil else {
            removeAndResubmit(item)
            return
        }
        let canResume = item.downloader?.supportsResume ?? false
        item.progress = ProgressUpdate()
        item.recentLines = []
        start(item, options: [:], formatId: nil, audioOnly: false, resume: canResume)
    }

    public func remove(_ item: DownloadItem) {
        if item.state == .downloading || item.state == .paused { cancel(item) }
        items.removeAll { $0.id == item.id }
        running[item.id] = nil
    }

    public func clearFinished() {
        items.removeAll {
            switch $0.state {
            case .completed, .cancelled, .failed: return true
            default: return false
            }
        }
    }

    private func removeAndResubmit(_ item: DownloadItem) {
        let url = item.url
        items.removeAll { $0.id == item.id }
        submit(url)
    }

    // MARK: - Process events

    private func handleLine(_ line: String, for item: DownloadItem, downloader: any Downloader) {
        item.recentLines.append(line)
        if item.recentLines.count > 20 { item.recentLines.removeFirst() }

        guard let update = downloader.parseProgress(line) else { return }
        // Throttle UI-visible progress writes to ~10/s per item.
        let now = ProcessInfo.processInfo.systemUptime
        if let last = lastUIUpdate[item.id], now - last < 0.1, update.percent != 100 {
            return
        }
        lastUIUpdate[item.id] = now

        var merged = update
        if merged.percent == nil { merged.percent = item.progress.percent }
        if let count = item.progress.fileCount, merged.fileCount == nil { merged.fileCount = count }
        item.progress = merged
    }

    private func handleExit(code: Int32, item: DownloadItem, stagingDir: URL?) {
        running[item.id] = nil
        if item.state == .cancelled {
            // Leave the staging dir for a future retry, per spec.
            onStateChange?(item)
            return
        }

        let settings = settingsProvider()
        if code == 0 {
            var destination = settings.downloadFolder
            if let stagingDir {
                let source = URL(string: item.url)?.host ?? item.downloaderId
                do {
                    let moved = try Staging.finalize(
                        stagingDir: stagingDir,
                        finalFolder: settings.downloadFolder,
                        organize: settings.organize,
                        source: source
                    )
                    if let first = moved.first {
                        destination = moved.count == 1 ? first.path : first.deletingLastPathComponent().path
                    }
                } catch {
                    item.state = .failed("Downloaded, but moving files failed: \(error.localizedDescription)")
                    onStateChange?(item)
                    return
                }
            }
            item.progress.percent = 100
            item.destination = destination
            item.state = .completed
        } else {
            let detail = item.recentLines.last { !$0.trimmingCharacters(in: .whitespaces).isEmpty } ?? ""
            item.state = .failed(detail.isEmpty ? "Exited with code \(code)" : detail)
        }
        onStateChange?(item)
    }
}
