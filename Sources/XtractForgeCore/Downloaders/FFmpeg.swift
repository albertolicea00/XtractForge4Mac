import Foundation

/// Records HLS/DASH/RTMP/RTSP streams to a file, and converts local media files.
public struct FFmpegTool: Downloader {
    static let streamPattern = #"\.(m3u8|mpd)(\?|#|$)|^rtmps?://|^rtsp://"#
    static let mediaExts = ["mp4", "mkv", "webm", "mov", "avi", "flv", "ts", "m4v",
                            "mp3", "m4a", "aac", "flac", "wav", "ogg", "opus"]

    public let id = "ffmpeg"
    public let name = "FFmpeg"
    public let summary = "HLS/DASH/RTMP streams and local file conversion"
    public let binaryDefault = "ffmpeg"
    public let installHint = "brew install ffmpeg"

    public init() {}

    public func binaryPath(_ settings: AppSettings) -> String {
        settings.ffmpegPath.isEmpty ? binaryDefault : settings.ffmpegPath
    }

    public func checkDependency(settings: AppSettings) async -> DependencyStatus {
        do {
            let res = try await ProcessRunner.capture(binaryPath(settings), ["-version"])
            let version = firstMatch(#"ffmpeg version (\S+)"#, in: res.stdout, caseInsensitive: true)?[1]
                ?? res.stdout.components(separatedBy: "\n").first ?? ""
            return DependencyStatus(available: res.success, version: version)
        } catch {
            return DependencyStatus(available: false, version: "")
        }
    }

    public func canHandle(_ url: String) -> Bool {
        if matches(Self.streamPattern, url) { return true }
        if URLHelpers.isLocalPath(url) {
            let ext = (URLHelpers.localPath(url) as NSString).pathExtension.lowercased()
            return Self.mediaExts.contains(ext)
        }
        return false
    }

    public func getInfo(_ url: String, settings: AppSettings) async throws -> MediaInfo {
        if URLHelpers.isLocalPath(url) {
            let path = URLHelpers.localPath(url)
            let filename = (path as NSString).lastPathComponent
            let baseName = (filename as NSString).deletingPathExtension
            let ext = (filename as NSString).pathExtension.lowercased()
            let audioExts = ["mp3", "m4a", "wav"]

            return MediaInfo(
                title: baseName.isEmpty ? filename : baseName,
                uploader: "Local File",
                downloaderId: id,
                optionFields: [
                    OptionField(key: "action", label: "Action", kind: .select,
                                defaultValue: "convert", options: ["convert", "extract_audio"],
                                help: "Convert the video to another format, or extract its audio."),
                    OptionField(key: "container", label: "Output format", kind: .select,
                                defaultValue: audioExts.contains(ext) ? ext : "mp4",
                                options: ["mp4", "mkv", "mp3", "m4a", "wav"],
                                help: "The file container/format to convert to."),
                    OptionField(key: "videoCodec", label: "Video codec", kind: .select,
                                defaultValue: "copy", options: ["copy", "h264", "h265"],
                                help: "\"copy\" is extremely fast as it does not re-encode."),
                    OptionField(key: "audioCodec", label: "Audio codec", kind: .select,
                                defaultValue: "copy", options: ["copy", "aac", "mp3"],
                                help: "Codec for the audio track."),
                ]
            )
        }

        return MediaInfo(
            title: Self.nameFromStreamUrl(url),
            downloaderId: id,
            optionFields: [
                OptionField(key: "container", label: "Output container", kind: .select,
                            defaultValue: settings.ffmpegContainer.isEmpty ? "mp4" : settings.ffmpegContainer,
                            options: ["mp4", "mkv", "ts"],
                            help: "File format for the recorded stream. mp4 is the most compatible."),
            ]
        )
    }

    public func buildArgs(_ url: String, options: DownloadOptions, settings: AppSettings) -> Command {
        let bin = binaryPath(settings)

        if URLHelpers.isLocalPath(url) {
            let input = URLHelpers.localPath(url)
            let action = options.pluginOptions["action"] ?? "convert"
            let container = options.pluginOptions["container"] ?? "mp4"
            let videoCodec = options.pluginOptions["videoCodec"] ?? "copy"
            let audioCodec = options.pluginOptions["audioCodec"] ?? "copy"

            let baseName = ((input as NSString).lastPathComponent as NSString).deletingPathExtension
            let out = options.downloadFolder + "/\(baseName)_converted.\(container)"

            var args = ["-y", "-stats", "-i", input]
            if action == "extract_audio" {
                args.append("-vn")
                args += Self.audioCodecArgs(audioCodec)
            } else {
                switch videoCodec {
                case "h264": args += ["-vcodec", "libx264"]
                case "h265": args += ["-vcodec", "libx265"]
                default: args += ["-vcodec", "copy"]
                }
                args += Self.audioCodecArgs(audioCodec)
            }
            args.append(out)
            return Command(binary: bin, args: args)
        }

        let container = options.pluginOptions["container"]
            ?? (settings.ffmpegContainer.isEmpty ? "mp4" : settings.ffmpegContainer)
        let out = options.downloadFolder + "/\(Self.nameFromStreamUrl(url)).\(container)"
        var args = ["-y", "-stats", "-i", url, "-c", "copy"]
        if container == "mp4" {
            args += ["-bsf:a", "aac_adtstoasc"]
        }
        args.append(out)
        return Command(binary: bin, args: args)
    }

    public func parseProgress(_ line: String) -> ProgressUpdate? {
        let time = firstMatch(#"time=(\d{2}:\d{2}:\d{2})"#, in: line)
        let speed = firstMatch(#"speed=\s*([\d.]+x)"#, in: line)
        if time == nil && speed == nil { return nil }
        return ProgressUpdate(percent: nil, size: time?[1] ?? "", speed: speed?[1] ?? "")
    }

    static func audioCodecArgs(_ codec: String) -> [String] {
        switch codec {
        case "aac": return ["-acodec", "aac"]
        case "mp3": return ["-acodec", "libmp3lame"]
        default: return ["-acodec", "copy"]
        }
    }

    static func nameFromStreamUrl(_ url: String) -> String {
        guard let u = URL(string: url) else { return "stream" }
        let base = (u.pathComponents.filter { $0 != "/" }.last ?? "stream")
            .replacingOccurrences(of: #"\.(m3u8|mpd)$"#, with: "", options: [.regularExpression, .caseInsensitive])
        return base.isEmpty ? "stream" : base
    }
}
