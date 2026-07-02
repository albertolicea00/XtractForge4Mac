import Foundation

// MARK: - Command

/// A resolved child-process invocation: binary + arguments.
public struct Command: Equatable, Sendable {
    public var binary: String
    public var args: [String]

    public init(binary: String, args: [String]) {
        self.binary = binary
        self.args = args
    }
}

// MARK: - Dependency

public struct DependencyStatus: Equatable, Sendable {
    public var available: Bool
    public var version: String

    public init(available: Bool, version: String) {
        self.available = available
        self.version = version
    }
}

// MARK: - Media info

public struct MediaFormat: Equatable, Sendable, Identifiable, Hashable {
    public var formatId: String
    public var ext: String
    public var resolution: String
    public var filesize: Int64?
    public var fps: Double?
    public var note: String
    public var vcodec: String

    public var id: String { formatId }

    public init(formatId: String, ext: String, resolution: String,
                filesize: Int64? = nil, fps: Double? = nil,
                note: String = "", vcodec: String = "") {
        self.formatId = formatId
        self.ext = ext
        self.resolution = resolution
        self.filesize = filesize
        self.fps = fps
        self.note = note
        self.vcodec = vcodec
    }
}

/// Declarative per-download option rendered by the options sheet
/// (the old `_downloadOptions` idea, strongly typed).
public struct OptionField: Equatable, Sendable, Identifiable {
    public enum Kind: Equatable, Sendable {
        case text
        case toggle
        case select
    }

    public var key: String
    public var label: String
    public var kind: Kind
    /// Toggles use "true"/"false".
    public var defaultValue: String
    public var options: [String]
    public var placeholder: String
    public var help: String

    public var id: String { key }

    public init(key: String, label: String, kind: Kind, defaultValue: String,
                options: [String] = [], placeholder: String = "", help: String = "") {
        self.key = key
        self.label = label
        self.kind = kind
        self.defaultValue = defaultValue
        self.options = options
        self.placeholder = placeholder
        self.help = help
    }
}

public struct MediaInfo: Equatable, Sendable {
    public var title: String
    public var thumbnail: String
    public var duration: Double
    public var uploader: String
    public var formats: [MediaFormat]
    public var downloaderId: String
    public var isPlaylist: Bool
    public var entryCount: Int
    public var isGallery: Bool
    /// Extra fields the options sheet renders; values land in `DownloadOptions.pluginOptions`.
    public var optionFields: [OptionField]
    /// True → skip the options sheet entirely and download directly.
    public var simpleDownload: Bool

    public init(title: String, thumbnail: String = "", duration: Double = 0,
                uploader: String = "", formats: [MediaFormat] = [],
                downloaderId: String, isPlaylist: Bool = false, entryCount: Int = 0,
                isGallery: Bool = false, optionFields: [OptionField] = [],
                simpleDownload: Bool = false) {
        self.title = title
        self.thumbnail = thumbnail
        self.duration = duration
        self.uploader = uploader
        self.formats = formats
        self.downloaderId = downloaderId
        self.isPlaylist = isPlaylist
        self.entryCount = entryCount
        self.isGallery = isGallery
        self.optionFields = optionFields
        self.simpleDownload = simpleDownload
    }
}

// MARK: - Download options

public struct DownloadOptions: Equatable, Sendable {
    /// Folder the tool writes into (the staging dir when staging is on).
    public var downloadFolder: String
    public var formatId: String?
    public var audioOnly: Bool
    public var audioFormat: String
    public var isPlaylist: Bool
    /// Set when resuming a paused download (adds the tool's continue flag).
    public var resume: Bool
    /// Values collected from `MediaInfo.optionFields` ("true"/"false" for toggles).
    public var pluginOptions: [String: String]

    public init(downloadFolder: String, formatId: String? = nil, audioOnly: Bool = false,
                audioFormat: String = "mp3", isPlaylist: Bool = false,
                resume: Bool = false, pluginOptions: [String: String] = [:]) {
        self.downloadFolder = downloadFolder
        self.formatId = formatId
        self.audioOnly = audioOnly
        self.audioFormat = audioFormat
        self.isPlaylist = isPlaylist
        self.resume = resume
        self.pluginOptions = pluginOptions
    }
}

// MARK: - Progress

public struct ProgressUpdate: Equatable, Sendable {
    public var percent: Double?
    public var size: String
    public var speed: String
    public var eta: String
    public var fileCount: Int?

    public init(percent: Double? = nil, size: String = "", speed: String = "",
                eta: String = "", fileCount: Int? = nil) {
        self.percent = percent
        self.size = size
        self.speed = speed
        self.eta = eta
        self.fileCount = fileCount
    }
}

// MARK: - Errors

public enum DownloadError: LocalizedError {
    case binaryNotFound(String)
    case toolFailed(tool: String, message: String)
    case badOutput(tool: String)

    public var errorDescription: String? {
        switch self {
        case .binaryNotFound(let bin):
            return "Binary not found: \(bin)"
        case .toolFailed(let tool, let message):
            return "\(tool) failed: \(message)"
        case .badOutput(let tool):
            return "Could not parse \(tool) output"
        }
    }
}
