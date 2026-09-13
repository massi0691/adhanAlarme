import SwiftUI

/// Carte de la prochaine échéance : nom, horaire et compte à rebours.
struct NextPrayerCardView: View {
    let nextPrayer: NextPrayer

    var body: some View {
        VStack(spacing: DSSpacing.sm) {
            Text("home.nextPrayer")
                .font(DSTypography.city)
                .foregroundStyle(DSColors.secondaryText)

            Text(LocalizedStringKey(nextPrayer.prayer.titleKey))
                .font(DSTypography.nextPrayerName)
                .textCase(.uppercase)

            Text(nextPrayer.date, style: .time)
                .font(DSTypography.nextPrayerTime)
                .fontDesign(.rounded)

            HStack(spacing: DSSpacing.xs) {
                Text("home.in")
                CountdownText(target: nextPrayer.date)
                if nextPrayer.isTomorrow {
                    Text("home.tomorrow")
                }
            }
            .foregroundStyle(DSColors.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(DSSpacing.lg)
        .background(DSColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: DSSpacing.cardCornerRadius))
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    NextPrayerCardView(
        nextPrayer: NextPrayer(
            prayer: .dhuhr,
            date: Date().addingTimeInterval(5022),
            isTomorrow: false
        )
    )
    .padding()
}
