import SwiftUI

// MARK: - Kind Filter

/// Compact segmented group of icon toggles (note / link / file).
/// Clicking the active one again clears the filter and shows everything.
struct KindFilterBar: View {
    @Binding var selection: Note.Kind?
    /// Button size and glyph size: compact in the Mac panel, touch-sized on iOS.
    var size = CGSize(width: 24, height: 22)
    var glyph: CGFloat = 11.5
    /// The iOS toolbar already draws its own capsule behind the group.
    var showsBackground = true

    private let items: [(kind: Note.Kind, symbol: String, help: String)] = [
        (.text, "note.text", L("Solo note")),
        (.link, "link", L("Solo link")),
        (.file, "doc", L("Solo file")),
    ]

    var body: some View {
        HStack(spacing: 1) {
            ForEach(items, id: \.symbol) { item in
                let isOn = selection == item.kind
                Button {
                    withAnimation(Q.anim) { selection = isOn ? nil : item.kind }
                } label: {
                    Image(systemName: item.symbol)
                        .font(.system(size: glyph, weight: .semibold))
                        .foregroundStyle(isOn ? Q.C.accent : Color.secondary)
                        .frame(width: size.width, height: size.height)
                        .background(RoundedRectangle(cornerRadius: Q.R.control - 2)
                            .fill(isOn ? Q.C.accentSoft : Color.clear))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(isOn ? L("Mostra tutto") : item.help)
                .accessibilityLabel(item.help)
                .accessibilityAddTraits(isOn ? .isSelected : [])
            }
        }
        .padding(2)
        .background(RoundedRectangle(cornerRadius: Q.R.control).fill(showsBackground ? Q.C.fill1 : Color.clear))
    }
}
