import Foundation

/// Image-gallery downloader: DeviantArt, Pixiv, Reddit, Instagram, and more.
public struct GalleryDl: Downloader {
    static let handledSites = [
        "deviantart.com", "pixiv.net", "danbooru.donmai.us", "artstation.com",
        "flickr.com", "reddit.com", "instagram.com", "twitter.com", "x.com",
        "tumblr.com", "gelbooru.com", "rule34.xxx", "sankakucomplex.com",
        "nijie.info", "seiga.nicovideo.jp", "pinterest.com", "patreon.com",
        "furaffinity.net", "e621.net", "newgrounds.com", "imgur.com",
    ]

    public let id = "gallery-dl"
    public let name = "gallery-dl"
    public let summary = "Image galleries: DeviantArt, Pixiv, Reddit, and more"
    public let binaryDefault = "gallery-dl"
    public let installHint = "brew install gallery-dl"

    public init() {}

    public func binaryPath(_ settings: AppSettings) -> String {
        settings.galleryDlPath.isEmpty ? binaryDefault : settings.galleryDlPath
    }

    public func canHandle(_ url: String) -> Bool {
        Self.handledSites.contains { url.contains($0) }
    }

    public func getInfo(_ url: String, settings: AppSettings) async throws -> MediaInfo {
        let slug = url
            .replacingOccurrences(of: #"^https?://"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"/$"#, with: "", options: .regularExpression)
            .split(separator: "/")
            .suffix(2)
            .joined(separator: "/")
        let site = Self.handledSites.first { url.contains($0) } ?? "gallery"

        return MediaInfo(
            title: slug.isEmpty ? "Gallery Download" : slug,
            uploader: site,
            formats: [MediaFormat(
                formatId: "original", ext: "images", resolution: "Original Quality",
                note: "All images — gallery-dl downloads every item in the gallery",
                vcodec: "none"
            )],
            downloaderId: id,
            isGallery: true,
            simpleDownload: true
        )
    }

    public func buildArgs(_ url: String, options: DownloadOptions, settings: AppSettings) -> Command {
        var args: [String] = ["-d", options.downloadFolder]

        if !settings.galleryDlCookies.isEmpty {
            args += ["--cookies", settings.galleryDlCookies]
        }
        if !settings.galleryDlConfig.isEmpty {
            args += ["--config", settings.galleryDlConfig]
        }

        args.append(url)
        return Command(binary: binaryPath(settings), args: args)
    }

    public func parseProgress(_ line: String) -> ProgressUpdate? {
        guard let m = firstMatch(#"#(\d+)"#, in: line) else { return nil }
        return ProgressUpdate(percent: nil, fileCount: Int(m[1]))
    }
}
