import Foundation
import Observation
import SwiftUI

/// Apparence : source unique observable, persistée dans les réglages.
/// Lue par l'app (`.preferredColorScheme`), écrite par Réglages.
@Observable
@MainActor
final class AppearanceSettings {
    private let settingsStore: any SettingsStoring

    /// Apparence choisie (mutation via `setAppearance`, qui persiste).
    private(set) var appearance: AppAppearance

    init(settingsStore: any SettingsStoring) {
        self.settingsStore = settingsStore
        self.appearance = settingsStore.settings.appearance
    }

    /// Change l'apparence et persiste le choix.
    func setAppearance(_ appearance: AppAppearance) {
        self.appearance = appearance
        var settings = settingsStore.settings
        settings.appearance = appearance
        settingsStore.settings = settings
    }

    /// Scheme SwiftUI (`nil` = suivre le système).
    var colorScheme: ColorScheme? {
        switch appearance {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}
