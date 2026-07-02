import Foundation

/// URL extraction for everything that enters the app (drop, paste, and — later —
/// the xtractforge:// scheme). Pure logic; the app-side IntakeService feeds
/// results into the DownloadManager.
public enum Intake {
    /// Extract downloadable targets from arbitrary text: http(s) links,
    /// spotify: URIs, rtmp/rtsp streams, and absolute local media paths.
    public static func extractURLs(from text: String) -> [String] {
        var found: [String] = []
        var seen = Set<String>()

        func add(_ s: String) {
            let trimmed = s.trimmingCharacters(in: CharacterSet(charactersIn: ".,;)]}>\"'"))
            guard !trimmed.isEmpty, !seen.contains(trimmed) else { return }
            seen.insert(trimmed)
            found.append(trimmed)
        }

        for rawToken in text.split(whereSeparator: { $0.isNewline || $0 == " " || $0 == "\t" }) {
            let token = String(rawToken)
            if token.hasPrefix("http://") || token.hasPrefix("https://") {
                add(token)
            } else if token.hasPrefix("spotify:") && token.count > "spotify:".count {
                add(token)
            } else if token.hasPrefix("rtmp://") || token.hasPrefix("rtmps://") || token.hasPrefix("rtsp://") {
                add(token)
            } else if token.hasPrefix("file://") {
                add(token)
            } else if token.hasPrefix("/") && FileManager.default.fileExists(atPath: token) {
                add(token)
            } else if token.contains("://") == false && looksLikeBareDomainURL(token) {
                add("https://" + token)
            }
        }
        return found
    }

    /// "youtube.com/watch?v=x" style input without a scheme.
    static func looksLikeBareDomainURL(_ token: String) -> Bool {
        guard let m = firstMatch(#"^([a-z0-9-]+\.)+[a-z]{2,}(/\S*)?$"#, in: token, caseInsensitive: true),
              !m.isEmpty else { return false }
        // Require a path or a known media-ish domain to avoid swallowing plain words like "e.g".
        return token.contains("/") || token.contains("www.")
    }
}
