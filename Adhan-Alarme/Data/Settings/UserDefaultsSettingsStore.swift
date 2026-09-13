import Foundation
import Observation

/// Magasin de réglages persisté en `UserDefaults` (JSON versionné).
/// Toute évolution du schéma change `storageKey` (migration simple).
@Observable
@MainActor
final class UserDefaultsSettingsStore: SettingsStoring {
    private static let storageKey = "app.settings.v2"
    private static let legacyStorageKey = "app.settings.v1"

    /// Schéma phase 1, conservé pour la migration sans perte.
    /// (La ville active v1 ne pointait sur aucune ville enregistrée :
    /// sa disparition ne perd aucune donnée.)
    private struct LegacySettings: Decodable {
        var useAutomaticLocation: Bool = true
        var activeCityID: UUID?
        var activeCityName: String = ""
        var calculation: PrayerCalculationConfiguration = PrayerCalculationConfiguration()
        var globalAdhanEnabled: Bool = true
        var selectedMuezzinID: String = Muezzin.defaultID
        var prayerPreferences: [Prayer: PrayerNotificationPreference]?
        var appLanguage: AppLanguage = .system
    }

    private let userDefaults: UserDefaults

    var settings: AppSettings {
        didSet { save() }
    }

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        if let data = userDefaults.data(forKey: Self.storageKey),
           let decoded = try? JSONDecoder().decode(AppSettings.self, from: data) {
            self.settings = decoded
        } else if let legacyData = userDefaults.data(forKey: Self.legacyStorageKey),
                  let legacy = try? JSONDecoder().decode(LegacySettings.self, from: legacyData) {
            var migrated = AppSettings.default
            migrated.useAutomaticLocation = legacy.useAutomaticLocation
            migrated.calculation = legacy.calculation
            migrated.globalAdhanEnabled = legacy.globalAdhanEnabled
            migrated.selectedMuezzinID = legacy.selectedMuezzinID
            migrated.prayerPreferences = legacy.prayerPreferences ?? AppSettings.default.prayerPreferences
            migrated.appLanguage = legacy.appLanguage
            self.settings = migrated
            // `didSet` ne s'exécute pas dans `init` : sauvegarde explicite.
            userDefaults.removeObject(forKey: Self.legacyStorageKey)
            if let data = try? JSONEncoder().encode(migrated) {
                userDefaults.set(data, forKey: Self.storageKey)
            }
        } else {
            self.settings = AppSettings.default
        }
    }

    func setGlobalAdhanEnabled(_ enabled: Bool) {
        settings.globalAdhanEnabled = enabled
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        userDefaults.set(data, forKey: Self.storageKey)
    }
}
