import SwiftUI

/// Typographies sémantiques. Basées sur les styles de texte dynamiques :
/// Dynamic Type et accessibilité respectés (aucune taille fixe).
enum DSTypography {
    static let greeting: Font = .title2.weight(.semibold)
    static let city: Font = .subheadline
    static let nextPrayerName: Font = .largeTitle.weight(.bold)
    static let nextPrayerTime: Font = .largeTitle.weight(.bold)
    static let countdown: Font = .title2.monospacedDigit().weight(.semibold)
    static let prayerName: Font = .body.weight(.medium)
    static let prayerArabicName: Font = .subheadline
    static let prayerTime: Font = .body.monospacedDigit().weight(.semibold)
}
