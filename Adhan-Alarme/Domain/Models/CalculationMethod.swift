import Foundation

/// Méthode de calcul des horaires de prière.
/// Les paramètres astronomiques (angles) sont branchés en phase 5.
enum CalculationMethod: String, Sendable, Codable, CaseIterable, Hashable {
    case muslimWorldLeague
    case egyptian
    case karachi
    case ummAlQura
    case isna
    case diyanet
    case kuwait
    case qatar
    case singapore
    case tehran
    case jafari
    /// Union des Organisations Islamiques de France (12°/12°).
    /// Ajoutée en phase 2 : méthode de référence pour la France,
    /// vérifiée via l'API Aladhan (méthode n° 12).
    case uoif

    /// Clé de localisation (catalogue complété avec l'écran Réglages, phase 5).
    var titleKey: String { "method.\(rawValue)" }
}
