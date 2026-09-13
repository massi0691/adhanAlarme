import SwiftUI

/// Ajustements manuels en minutes, par prière (poussé depuis Réglages).
/// Reçoit le ViewModel partagé (source unique de vérité).
struct CalculationAdjustmentsView: View {
    @State private var viewModel: SettingsViewModel

    init(viewModel: SettingsViewModel) {
        _viewModel = State(wrappedValue: viewModel)
    }

    var body: some View {
        Form {
            Section {
                ForEach(Prayer.allCases) { prayer in
                    Stepper(value: adjustmentBinding(for: prayer), in: -30...30) {
                        HStack {
                            Text(LocalizedStringKey(prayer.titleKey))
                            Spacer()
                            Text(formattedMinutes(viewModel.manualAdjustments[prayer] ?? 0))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            } footer: {
                Text("settings.calculation.adjustmentsHint")
            }
        }
        .navigationTitle("settings.calculation.adjustments")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func adjustmentBinding(for prayer: Prayer) -> Binding<Int> {
        Binding(
            get: { viewModel.manualAdjustments[prayer] ?? 0 },
            set: { viewModel.setManualAdjustment($0, for: prayer) }
        )
    }

    private func formattedMinutes(_ minutes: Int) -> String {
        String(format: String(localized: "settings.calculation.minutesFormat"), minutes)
    }
}

#Preview {
    NavigationStack {
        CalculationAdjustmentsView(viewModel: AppContainer.preview.makeSettingsViewModel())
    }
}
