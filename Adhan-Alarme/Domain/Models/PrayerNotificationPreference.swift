import Foundation

/// Préférence d'alerte pour une prière.
struct PrayerNotificationPreference: Sendable, Codable, Hashable {
    let prayer: Prayer
    var enabled: Bool
    var mode: PrayerAlertMode
    var selectedMuezzinID: String

    /// Préférences par défaut : Adhan pour les prières obligatoires,
    /// simple notification pour le lever du soleil.
    static func defaults(for prayer: Prayer) -> PrayerNotificationPreference {
        PrayerNotificationPreference(
            prayer: prayer,
            enabled: true,
            mode: prayer.isObligatory ? .adhan : .notificationOnly,
            selectedMuezzinID: Muezzin.defaultID
        )
    }
}
