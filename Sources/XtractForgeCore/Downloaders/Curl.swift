import Foundation

/// Direct file URLs straight to disk (no extraction).
public struct Curl: Downloader {
    static let fileExtPattern = #"\.(mp4|mkv|webm|mov|avi|flv|mp3|m4a|aac|flac|wav|ogg|opus|zip|rar|7z|pdf|jpg|jpeg|png|gif|webp|apk|dmg|exe|iso|gz|tar)(\?|#|$)"#

    public let id = "curl"
    public let name = "curl"
    public let summary = "Direct file URLs straight to disk"
    public let binaryDefault = "curl"
    public let installHint = "Pre-installed on macOS"
    public let supportsResume = true

    public init() {}

    public func binaryPath(_ settings: AppSettings) -> String {
        settings.curlPath.isEmpty ? binaryDefault : settings.curlPath
    }

    public func checkDependency(settings: AppSettings) async -> DependencyStatus {
        do {
            let res = try await ProcessRunner.capture(binaryPath(settings), ["--version"])
            let version = firstMatch(#"curl\s+([\d.]+)"#, in: res.stdout, caseInsensitive: true)?[1]
                ?? res.stdout.components(separatedBy: "\n").first ?? ""
            return DependencyStatus(available: res.success, version: version)
        } catch {
            return DependencyStatus(available: false, version: "")
        }
    }

    public func canHandle(_ url: String) -> Bool {
        if matches(FFmpegTool.streamPattern, url) { return false }
        return matches(Self.fileExtPattern, url)
    }

    public func getInfo(_ url: String, settings: AppSettings) async throws -> MediaInfo {
        let name = URLHelpers.filename(from: url, fallback: "download")
        return MediaInfo(
            title: name,
            downloaderId: id,
            optionFields: [
                OptionField(key: "filename", label: "Save as", kind: .text,
                            defaultValue: name, placeholder: name,
                            help: "curl saves the file as-is; it does not convert formats."),
            ]
        )
    }

    public func buildArgs(_ url: String, options: DownloadOptions, settings: AppSettings) -> Command {
        let name = options.pluginOptions["filename"].flatMap { $0.isEmpty ? nil : $0 }
            ?? URLHelpers.filename(from: url, fallback: "download")
        let out = options.downloadFolder + "/" + name

        var args = ["-L", "--create-dirs"]
        if options.resume {
            args += ["-C", "-"]
        }
        args += ["-o", out, url]
        if !settings.speedLimit.isEmpty {
            args += ["--limit-rate", settings.speedLimit]
        }
        return Command(binary: binaryPath(settings), args: args)
    }

    public func parseProgress(_ line: String) -> ProgressUpdate? {
        guard let m = firstMatch(#"^\s*(\d{1,3})\b"#, in: line),
              let pct = Int(m[1]), pct <= 100 else { return nil }
        return ProgressUpdate(percent: Double(pct))
    }
}
