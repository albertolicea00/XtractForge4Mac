import Foundation

/// Spotify tracks/albums/playlists as audio (via YouTube Music match).
public struct SpotDl: Downloader {
    public let id = "spotdl"
    public let name = "spotDL"
    public let summary = "Spotify tracks, albums, and playlists as audio"
    public let binaryDefault = "spotdl"
    public let installHint = "pip install spotdl"

    public init() {}

    public func binaryPath(_ settings: AppSettings) -> String {
        settings.spotdlPath.isEmpty ? binaryDefault : settings.spotdlPath
    }

    public func canHandle(_ url: String) -> Bool {
        url.contains("open.spotify.com") || url.hasPrefix("spotify:")
    }

    public func getInfo(_ url: String, settings: AppSettings) async throws -> MediaInfo {
        var contentType = "Track"
        if url.contains("/playlist/") { contentType = "Playlist" }
        if url.contains("/album/") { contentType = "Album" }
        if url.contains("/artist/") { contentType = "Artist discography" }

        let fmt = settings.spotdlFormat.isEmpty ? "mp3" : settings.spotdlFormat
        let bitrate = settings.spotdlBitrate.isEmpty ? "320k" : settings.spotdlBitrate

        return MediaInfo(
            title: "Spotify \(contentType)",
            uploader: "Spotify",
            formats: [MediaFormat(
                formatId: fmt, ext: fmt, resolution: bitrate,
                note: "\(fmt.uppercased()) @ \(bitrate) — downloaded via YouTube Music match",
                vcodec: "none"
            )],
            downloaderId: id,
            simpleDownload: true
        )
    }

    public func buildArgs(_ url: String, options: DownloadOptions, settings: AppSettings) -> Command {
        let fmt = settings.spotdlFormat.isEmpty ? "mp3" : settings.spotdlFormat
        let bitrate = settings.spotdlBitrate.isEmpty ? "320k" : settings.spotdlBitrate

        let args = [
            "download", url,
            "--output", options.downloadFolder + "/{artist} - {title}.{output-ext}",
            "--format", fmt,
            "--bitrate", bitrate,
        ]
        return Command(binary: binaryPath(settings), args: args)
    }

    public func parseProgress(_ line: String) -> ProgressUpdate? {
        if line.contains("Downloaded") || line.contains("Skipping") {
            return ProgressUpdate(percent: 100)
        }
        if line.contains("Downloading") {
            return ProgressUpdate(percent: 50)
        }
        return nil
    }
}
