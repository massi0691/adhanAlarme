import Foundation

/// Apparence de l'interface : suit le système ou forcée.
/// Persistée (`AppSettings.appearance`), appliquée à la racine
/// via `.preferredColorScheme` (voir `AppearanceSettings`).
enum AppAppearance: String, Sendable, Codable, CaseIterable, Hashable {
    case system
    case light
    case dark
}

extension AppAppearance {
    /// `nil` = suivre le système.
    var prefersDark: Bool? {
        switch self {
        case .system: nil
        case .light: false
        case .dark: true
        }
    }

    /// Clé localisée du nom affiché.
    var titleKey: String {
        switch self {
        case .system: "appearance.system"
        case .light: "appearance.light"
        case .dark: "appearance.dark"
        }
    }
}
