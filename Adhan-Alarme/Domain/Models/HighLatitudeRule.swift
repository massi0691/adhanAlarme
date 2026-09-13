import Foundation

/// Règle de calcul pour les régions à haute latitude.
enum HighLatitudeRule: String, Sendable, Codable, CaseIterable, Hashable {
    case middleOfNight
    case oneSeventh
    case angleBased

    /// Clé de localisation (catalogue complété avec l'écran Réglages, phase 5).
    var titleKey: String { "highLatitude.\(rawValue)" }
}
