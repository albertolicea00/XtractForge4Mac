import Foundation

/// Fast downloader for Bilibili, Douyin, Kuaishou, and other Asian sites.
/// Note: unlike the old plugin, youtube.com/youtu.be are NOT claimed here —
/// YouTube belongs to yt-dlp (the core engine).
public struct Lux: Downloader {
    static let handledSites = [
        "bilibili.com", "douyin.com", "kuaishou.com", "weibo.com",
        "mgtv.com", "iqiyi.com", "youku.com", "v.qq.com", "acfun.cn",
        "huya.com", "douyu.com",
    ]

    public let id = "lux"
    public let name = "Lux"
    public let summary = "Bilibili, Douyin, Kuaishou, and more"
    public let binaryDefault = "lux"
    public let installHint = "brew install lux"

    public init() {}

    public func binaryPath(_ settings: AppSettings) -> String {
        settings.luxPath.isEmpty ? binaryDefault : settings.luxPath
    }

    public func canHandle(_ url: String) -> Bool {
        Self.handledSites.contains { url.contains($0) }
    }

    public func getInfo(_ url: String, settings: AppSettings) async throws -> MediaInfo {
        let bin = binaryPath(settings)
        let res = try await ProcessRunner.capture(bin, ["-j", url])
        guard res.success, let data = res.stdout.data(using: .utf8) else {
            throw DownloadError.toolFailed(tool: "lux", message: lastLine(res.stderr))
        }
        let parsed = try? JSONSerialization.jsonObject(with: data)
        let raw: [String: Any]
        if let arr = parsed as? [[String: Any]], let first = arr.first {
            raw = first
        } else if let obj = parsed as? [String: Any] {
            raw = obj
        } else {
            throw DownloadError.badOutput(tool: "lux")
        }

        let streams = raw["streams"] as? [String: [String: Any]] ?? [:]
        let formats: [MediaFormat] = streams.map { (streamId, s) in
            MediaFormat(
                formatId: streamId,
                ext: s["ext"] as? String ?? "mp4",
                resolution: s["quality"] as? String ?? "unknown",
                filesize: (s["size"] as? NSNumber)?.int64Value,
                note: s["quality"] as? String ?? streamId
            )
        }.sorted { ($0.filesize ?? 0) > ($1.filesize ?? 0) }

        return MediaInfo(
            title: raw["title"] as? String ?? "Untitled",
            thumbnail: raw["thumbnail"] as? String ?? "",
            uploader: raw["author"] as? String ?? "",
            formats: formats,
            downloaderId: id
        )
    }

    public func buildArgs(_ url: String, options: DownloadOptions, settings: AppSettings) -> Command {
        var args: [String] = ["-o", options.downloadFolder]

        if let format = options.formatId, !format.isEmpty, format != "best" {
            args += ["-f", format]
        }
        if !settings.luxCookie.isEmpty {
            args += ["-c", settings.luxCookie]
        }
        if settings.luxMultiThread {
            args.append("-m")
        }

        args.append(url)
        return Command(binary: binaryPath(settings), args: args)
    }

    public func parseProgress(_ line: String) -> ProgressUpdate? {
        guard let pct = firstMatch(#"([\d.]+)%"#, in: line) else { return nil }
        let speed = firstMatch(#"([\d.]+\s*\w+/s)"#, in: line, caseInsensitive: true)
        return ProgressUpdate(percent: Double(pct[1]), speed: speed?[1] ?? "")
    }
}
