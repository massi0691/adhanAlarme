import SwiftUI

/// Compte à rebours seconde par seconde.
/// Léger : une seule `TimelineView`, un simple formatage de chaîne.
struct CountdownText: View {
    let target: Date
    var foreground: Color = DSColors.secondaryText

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            Text(CountdownFormatter.string(until: target, from: context.date))
                .font(DSTypography.countdown)
                .foregroundStyle(foreground)
        }
    }
}

#Preview {
    CountdownText(target: Date().addingTimeInterval(5022))
        .padding()
}
