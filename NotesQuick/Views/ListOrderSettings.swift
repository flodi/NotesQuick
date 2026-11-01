import SwiftUI

/// Settings section for the list order: pinned items, other items, grouping by kind.
struct ListOrderSettings: View {
    @EnvironmentObject var viewModel: NotesViewModel

    var body: some View {
        Section("Ordine dell'elenco") {
            Picker("Elementi in cima", selection: $viewModel.pinnedSort) {
                ForEach(ListSort.allCases) { Text($0.label).tag($0) }
            }
            Picker("Altri elementi", selection: $viewModel.otherSort) {
                ForEach(ListSort.allCases) { Text($0.label).tag($0) }
            }
            Toggle("Raggruppa per tipo", isOn: $viewModel.groupByKind.animation())
            if viewModel.groupByKind {
                ForEach(Array(viewModel.kindOrder.enumerated()), id: \.element) { index, kind in
                    HStack(spacing: 8) {
                        Text("\(index + 1)").font(Q.F.data(12)).foregroundStyle(.secondary).frame(width: 14)
                        Image(systemName: kind.symbol).foregroundStyle(.secondary).frame(width: 18)
                        Text(kind.groupTitle)
                        Spacer()
                        orderButton("chevron.up", L("Sposta su"), enabled: index > 0) { viewModel.moveKind(kind, by: -1) }
                        orderButton("chevron.down", L("Sposta giù"), enabled: index < viewModel.kindOrder.count - 1) {
                            viewModel.moveKind(kind, by: 1)
                        }
                    }
                }
            }
            Text("Gli elementi fissati stanno sempre in cima. Con il raggruppamento, gli altri sono divisi per tipo in quest'ordine.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func orderButton(_ symbol: String, _ help: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button { withAnimation(Q.anim) { action() } } label: {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .semibold))
                .frame(width: 28, height: 24)
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .disabled(!enabled)
        .help(help)
        .accessibilityLabel(help)
    }
}
