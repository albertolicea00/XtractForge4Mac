import Foundation

/// A compiled-in download tool. Fixed set — no dynamic loading, ever.
public protocol Downloader: Sendable {
    var id: String { get }
    var name: String { get }
    var summary: String { get }
    var binaryDefault: String { get }
    var installHint: String { get }
    /// True when the underlying tool can continue a partial download
    /// (drives whether the UI offers pause on this item).
    var supportsResume: Bool { get }

    func binaryPath(_ settings: AppSettings) -> String
    func checkDependency(settings: AppSettings) async -> DependencyStatus
    func canHandle(_ url: String) -> Bool
    func getInfo(_ url: String, settings: AppSettings) async throws -> MediaInfo
    func buildArgs(_ url: String, options: DownloadOptions, settings: AppSettings) -> Command
    func parseProgress(_ line: String) -> ProgressUpdate?
}

public extension Downloader {
    var supportsResume: Bool { false }

    func checkDependency(settings: AppSettings) async -> DependencyStatus {
        await Self.versionCheck(binary: binaryPath(settings), flag: "--version")
    }

    static func versionCheck(binary: String, flag: String) async -> DependencyStatus {
        do {
            let res = try await ProcessRunner.capture(binary, [flag])
            let firstLine = res.stdout
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .components(separatedBy: "\n").first ?? ""
            return DependencyStatus(available: res.success, version: firstLine)
        } catch {
            return DependencyStatus(available: false, version: "")
        }
    }
}

/// Fixed registry. Routing order: most specific first, yt-dlp catch-all last.
public enum DownloaderRegistry {
    public static let all: [any Downloader] = [
        SpotDl(), GalleryDl(), Lux(), FFmpegTool(), Curl(), YtDlp(),
    ]

    public static func downloader(id: String) -> (any Downloader)? {
        all.first { $0.id == id }
    }

    /// First enabled downloader whose `canHandle` matches; yt-dlp is the
    /// catch-all (unless disabled, in which case nil).
    public static func route(_ url: String, disabled: [String] = []) -> (any Downloader)? {
        for downloader in all where !disabled.contains(downloader.id) {
            if downloader.canHandle(url) { return downloader }
        }
        return nil
    }
}

// Shared helpers for downloaders.
enum URLHelpers {
    /// Last path component of a URL, decoded; `fallback` when empty/unparseable.
    static func filename(from url: String, fallback: String) -> String {
        guard let u = URL(string: url) else { return fallback }
        let base = u.pathComponents.filter { $0 != "/" }.last ?? ""
        let decoded = base.removingPercentEncoding ?? base
        return decoded.isEmpty ? fallback : decoded
    }

    static func isLocalPath(_ url: String) -> Bool {
        url.hasPrefix("/") || url.hasPrefix("file://")
    }

    static func localPath(_ url: String) -> String {
        url.hasPrefix("file://") ? (URL(string: url)?.path ?? url) : url
    }
}
