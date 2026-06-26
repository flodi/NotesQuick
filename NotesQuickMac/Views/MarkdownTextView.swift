import SwiftUI
import AppKit

struct MarkdownTextView: NSViewRepresentable {
    @Binding var text: String
    var hidesTags: Bool = false

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        let textView = scrollView.documentView as! NSTextView

        textView.delegate = context.coordinator
        textView.isRichText = true
        textView.allowsUndo = true
        textView.usesFindPanel = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isAutomaticTextCompletionEnabled = false
        textView.textContainerInset = NSSize(width: 16, height: 16)
        textView.backgroundColor = .textBackgroundColor
        textView.insertionPointColor = .labelColor
        textView.font = .monospacedSystemFont(ofSize: 14, weight: .regular)
        textView.textColor = .labelColor

        textView.string = text
        context.coordinator.applyHighlighting(to: textView)

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        context.coordinator.hidesTags = hidesTags
        guard let textView = scrollView.documentView as? NSTextView else { return }
        if textView.string != text {
            textView.string = text
        }
        context.coordinator.applyHighlighting(to: textView)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: MarkdownTextView
        var hidesTags = false
        private var isHighlighting = false

        private let baseFont = NSFont.monospacedSystemFont(ofSize: 14, weight: .regular)
        private let boldFont = NSFont.monospacedSystemFont(ofSize: 14, weight: .bold)
        private let markerColor = NSColor.tertiaryLabelColor

        init(_ parent: MarkdownTextView) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
            applyHighlighting(to: textView)
        }

        // MARK: - List auto-continuation

        func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                return handleListContinuation(in: textView)
            }
            return false
        }

        private func handleListContinuation(in textView: NSTextView) -> Bool {
            let nsText = textView.string as NSString
            let cursorLocation = textView.selectedRange().location
            let lineRange = nsText.lineRange(for: NSRange(location: cursorLocation, length: 0))
            var currentLine = nsText.substring(with: lineRange)
            if currentLine.hasSuffix("\n") { currentLine = String(currentLine.dropLast()) }
            let nsLine = currentLine as NSString

            // Unordered list: "  - item", "  * item", "  + item"
            if let regex = try? NSRegularExpression(pattern: "^(\\s*)([-*+])(\\s+)(.*)$"),
               let match = regex.firstMatch(in: currentLine, range: NSRange(location: 0, length: nsLine.length)) {
                let indent = nsLine.substring(with: match.range(at: 1))
                let marker = nsLine.substring(with: match.range(at: 2))
                let space = nsLine.substring(with: match.range(at: 3))
                let content = nsLine.substring(with: match.range(at: 4))

                if content.trimmingCharacters(in: .whitespaces).isEmpty {
                    // Empty list item → remove marker
                    let deleteRange = NSRange(location: lineRange.location, length: nsLine.length)
                    textView.insertText("", replacementRange: deleteRange)
                    return true
                }

                textView.insertText("\n\(indent)\(marker)\(space)", replacementRange: textView.selectedRange())
                return true
            }

            // Ordered list: "  1. item"
            if let regex = try? NSRegularExpression(pattern: "^(\\s*)(\\d+)(\\.\\s+)(.*)$"),
               let match = regex.firstMatch(in: currentLine, range: NSRange(location: 0, length: nsLine.length)) {
                let indent = nsLine.substring(with: match.range(at: 1))
                let number = Int(nsLine.substring(with: match.range(at: 2))) ?? 1
                let sep = nsLine.substring(with: match.range(at: 3))
                let content = nsLine.substring(with: match.range(at: 4))

                if content.trimmingCharacters(in: .whitespaces).isEmpty {
                    let deleteRange = NSRange(location: lineRange.location, length: nsLine.length)
                    textView.insertText("", replacementRange: deleteRange)
                    return true
                }

                textView.insertText("\n\(indent)\(number + 1)\(sep)", replacementRange: textView.selectedRange())
                return true
            }

            return false
        }

        // MARK: - Highlighting

        func applyHighlighting(to textView: NSTextView) {
            guard !isHighlighting else { return }
            isHighlighting = true
            defer { isHighlighting = false }

            let text = textView.string
            guard let storage = textView.textStorage else { return }
            let fullRange = NSRange(location: 0, length: (text as NSString).length)
            guard fullRange.length > 0 else { return }

            let selectedRanges = textView.selectedRanges

            storage.beginEditing()

            // Reset to defaults
            storage.setAttributes([
                .font: baseFont,
                .foregroundColor: NSColor.labelColor
            ], range: fullRange)

            // Apply markdown patterns (order matters)
            highlightHeaders(storage: storage, text: text)
            highlightBoldItalic(storage: storage, text: text)
            highlightBold(storage: storage, text: text)
            highlightItalic(storage: storage, text: text)
            highlightStrikethrough(storage: storage, text: text)
            highlightInlineCode(storage: storage, text: text)
            highlightBlockquotes(storage: storage, text: text)
            highlightLinks(storage: storage, text: text)
            highlightLists(storage: storage, text: text)
            highlightTags(storage: storage, text: text)

            storage.endEditing()

            textView.selectedRanges = selectedRanges
        }

        // MARK: - Headers

        private func highlightHeaders(storage: NSTextStorage, text: String) {
            guard let regex = try? NSRegularExpression(
                pattern: "^(#{1,6}\\s+)(.+)$",
                options: .anchorsMatchLines
            ) else { return }

            let nsText = text as NSString
            regex.enumerateMatches(in: text, range: NSRange(location: 0, length: nsText.length)) { match, _, _ in
                guard let match = match else { return }
                let prefixRange = match.range(at: 1)
                let level = nsText.substring(with: prefixRange).filter { $0 == "#" }.count

                let fontSize: CGFloat = switch level {
                    case 1: 28
                    case 2: 24
                    case 3: 20
                    case 4: 17
                    default: 15
                }

                let headerFont = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .bold)
                storage.addAttribute(.font, value: headerFont, range: match.range)
                storage.addAttribute(.foregroundColor, value: markerColor, range: prefixRange)
            }
        }

        // MARK: - Bold + Italic (***)

        private func highlightBoldItalic(storage: NSTextStorage, text: String) {
            applyInlineStyle(
                storage: storage, text: text,
                pattern: "(?<!\\*)(\\*{3})(.+?)(\\*{3})(?!\\*)",
                bold: true, italic: true
            )
        }

        // MARK: - Bold

        private func highlightBold(storage: NSTextStorage, text: String) {
            applyInlineStyle(
                storage: storage, text: text,
                pattern: "(?<!\\*)(\\*{2})(?!\\*)(.+?)(?<!\\*)(\\*{2})(?!\\*)",
                bold: true
            )
            applyInlineStyle(
                storage: storage, text: text,
                pattern: "(?<!_)(_{2})(?!_)(.+?)(?<!_)(_{2})(?!_)",
                bold: true
            )
        }

        // MARK: - Italic

        private func highlightItalic(storage: NSTextStorage, text: String) {
            applyInlineStyle(
                storage: storage, text: text,
                pattern: "(?<!\\*)(\\*)(?!\\*)(.+?)(?<!\\*)(\\*)(?!\\*)",
                italic: true
            )
            applyInlineStyle(
                storage: storage, text: text,
                pattern: "(?<!\\w)(_)(?!_)(.+?)(?<!_)(_)(?!\\w)",
                italic: true
            )
        }

        // MARK: - Strikethrough

        private func highlightStrikethrough(storage: NSTextStorage, text: String) {
            guard let regex = try? NSRegularExpression(pattern: "(~~)(.+?)(~~)") else { return }
            let nsText = text as NSString

            regex.enumerateMatches(in: text, range: NSRange(location: 0, length: nsText.length)) { match, _, _ in
                guard let match = match else { return }
                storage.addAttribute(.foregroundColor, value: self.markerColor, range: match.range(at: 1))
                storage.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: match.range(at: 2))
                storage.addAttribute(.foregroundColor, value: self.markerColor, range: match.range(at: 3))
            }
        }

        // MARK: - Inline Code

        private func highlightInlineCode(storage: NSTextStorage, text: String) {
            guard let regex = try? NSRegularExpression(pattern: "(`)([^`]+)(`)") else { return }
            let nsText = text as NSString
            let codeBg = NSColor.quaternaryLabelColor

            regex.enumerateMatches(in: text, range: NSRange(location: 0, length: nsText.length)) { match, _, _ in
                guard let match = match else { return }
                storage.addAttribute(.foregroundColor, value: self.markerColor, range: match.range(at: 1))
                storage.addAttribute(.backgroundColor, value: codeBg, range: match.range(at: 2))
                storage.addAttribute(.foregroundColor, value: self.markerColor, range: match.range(at: 3))
            }
        }

        // MARK: - Blockquotes

        private func highlightBlockquotes(storage: NSTextStorage, text: String) {
            guard let regex = try? NSRegularExpression(
                pattern: "^(>\\s+)(.+)$",
                options: .anchorsMatchLines
            ) else { return }

            let nsText = text as NSString
            let quoteColor = NSColor.secondaryLabelColor

            regex.enumerateMatches(in: text, range: NSRange(location: 0, length: nsText.length)) { match, _, _ in
                guard let match = match else { return }
                storage.addAttribute(.foregroundColor, value: self.markerColor, range: match.range(at: 1))
                storage.addAttribute(.foregroundColor, value: quoteColor, range: match.range(at: 2))
                let italicFont = NSFontManager.shared.convert(self.baseFont, toHaveTrait: .italicFontMask)
                storage.addAttribute(.font, value: italicFont, range: match.range(at: 2))
            }
        }

        // MARK: - Links

        private func highlightLinks(storage: NSTextStorage, text: String) {
            guard let regex = try? NSRegularExpression(
                pattern: "(\\[)([^\\]]+)(\\]\\()([^)]+)(\\))"
            ) else { return }

            let nsText = text as NSString
            let linkColor = NSColor.linkColor

            regex.enumerateMatches(in: text, range: NSRange(location: 0, length: nsText.length)) { match, _, _ in
                guard let match = match else { return }
                storage.addAttribute(.foregroundColor, value: self.markerColor, range: match.range(at: 1))
                storage.addAttribute(.foregroundColor, value: self.markerColor, range: match.range(at: 3))
                storage.addAttribute(.foregroundColor, value: self.markerColor, range: match.range(at: 5))
                storage.addAttribute(.foregroundColor, value: linkColor, range: match.range(at: 2))
                storage.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: match.range(at: 2))
                storage.addAttribute(.foregroundColor, value: self.markerColor, range: match.range(at: 4))
            }
        }

        // MARK: - Lists

        private func highlightLists(storage: NSTextStorage, text: String) {
            guard let regex = try? NSRegularExpression(
                pattern: "^(\\s*)([-*+]|\\d+\\.)\\s",
                options: .anchorsMatchLines
            ) else { return }

            let nsText = text as NSString
            let bulletColor = NSColor.systemOrange

            regex.enumerateMatches(in: text, range: NSRange(location: 0, length: nsText.length)) { match, _, _ in
                guard let match = match else { return }
                storage.addAttribute(.foregroundColor, value: bulletColor, range: match.range(at: 2))
            }
        }

        // MARK: - Tags

        private func highlightTags(storage: NSTextStorage, text: String) {
            guard let regex = try? NSRegularExpression(pattern: "(?<!\\w)(#\\w+)") else { return }
            let nsText = text as NSString
            let tagColor = NSColor.systemPurple

            regex.enumerateMatches(in: text, range: NSRange(location: 0, length: nsText.length)) { match, _, _ in
                guard let match = match else { return }
                let range = match.range(at: 1)
                if self.hidesTags {
                    storage.addAttribute(.foregroundColor, value: NSColor.textBackgroundColor, range: range)
                    storage.addAttribute(.font, value: NSFont.monospacedSystemFont(ofSize: 1, weight: .regular), range: range)
                } else {
                    storage.addAttribute(.foregroundColor, value: tagColor, range: range)
                }
            }
        }

        // MARK: - Inline Style Helper

        private func applyInlineStyle(
            storage: NSTextStorage,
            text: String,
            pattern: String,
            bold: Bool = false,
            italic: Bool = false
        ) {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { return }
            let nsText = text as NSString

            regex.enumerateMatches(in: text, range: NSRange(location: 0, length: nsText.length)) { match, _, _ in
                guard let match = match, match.numberOfRanges >= 4 else { return }

                let openRange = match.range(at: 1)
                let contentRange = match.range(at: 2)
                let closeRange = match.range(at: 3)

                // Dim the markers
                storage.addAttribute(.foregroundColor, value: self.markerColor, range: openRange)
                storage.addAttribute(.foregroundColor, value: self.markerColor, range: closeRange)

                // Preserve existing font size (e.g. inside headers)
                let existingFont = storage.attribute(.font, at: contentRange.location, effectiveRange: nil) as? NSFont ?? self.baseFont
                let size = existingFont.pointSize
                let existingIsBold = existingFont.fontDescriptor.symbolicTraits.contains(.bold)

                // Build the styled font using explicit weight for visible bold
                let weight: NSFont.Weight = (bold || existingIsBold) ? .bold : .regular
                var styledFont = NSFont.monospacedSystemFont(ofSize: size, weight: weight)

                let existingIsItalic = existingFont.fontDescriptor.symbolicTraits.contains(.italic)
                if italic || existingIsItalic {
                    styledFont = NSFontManager.shared.convert(styledFont, toHaveTrait: .italicFontMask)
                }

                storage.addAttribute(.font, value: styledFont, range: contentRange)
            }
        }
    }
}
