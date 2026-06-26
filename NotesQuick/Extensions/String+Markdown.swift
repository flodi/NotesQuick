import Foundation

extension String {
    /// Strips markdown syntax from a string, returning plain text.
    func strippingMarkdown() -> String {
        var result = self
        // Header markers
        result = result.replacingOccurrences(of: "^#{1,6}\\s+", with: "", options: .regularExpression)
        // Images ![alt](url) → alt
        result = result.replacingOccurrences(of: "!\\[([^\\]]*?)\\]\\([^)]*?\\)", with: "$1", options: .regularExpression)
        // Links [text](url) → text
        result = result.replacingOccurrences(of: "\\[([^\\]]*?)\\]\\([^)]*?\\)", with: "$1", options: .regularExpression)
        // Bold+Italic ***
        result = result.replacingOccurrences(of: "\\*{3}(.+?)\\*{3}", with: "$1", options: .regularExpression)
        // Bold **
        result = result.replacingOccurrences(of: "\\*{2}(.+?)\\*{2}", with: "$1", options: .regularExpression)
        // Bold __
        result = result.replacingOccurrences(of: "__(.+?)__", with: "$1", options: .regularExpression)
        // Italic *
        result = result.replacingOccurrences(of: "\\*(.+?)\\*", with: "$1", options: .regularExpression)
        // Italic _
        result = result.replacingOccurrences(of: "(?<!\\w)_(.+?)_(?!\\w)", with: "$1", options: .regularExpression)
        // Strikethrough ~~
        result = result.replacingOccurrences(of: "~~(.+?)~~", with: "$1", options: .regularExpression)
        // Inline code `
        result = result.replacingOccurrences(of: "`([^`]+)`", with: "$1", options: .regularExpression)
        return result.trimmingCharacters(in: .whitespaces)
    }

    /// Extracts unique #tags from the string, sorted alphabetically.
    func extractTags() -> [String] {
        guard let regex = try? NSRegularExpression(pattern: "(?<!\\w)#(\\w+)") else { return [] }
        let nsString = self as NSString
        let results = regex.matches(in: self, range: NSRange(location: 0, length: nsString.length))
        let tags = results.map { nsString.substring(with: $0.range(at: 1)).lowercased() }
        return Array(Set(tags)).sorted()
    }
}
