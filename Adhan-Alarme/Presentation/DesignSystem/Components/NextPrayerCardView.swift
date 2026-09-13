import SwiftUI

/// Carte hero de la prochaine échéance : médaillon doré, nom, horaire
/// et compte à rebours en pilule, sur dégradé émeraude profond.
struct NextPrayerCardView: View {
    let nextPrayer: NextPrayer

    var body: some View {
        VStack(spacing: DSSpacing.md) {
            HStack(spacing: DSSpacing.md) {
                Image(systemName: nextPrayer.prayer.iconName)
                    .font(.title2)
                    .foregroundStyle(DSColors.brandInk)
                    .frame(minWidth: 56, minHeight: 56)
                    .background(DSColors.goldBright)
                    .clipShape(Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text("home.nextPrayer")
                        .font(DSTypography.city)
                        .foregroundStyle(DSColors.goldBright)
                    Text(LocalizedStringKey(nextPrayer.prayer.titleKey))
                        .font(DSTypography.nextPrayerName)
                        .textCase(.uppercase)
                        .foregroundStyle(DSColors.onBrand)
                }
                Spacer()
                if nextPrayer.isTomorrow {
                    Text("home.tomorrow")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(DSColors.brandInk)
                        .padding(.horizontal, DSSpacing.sm)
                        .padding(.vertical, DSSpacing.xs)
                        .background(DSColors.goldBright)
                        .clipShape(Capsule())
                }
            }
            Text(nextPrayer.date, style: .time)
                .font(DSTypography.nextPrayerTime)
                .fontDesign(.rounded)
                .foregroundStyle(DSColors.onBrand)
            HStack(spacing: DSSpacing.xs) {
                Text("home.in")
                CountdownText(target: nextPrayer.date, foreground: DSColors.brandInk)
            }
            .foregroundStyle(DSColors.brandInk)
            .padding(.horizontal, DSSpacing.md)
            .padding(.vertical, DSSpacing.sm)
            .background(DSColors.goldBright)
            .clipShape(Capsule())
        }
        .frame(maxWidth: .infinity)
        .padding(DSSpacing.lg)
        .background(DSColors.heroGradient)
        .clipShape(RoundedRectangle(cornerRadius: DSSpacing.cardCornerRadius))
        .shadow(color: .black.opacity(0.15), radius: 12, y: 6)
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
