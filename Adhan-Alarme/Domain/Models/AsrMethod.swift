import Foundation

/// Convention de calcul de l'Asr (facteur d'ombre).
enum AsrMethod: String, Sendable, Codable, CaseIterable, Hashable {
    /// Ombre = 1× l'objet (majoritaire).
    case standard
    /// Ombre = 2× l'objet (Hanafi).
    case hanafi

    /// Clé de localisation (catalogue complété avec l'écran Réglages, phase 5).
    var titleKey: String { "asr.\(rawValue)" }
}
