// Componenti Quick specifici di NotesQuick, costruiti sui token di QuickDesign.swift.
import SwiftUI

/// Logotipo dell'app: `notes▪` (testo di sistema bold + quadrato accento sulla linea di base).
struct QWordmark: View {
    var name = "notes"
    var size: CGFloat = 17
    var body: some View {
        HStack(alignment: .lastTextBaseline, spacing: 2) {
            Text(name).font(.system(size: size, weight: .bold)).tracking(-0.03 * size)
            Rectangle().fill(Q.C.accent).frame(width: size / 4, height: size / 4)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("NotesQuick")
    }
}

/// Stato vuoto: dice cosa comparirà lì.
struct QEmptyState: View {
    var symbol = "tray"
    let title: String
    var message: String? = nil
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: symbol).font(.system(size: 32, weight: .light)).foregroundStyle(.tertiary)
            Text(title).font(.system(size: 13.5, weight: .semibold))
            if let message {
                Text(message).font(.system(size: 12)).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center).frame(maxWidth: 280)
            }
        }
        .padding(.horizontal, 20).padding(.vertical, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

extension Date {
    private static let quickRelative: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.locale = Locale(identifier: appIsEnglish ? "en_US" : "it_IT")
        f.unitsStyle = .full
        return f
    }()

    private static let quickShort: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: appIsEnglish ? "en_US" : "it_IT")
        f.dateFormat = appIsEnglish ? "MMM d" : "d MMM"
        return f
    }()

    /// Data breve delle righe: `29 ago`.
    var quickShort: String { Date.quickShort.string(from: self) }

    /// Meta di riga: tempo relativo in maiuscolo + data breve, `3 GIORNI FA · 29 ago`.
    var quickMeta: String {
        let now = Date()
        let relative = now.timeIntervalSince(self) < 60
            ? L("ORA")
            : Date.quickRelative.localizedString(for: self, relativeTo: now).uppercased()
        return "\(relative) · \(quickShort)"
    }
}
