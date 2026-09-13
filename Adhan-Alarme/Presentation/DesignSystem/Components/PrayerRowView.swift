import SwiftUI

/// Ligne d'horaire : médaillon icône (moment du soleil), nom localisé,
/// nom arabe et heure. La prochaine prière se distingue par un
/// médaillon doré ; les prières passées sont estompées.
struct PrayerRowView: View {
    let prayer: Prayer
    let time: Date
    let isNext: Bool
    let isPast: Bool

    var body: some View {
        HStack(spacing: DSSpacing.md) {
            Image(systemName: prayer.iconName)
                .font(.body)
                .foregroundStyle(isNext ? DSColors.brandInk : DSColors.brand)
                .frame(minWidth: 40, minHeight: 40)
                .background(isNext ? DSColors.goldBright : DSColors.brand.opacity(0.12))
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(LocalizedStringKey(prayer.titleKey))
                    .font(DSTypography.prayerName)
                Text(prayer.arabicName)
                    .font(DSTypography.prayerArabicName)
                    .foregroundStyle(DSColors.secondaryText)
            }
            Spacer()
            Text(time, style: .time)
                .font(DSTypography.prayerTime)
        }
        .foregroundStyle(DSColors.primaryText)
        .padding(.horizontal, DSSpacing.md)
        .padding(.vertical, DSSpacing.sm)
        .background(isNext ? DSColors.nextHighlight : DSColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: DSSpacing.rowCornerRadius))
        .opacity(isPast ? 0.55 : 1)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    VStack(spacing: 8) {
        PrayerRowView(prayer: .fajr, time: Date(), isNext: false, isPast: true)
        PrayerRowView(prayer: .dhuhr, time: Date(), isNext: true, isPast: false)
        PrayerRowView(prayer: .isha, time: Date(), isNext: false, isPast: false)
    }
    .padding()
}
