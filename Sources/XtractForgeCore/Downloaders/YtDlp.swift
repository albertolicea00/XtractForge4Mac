import Foundation

/// Catch-all engine: YouTube, Vimeo, TikTok, Twitter/X, and 1000+ sites.
public struct YtDlp: Downloader {
    public let id = "yt-dlp"
    public let name = "yt-dlp"
    public let summary = "YouTube, Vimeo, TikTok, and 1000+ sites"
    public let binaryDefault = "yt-dlp"
    public let installHint = "brew install yt-dlp ffmpeg"
    public let supportsResume = true

    public init() {}

    public func binaryPath(_ settings: AppSettings) -> String {
        settings.ytdlpPath.isEmpty ? binaryDefault : settings.ytdlpPath
    }

    public func canHandle(_ url: String) -> Bool { true }

    public func getInfo(_ url: String, settings: AppSettings) async throws -> MediaInfo {
        let bin = binaryPath(settings)
        let res = try await ProcessRunner.capture(bin, ["--dump-single-json", "--flat-playlist", url])
        guard res.success, let data = res.stdout.data(using: .utf8) else {
            throw DownloadError.toolFailed(tool: "yt-dlp", message: lastLine(res.stderr))
        }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw DownloadError.badOutput(tool: "yt-dlp")
        }

        let entries = json["entries"] as? [[String: Any]]
        let isPlaylist = (json["_type"] as? String) == "playlist" || entries != nil

        var thumbnail = json["thumbnail"] as? String ?? ""
        if thumbnail.isEmpty,
           let thumbs = json["thumbnails"] as? [[String: Any]],
           let last = thumbs.last?["url"] as? String {
            thumbnail = last
        }

        let formats: [MediaFormat] = ((json["formats"] as? [[String: Any]]) ?? []).map { f in
            MediaFormat(
                formatId: f["format_id"] as? String ?? "",
                ext: f["ext"] as? String ?? "",
                resolution: f["resolution"] as? String ?? "",
                filesize: (f["filesize"] as? NSNumber)?.int64Value
                    ?? (f["filesize_approx"] as? NSNumber)?.int64Value,
                fps: (f["fps"] as? NSNumber)?.doubleValue,
                note: f["format_note"] as? String ?? "",
                vcodec: f["vcodec"] as? String ?? ""
            )
        }

        return MediaInfo(
            title: json["title"] as? String ?? "Untitled",
            thumbnail: thumbnail,
            duration: (json["duration"] as? NSNumber)?.doubleValue ?? 0,
            uploader: json["uploader"] as? String ?? (json["channel"] as? String ?? ""),
            formats: formats,
            downloaderId: id,
            isPlaylist: isPlaylist,
            entryCount: entries?.count ?? 0
        )
    }

    public func buildArgs(_ url: String, options: DownloadOptions, settings: AppSettings) -> Command {
        var args: [String] = []

        let template = options.isPlaylist
            ? "%(playlist_title)s/%(playlist_index)s - %(title)s.%(ext)s"
            : "%(title)s.%(ext)s"
        args += ["-o", options.downloadFolder + "/" + template]

        if !settings.speedLimit.isEmpty {
            args += ["-r", settings.speedLimit]
        }

        if let format = options.formatId, !format.isEmpty {
            args += ["-f", format]
        } else if options.audioOnly {
            args += ["-x", "--audio-format", options.audioFormat]
        } else {
            args += ["-f", "bestvideo+bestaudio/best"]
        }

        if settings.embedSubtitles {
            args += ["--embed-subs", "--all-subs"]
        }
        if settings.sponsorBlock {
            args += ["--sponsorblock-remove", "all"]
        }
        if options.resume {
            args.append("-c")
        }

        args.append(url)
        return Command(binary: binaryPath(settings), args: args)
    }

    public func parseProgress(_ line: String) -> ProgressUpdate? {
        guard let m = firstMatch(
            #"\[download\]\s+([\d.]+)% of\s+(?:~\s*)?([\d.]+\w+) at\s+([\d.]+\w+/s) ETA\s+([\d:]+)"#,
            in: line
        ) else { return nil }
        return ProgressUpdate(percent: Double(m[1]), size: m[2], speed: m[3], eta: m[4])
    }
}

func lastLine(_ text: String) -> String {
    text.trimmingCharacters(in: .whitespacesAndNewlines)
        .components(separatedBy: "\n").last ?? ""
}
