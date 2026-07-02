import Foundation

/// Tiny NSRegularExpression wrapper: returns capture groups (index 0 = full match)
/// or nil when the pattern doesn't match.
func firstMatch(_ pattern: String, in text: String, caseInsensitive: Bool = false) -> [String]? {
    let options: NSRegularExpression.Options = caseInsensitive ? [.caseInsensitive] : []
    guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else { return nil }
    let range = NSRange(text.startIndex..., in: text)
    guard let match = regex.firstMatch(in: text, range: range) else { return nil }
    return (0..<match.numberOfRanges).map { i in
        guard let r = Range(match.range(at: i), in: text) else { return "" }
        return String(text[r])
    }
}

func matches(_ pattern: String, _ text: String, caseInsensitive: Bool = true) -> Bool {
    firstMatch(pattern, in: text, caseInsensitive: caseInsensitive) != nil
}
