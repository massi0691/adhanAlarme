import Foundation

/// Réglages persistés de l'application (voir `SettingsStoring`).
struct AppSettings: Sendable, Codable, Hashable {
    var useAutomaticLocation: Bool = true
    var calculation: PrayerCalculationConfiguration = PrayerCalculationConfiguration()
    var globalAdhanEnabled: Bool = true
    /// Hack « Adhan long » (notifications chaînées, expérimental).
    /// Champ ajouté avant publication : pas de migration d'ancien schéma.
    var longAdhanEnabled = false
    var selectedMuezzinID: String = Muezzin.defaultID
    var prayerPreferences: [Prayer: PrayerNotificationPreference] = Dictionary(
        uniqueKeysWithValues: Prayer.allCases.map { ($0, .defaults(for: $0)) }
    )
    var appLanguage: AppLanguage = .system
    var appearance: AppAppearance = .system
    /// Dernière position GPS connue (secours si le GPS est indisponible).
    var lastAutomaticCoordinates: Coordinates?
    /// Nom correspondant (géocodage inverse best-effort).
    var lastAutomaticDisplayName: String?

    static let `default` = AppSettings()
}
