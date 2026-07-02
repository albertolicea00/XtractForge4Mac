import Foundation

public enum Organize: String, Codable, CaseIterable, Sendable {
    case none
    case type
    case source
}

public enum AppearanceSetting: String, Codable, CaseIterable, Sendable {
    case system
    case light
    case dark
}

/// Value snapshot of every user setting. Persisted as JSON (see `SettingsStore`
/// in the app target) and passed into downloaders by value.
public struct AppSettings: Codable, Equatable, Sendable {
    // General
    public var downloadFolder: String
    public var speedLimit: String
    public var stageToTemp: Bool
    public var organize: Organize
    public var watchClipboard: Bool
    public var appearance: AppearanceSetting
    public var disabledDownloaders: [String]

    // yt-dlp
    public var ytdlpPath: String
    public var embedSubtitles: Bool
    public var sponsorBlock: Bool

    // ffmpeg
    public var ffmpegPath: String
    public var ffmpegContainer: String

    // lux
    public var luxPath: String
    public var luxCookie: String
    public var luxMultiThread: Bool

    // gallery-dl
    public var galleryDlPath: String
    public var galleryDlCookies: String
    public var galleryDlConfig: String

    // spotdl
    public var spotdlPath: String
    public var spotdlFormat: String
    public var spotdlBitrate: String

    // curl
    public var curlPath: String

    public init(
        downloadFolder: String = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first?.path ?? NSHomeDirectory() + "/Downloads",
        speedLimit: String = "",
        stageToTemp: Bool = true,
        organize: Organize = .none,
        watchClipboard: Bool = false,
        appearance: AppearanceSetting = .system,
        disabledDownloaders: [String] = [],
        ytdlpPath: String = "yt-dlp",
        embedSubtitles: Bool = false,
        sponsorBlock: Bool = false,
        ffmpegPath: String = "ffmpeg",
        ffmpegContainer: String = "mp4",
        luxPath: String = "lux",
        luxCookie: String = "",
        luxMultiThread: Bool = false,
        galleryDlPath: String = "gallery-dl",
        galleryDlCookies: String = "",
        galleryDlConfig: String = "",
        spotdlPath: String = "spotdl",
        spotdlFormat: String = "mp3",
        spotdlBitrate: String = "320k",
        curlPath: String = "curl"
    ) {
        self.downloadFolder = downloadFolder
        self.speedLimit = speedLimit
        self.stageToTemp = stageToTemp
        self.organize = organize
        self.watchClipboard = watchClipboard
        self.appearance = appearance
        self.disabledDownloaders = disabledDownloaders
        self.ytdlpPath = ytdlpPath
        self.embedSubtitles = embedSubtitles
        self.sponsorBlock = sponsorBlock
        self.ffmpegPath = ffmpegPath
        self.ffmpegContainer = ffmpegContainer
        self.luxPath = luxPath
        self.luxCookie = luxCookie
        self.luxMultiThread = luxMultiThread
        self.galleryDlPath = galleryDlPath
        self.galleryDlCookies = galleryDlCookies
        self.galleryDlConfig = galleryDlConfig
        self.spotdlPath = spotdlPath
        self.spotdlFormat = spotdlFormat
        self.spotdlBitrate = spotdlBitrate
        self.curlPath = curlPath
    }
}
