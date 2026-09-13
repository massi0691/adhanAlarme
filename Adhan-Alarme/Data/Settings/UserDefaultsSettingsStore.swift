import Foundation
import Observation

/// Magasin de réglages persisté en `UserDefaults` (JSON versionné).
/// Toute évolution du schéma doit changer `storageKey` (migration simple).
@Observable
@MainActor
final class UserDefaultsSettingsStore: SettingsStoring {
    private static let storageKey = "app.settings.v1"

    private let userDefaults: UserDefaults

    var settings: AppSettings {
        didSet { save() }
    }

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        if let data = userDefaults.data(forKey: Self.storageKey),
           let decoded = try? JSONDecoder().decode(AppSettings.self, from: data) {
            self.settings = decoded
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
