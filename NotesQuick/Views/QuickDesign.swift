// Quick Design System — SwiftUI
// Aggiungi questo file a ogni app. In Assets.xcassets imposta AccentColor = #D9772E (Any) / #F08A3E (Dark).
import SwiftUI

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(.sRGB, red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255, opacity: alpha)
    }
    static func dynamic(_ light: Color, _ dark: Color) -> Color {
        #if canImport(UIKit)
        return Color(UIColor { $0.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light) })
        #else
        return Color(NSColor(name: nil) { $0.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? NSColor(dark) : NSColor(light) })
        #endif
    }
}

enum Q {
    // MARK: Colori
    enum C {
        static let accent      = Color.dynamic(Color(hex: 0xD9772E), Color(hex: 0xF08A3E))
        static let accentSoft  = accent.opacity(0.12)
        static let ok          = Color.dynamic(Color(hex: 0x2F9E5B), Color(hex: 0x4CC47A))
        static let warn        = Color.dynamic(Color(hex: 0xB98900), Color(hex: 0xE8B53A))
        static let danger      = Color.dynamic(Color(hex: 0xD83B32), Color(hex: 0xFF6A5F))
        static let info        = Color.dynamic(Color(hex: 0x3478D1), Color(hex: 0x5A9BF0))
        static let none        = Color.dynamic(Color(hex: 0xC7C7CC), Color(hex: 0x48484A))
        static let fill1       = Color(hex: 0x787880, alpha: 0.08)   // bottone grigio
        static let fill2       = Color(hex: 0x787880, alpha: 0.14)   // hover / segmented
        static let sunken      = Color(hex: 0x787880, alpha: 0.08)   // status box
        static let band        = Color(hex: 0x787880, alpha: 0.06)   // fascia card
        static let card        = Color.dynamic(.white, Color(hex: 0x1E1E21))
        // Testo e separatori: usa i semantici di sistema (.primary, .secondary, Color(.separator))
    }
    /// Anzianità dello stato (giorni dall'ultimo aggiornamento)
    static func age(_ days: Int?) -> Color {
        guard let d = days else { return C.none }
        return d <= 6 ? C.ok : d <= 20 ? C.warn : C.danger
    }

    // MARK: Tipografia (SF di sistema; mono per tutti i numeri)
    enum F {
        static let sectionLabel = Font.system(size: 9.5, weight: .bold)      // + .tracking(0.7) + .textCase(.uppercase)
        static let meta         = Font.system(size: 10.5)
        static let body         = Font.system(size: 12.5)                    // desktop
        static let title        = Font.system(size: 15, weight: .semibold)
        static let viewTitle    = Font.system(size: 22, weight: .semibold)
        static func data(_ size: CGFloat = 12.5, _ w: Font.Weight = .medium) -> Font { .system(size: size, weight: w, design: .monospaced).monospacedDigit() }
    }

    // MARK: Spazi, raggi, misure
    enum S { static let xs: CGFloat = 3, s: CGFloat = 6, m: CGFloat = 8, l: CGFloat = 12, xl: CGFloat = 16, xxl: CGFloat = 24, indent: CGFloat = 24 }
    enum R { static let tag: CGFloat = 3, row: CGFloat = 5, control: CGFloat = 7, box: CGFloat = 8, touch: CGFloat = 10, card: CGFloat = 12, ring: CGFloat = 14, sheet: CGFloat = 16 }
    enum Size {
        static let toolbar = CGSize(width: 30, height: 26)
        static let action  = CGSize(width: 32, height: 28)
        static let handle  = CGSize(width: 22, height: 22)
        static let touch   = CGSize(width: 44, height: 40)
        static let statusBar: CGFloat = 4
        static let card: CGFloat = 280
    }
    static let anim = Animation.easeOut(duration: 0.18)
}

// MARK: Componenti base

/// Azione solo-icona. Ordine in un gruppo: .primary → .tinted/.gray → .plain
struct QIconButton: View {
    enum Kind { case primary, tinted, gray, plain }
    let symbol: String; var kind: Kind = .gray; var help: String; var action: () -> Void
    #if os(macOS)
    private let size = Q.Size.action
    #else
    private let size = Q.Size.touch
    #endif
    var body: some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: 13, weight: .semibold))
                .frame(width: size.width, height: size.height)
                .foregroundStyle(kind == .primary ? Color.white : kind == .tinted ? Q.C.accent : .secondary)
                .background(RoundedRectangle(cornerRadius: Q.R.control).fill(kind == .primary ? Q.C.accent : kind == .tinted ? Q.C.accentSoft : kind == .gray ? Q.C.fill2 : .clear))
        }.buttonStyle(.plain).help(help).accessibilityLabel(help)
    }
}

/// Intestazione di sezione: MAIUSCOLO 9.5 bold +0.07em, conteggio, azione a destra
struct QSectionHeader<Trailing: View>: View {
    let title: String; var count: Int? = nil; @ViewBuilder var trailing: () -> Trailing
    var body: some View {
        HStack(spacing: 6) {
            Text(count.map { "\(title) · \($0)" } ?? title).font(Q.F.sectionLabel).tracking(0.7).textCase(.uppercase).foregroundStyle(.secondary)
            Spacer(minLength: 0); trailing()
        }
    }
}

/// Box di stato: meta (anzianità · data · autore) + testo max 3 righe
struct QStatusBox: View {
    let ageDays: Int?; let ageLabel: String; let date: String; var author: String? = nil; let text: String?
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            (Text(text == nil ? "NESSUNO STATO" : ageLabel.uppercased()).bold().foregroundColor(Q.age(text == nil ? nil : ageDays))
             + Text(" · \(date)" + (author.map { " · \($0)" } ?? "")).foregroundColor(.secondary)).font(Q.F.meta).lineLimit(1)
            Text(text ?? "Nessuno stato registrato").font(.system(size: 12)).foregroundStyle(text == nil ? .tertiary : .primary).lineLimit(3)
        }.padding(.horizontal, 8).padding(.vertical, 7).frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: Q.R.box).fill(Q.C.sunken))
    }
}

/// Card oggetto: raggio 12, ombra + hairline, barra stato 4px, anello selezione
struct QCard<Content: View>: View {
    var status: Color? = nil; var selected = false; @ViewBuilder var content: () -> Content
    var body: some View {
        HStack(spacing: 0) {
            if let s = status { Rectangle().fill(s).frame(width: Q.Size.statusBar) }
            content().frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Q.C.card)
        .clipShape(RoundedRectangle(cornerRadius: Q.R.card))
        .shadow(color: .black.opacity(0.10), radius: 7, y: 4)
        .overlay(RoundedRectangle(cornerRadius: Q.R.card).stroke(Color.black.opacity(0.10), lineWidth: 0.5))
        .overlay(RoundedRectangle(cornerRadius: Q.R.ring).inset(by: -2).stroke(selected ? Q.C.accent : .clear, lineWidth: 2))
    }
}
