import Foundation

/// Réglages persistés de l'application (voir `SettingsStoring`).
struct AppSettings: Sendable, Codable, Hashable {
    var useAutomaticLocation: Bool = true
    var activeCityID: UUID?
    /// Nom de la ville active. Dupliqué en phase 1 ; la phase 2 introduira
    /// un dépôt de villes et ne conservera que l'identifiant.
    var activeCityName: String = "Évry-Courcouronnes"
    var calculation: PrayerCalculationConfiguration = PrayerCalculationConfiguration()
    var globalAdhanEnabled: Bool = true
    var selectedMuezzinID: String = Muezzin.defaultID
    var prayerPreferences: [Prayer: PrayerNotificationPreference] = Dictionary(
        uniqueKeysWithValues: Prayer.allCases.map { ($0, .defaults(for: $0)) }
    )
    var appLanguage: AppLanguage = .system

    static let `default` = AppSettings()
}
