import SwiftUI
import UIKit

struct MarkdownTextView: UIViewRepresentable {
    @Binding var text: String
    var hidesTags: Bool = false

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        textView.font = .monospacedSystemFont(ofSize: 16, weight: .regular)
        textView.textColor = .label
        textView.backgroundColor = .systemBackground
        textView.autocapitalizationType = .sentences
        textView.autocorrectionType = .default
        textView.smartQuotesType = .no
        textView.smartDashesType = .no
        textView.textContainerInset = UIEdgeInsets(top: 16, left: 12, bottom: 16, right: 12)
        textView.keyboardDismissMode = .interactive
        textView.alwaysBounceVertical = true
        textView.text = text
        context.coordinator.applyHighlighting(to: textView)
        return textView
    }

    func updateUIView(_ textView: UITextView, context: Context) {
        context.coordinator.hidesTags = hidesTags
        if textView.text != text {
            textView.text = text
        }
        context.coordinator.applyHighlighting(to: textView)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, UITextViewDelegate {
        var parent: MarkdownTextView
        var hidesTags = false
        private var isHighlighting = false

        private let baseFont = UIFont.monospacedSystemFont(ofSize: 16, weight: .regular)
        private let markerColor = UIColor.tertiaryLabel

        init(_ parent: MarkdownTextView) {
            self.parent = parent
        }

        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text
            applyHighlighting(to: textView)
        }

        // MARK: - List auto-continuation

        func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
            guard text == "\n" else { return true }
            return !handleListContinuation(in: textView, at: range)
        }

        private func handleListContinuation(in textView: UITextView, at range: NSRange) -> Bool {
            let nsText = (textView.text ?? "") as NSString
            let lineRange = nsText.lineRange(for: NSRange(location: range.location, length: 0))
            var currentLine = nsText.substring(with: lineRange)
            if currentLine.hasSuffix("\n") { currentLine = String(currentLine.dropLast()) }
            let nsLine = currentLine as NSString

            // Unordered list
            if let regex = try? NSRegularExpression(pattern: "^(\\s*)([-*+])(\\s+)(.*)$"),
               let match = regex.firstMatch(in: currentLine, range: NSRange(location: 0, length: nsLine.length)) {
                let indent = nsLine.substring(with: match.range(at: 1))
                let marker = nsLine.substring(with: match.range(at: 2))
                let space = nsLine.substring(with: match.range(at: 3))
                let content = nsLine.substring(with: match.range(at: 4))

                if content.trimmingCharacters(in: .whitespaces).isEmpty {
                    textView.textStorage.replaceCharacters(
                        in: NSRange(location: lineRange.location, length: nsLine.length),
                        with: ""
                    )
                    textView.selectedRange = NSRange(location: lineRange.location, length: 0)
                } else {
                    let insertion = "\n\(indent)\(marker)\(space)"
                    textView.textStorage.replaceCharacters(in: range, with: insertion)
                    textView.selectedRange = NSRange(location: range.location + (insertion as NSString).length, length: 0)
                }
                parent.text = textView.text
                applyHighlighting(to: textView)
                return true
            }

            // Ordered list
            if let regex = try? NSRegularExpression(pattern: "^(\\s*)(\\d+)(\\.\\s+)(.*)$"),
               let match = regex.firstMatch(in: currentLine, range: NSRange(location: 0, length: nsLine.length)) {
                let indent = nsLine.substring(with: match.range(at: 1))
                let number = Int(nsLine.substring(with: match.range(at: 2))) ?? 1
                let sep = nsLine.substring(with: match.range(at: 3))
                let content = nsLine.substring(with: match.range(at: 4))

                if content.trimmingCharacters(in: .whitespaces).isEmpty {
                    textView.textStorage.replaceCharacters(
                        in: NSRange(location: lineRange.location, length: nsLine.length),
                        with: ""
                    )
                    textView.selectedRange = NSRange(location: lineRange.location, length: 0)
                } else {
                    let insertion = "\n\(indent)\(number + 1)\(sep)"
                    textView.textStorage.replaceCharacters(in: range, with: insertion)
                    textView.selectedRange = NSRange(location: range.location + (insertion as NSString).length, length: 0)
                }
                parent.text = textView.text
                applyHighlighting(to: textView)
                return true
            }

            return false
        }

        // MARK: - Highlighting

        func applyHighlighting(to textView: UITextView) {
            guard !isHighlighting else { return }
            isHighlighting = true
            defer { isHighlighting = false }

            let text = textView.text ?? ""
            let storage = textView.textStorage
            let fullRange = NSRange(location: 0, length: (text as NSString).length)
            guard fullRange.length > 0 else { return }

            let selectedRange = textView.selectedRange

            storage.beginEditing()

            storage.setAttributes([
                .font: baseFont,
                .foregroundColor: UIColor.label
            ], range: fullRange)

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

            textView.selectedRange = selectedRange
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
                    case 1: 30
                    case 2: 26
                    case 3: 22
                    case 4: 19
                    default: 17
                }

                let headerFont = UIFont.monospacedSystemFont(ofSize: fontSize, weight: .bold)
                storage.addAttribute(.font, value: headerFont, range: match.range)
                storage.addAttribute(.foregroundColor, value: markerColor, range: prefixRange)
            }
        }

        // MARK: - Bold + Italic

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
            let codeBg = UIColor.quaternaryLabel

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
            let quoteColor = UIColor.secondaryLabel

            regex.enumerateMatches(in: text, range: NSRange(location: 0, length: nsText.length)) { match, _, _ in
                guard let match = match else { return }
                storage.addAttribute(.foregroundColor, value: self.markerColor, range: match.range(at: 1))
                storage.addAttribute(.foregroundColor, value: quoteColor, range: match.range(at: 2))
                let italicFont = self.fontWithTraits(size: self.baseFont.pointSize, bold: false, italic: true)
                storage.addAttribute(.font, value: italicFont, range: match.range(at: 2))
            }
        }

        // MARK: - Links

        private func highlightLinks(storage: NSTextStorage, text: String) {
            guard let regex = try? NSRegularExpression(
                pattern: "(\\[)([^\\]]+)(\\]\\()([^)]+)(\\))"
            ) else { return }

            let nsText = text as NSString
            let linkColor = UIColor.link

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
            let bulletColor = UIColor.systemOrange

            regex.enumerateMatches(in: text, range: NSRange(location: 0, length: nsText.length)) { match, _, _ in
                guard let match = match else { return }
                storage.addAttribute(.foregroundColor, value: bulletColor, range: match.range(at: 2))
            }
        }

        // MARK: - Tags

        private func highlightTags(storage: NSTextStorage, text: String) {
            guard let regex = try? NSRegularExpression(pattern: "(?<!\\w)(#\\w+)") else { return }
            let nsText = text as NSString
            let tagColor = UIColor.systemPurple

            regex.enumerateMatches(in: text, range: NSRange(location: 0, length: nsText.length)) { match, _, _ in
                guard let match = match else { return }
                let range = match.range(at: 1)
                if self.hidesTags {
                    storage.addAttribute(.foregroundColor, value: UIColor.systemBackground, range: range)
                    storage.addAttribute(.font, value: UIFont.monospacedSystemFont(ofSize: 1, weight: .regular), range: range)
                } else {
                    storage.addAttribute(.foregroundColor, value: tagColor, range: range)
                }
            }
        }

        // MARK: - Helpers

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

                storage.addAttribute(.foregroundColor, value: self.markerColor, range: openRange)
                storage.addAttribute(.foregroundColor, value: self.markerColor, range: closeRange)

                // Preserve existing font size (e.g. inside headers)
                let existingFont = storage.attribute(.font, at: contentRange.location, effectiveRange: nil) as? UIFont ?? self.baseFont
                let size = existingFont.pointSize
                let existingTraits = existingFont.fontDescriptor.symbolicTraits

                let needsBold = bold || existingTraits.contains(.traitBold)
                let needsItalic = italic || existingTraits.contains(.traitItalic)

                let styledFont = self.fontWithTraits(size: size, bold: needsBold, italic: needsItalic)
                storage.addAttribute(.font, value: styledFont, range: contentRange)
            }
        }

        private func fontWithTraits(size: CGFloat, bold: Bool, italic: Bool) -> UIFont {
            let weight: UIFont.Weight = bold ? .bold : .regular
            let font = UIFont.monospacedSystemFont(ofSize: size, weight: weight)

            if italic {
                var traits: UIFontDescriptor.SymbolicTraits = []
                if bold { traits.insert(.traitBold) }
                traits.insert(.traitItalic)
                if let descriptor = font.fontDescriptor.withSymbolicTraits(traits) {
                    return UIFont(descriptor: descriptor, size: size)
                }
            }

            return font
        }
    }
}
