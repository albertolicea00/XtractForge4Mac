import Foundation
import CryptoKit

/// Download staging: tools write into a hidden temp dir; on success files move
/// to the final folder (applying `organize`); on failure the temp dir stays so
/// the tool can resume later.
public enum Staging {
    public static let tempDirName = ".xtractforge-tmp"

    static let videoExts: Set<String> = ["mp4", "mkv", "webm", "mov", "avi", "flv", "ts", "m4v"]
    static let audioExts: Set<String> = ["mp3", "m4a", "aac", "flac", "wav", "ogg", "opus"]
    static let imageExts: Set<String> = ["jpg", "jpeg", "png", "gif", "webp", "bmp", "tiff", "heic"]

    public static func urlHash(_ url: String) -> String {
        let digest = SHA256.hash(data: Data(url.utf8))
        return digest.prefix(8).map { String(format: "%02x", $0) }.joined()
    }

    /// `<downloadFolder>/.xtractforge-tmp/<urlHash>/`
    public static func stagingDir(for url: String, downloadFolder: String) -> URL {
        URL(fileURLWithPath: downloadFolder)
            .appendingPathComponent(tempDirName)
            .appendingPathComponent(urlHash(url))
    }

    public static func category(forExtension ext: String) -> String {
        let e = ext.lowercased()
        if videoExts.contains(e) { return "Video" }
        if audioExts.contains(e) { return "Audio" }
        if imageExts.contains(e) { return "Images" }
        return "Files"
    }

    /// Destination folder for a file, applying the organize mode.
    /// `source` label = downloader id or site host.
    public static func destinationFolder(finalFolder: String, organize: Organize,
                                         fileExtension: String, source: String) -> URL {
        let base = URL(fileURLWithPath: finalFolder)
        switch organize {
        case .none:
            return base
        case .type:
            return base.appendingPathComponent(category(forExtension: fileExtension))
        case .source:
            return base.appendingPathComponent(source)
        }
    }

    /// Move everything out of `stagingDir` into `finalFolder` (applying
    /// organize), delete the staging dir, and return the moved top-level URLs.
    @discardableResult
    public static func finalize(stagingDir: URL, finalFolder: String,
                                organize: Organize, source: String) throws -> [URL] {
        let fm = FileManager.default
        var moved: [URL] = []

        let items = (try? fm.contentsOfDirectory(at: stagingDir,
                                                 includingPropertiesForKeys: nil,
                                                 options: [.skipsHiddenFiles])) ?? []
        for item in items {
            let ext = item.pathExtension
            let destFolder = destinationFolder(finalFolder: finalFolder, organize: organize,
                                               fileExtension: ext, source: source)
            try fm.createDirectory(at: destFolder, withIntermediateDirectories: true)
            var dest = destFolder.appendingPathComponent(item.lastPathComponent)
            // Never overwrite: append " (n)" like Finder does.
            var counter = 1
            let base = item.deletingPathExtension().lastPathComponent
            while fm.fileExists(atPath: dest.path) {
                counter += 1
                let name = ext.isEmpty ? "\(base) (\(counter))" : "\(base) (\(counter)).\(ext)"
                dest = destFolder.appendingPathComponent(name)
            }
            try fm.moveItem(at: item, to: dest)
            moved.append(dest)
        }

        try? fm.removeItem(at: stagingDir)
        // Remove the parent .xtractforge-tmp dir when it's now empty.
        let parent = stagingDir.deletingLastPathComponent()
        if parent.lastPathComponent == tempDirName,
           let rest = try? fm.contentsOfDirectory(atPath: parent.path), rest.isEmpty {
            try? fm.removeItem(at: parent)
        }
        return moved
    }
}
