import Foundation

/// Translation of a string that travels as `String` (tooltips, alert texts, computed titles).
/// Literals inside `Text("…")`, `Button("…")`, `Label("…")` are already translated by SwiftUI:
/// `L` is only needed where the text is a `String`. Translations live in
/// `NotesQuick/Resources/Localizable.xcstrings` (source language Italian, key = Italian text).
/// Every new string must be added to the catalog by hand, or it stays Italian in English.
func L(_ key: String, _ args: CVarArg...) -> String {
    let format = NSLocalizedString(key, comment: "")
    return args.isEmpty ? format : String(format: format, arguments: args)
}

/// True when the app runs in English: picks the locale for dates in list rows.
let appIsEnglish = Bundle.main.preferredLocalizations.first?.hasPrefix("en") ?? false
