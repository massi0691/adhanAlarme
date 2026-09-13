import SwiftUI

/// Interrupteur global de l'Adhan, accessible depuis l'écran principal.
/// Le changement d'état est immédiat (voir `HomeViewModel.toggleAdhan`).
struct AdhanToggleButton: View {
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: isEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                if isEnabled {
                    Text("adhan.enabled")
                } else {
                    Text("adhan.disabled")
                }
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .tint(isEnabled ? .accentColor : .secondary)
        .controlSize(.large)
        .accessibilityHint(Text("adhan.toggle.hint"))
    }
}

#Preview {
    VStack(spacing: 16) {
        AdhanToggleButton(isEnabled: true) {}
        AdhanToggleButton(isEnabled: false) {}
    }
    .padding()
}
