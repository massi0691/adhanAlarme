import Foundation
import Observation

/// Langue de l'interface : source unique observable, persistée dans
/// les réglages. Lue par l'app (locale + direction) et les services
/// (notifications), écrite par le sélecteur in-app (Réglages).
@Observable
@MainActor
final class LanguageSettings {
    private let settingsStore: any SettingsStoring

    /// Langue choisie (mutation via `setAppLanguage`, qui persiste).
    private(set) var appLanguage: AppLanguage

    init(settingsStore: any SettingsStoring) {
        self.settingsStore = settingsStore
        self.appLanguage = settingsStore.settings.appLanguage
    }

    /// Change la langue et persiste le choix.
    func setAppLanguage(_ language: AppLanguage) {
        appLanguage = language
        var settings = settingsStore.settings
        settings.appLanguage = language
        settingsStore.settings = settings
    }

    /// Locale SwiftUI (`nil` = suivre l'appareil).
    var locale: Locale? {
        appLanguage.localeIdentifier.map(Locale.init(identifier:))
    }
}
