import Foundation
import Observation

/// Langue de l'interface : source unique observable, persistée dans
/// les réglages. Lue par l'app (locale + direction) et les services
/// (notifications), écrite par le sélecteur in-app (Réglages).
@Observable
@MainActor
final class LanguageSettings {
    private let settingsStore: any SettingsStoring

    var appLanguage: AppLanguage {
        didSet { settingsStore.settings.appLanguage = appLanguage }
    }

    init(settingsStore: any SettingsStoring) {
        self.settingsStore = settingsStore
        self.appLanguage = settingsStore.settings.appLanguage
    }

    /// Locale SwiftUI (`nil` = suivre l'appareil).
    var locale: Locale? {
        appLanguage.localeIdentifier.map(Locale.init(identifier:))
    }
}
