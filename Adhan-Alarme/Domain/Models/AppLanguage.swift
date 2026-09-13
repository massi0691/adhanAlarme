import Foundation

/// Langue de l'interface.
/// Le sélecteur in-app et le chargeur kabyle arrivent en phase 6 ;
/// `system` suit la langue de l'appareil (comportement phase 1).
enum AppLanguage: String, Sendable, Codable, CaseIterable, Hashable {
    case system
    case french
    case english
    case arabic
    case kabyle

    /// Identifiant de locale ; `nil` = suivre l'appareil.
    var localeIdentifier: String? {
        switch self {
        case .system: nil
        case .french: "fr"
        case .english: "en"
        case .arabic: "ar"
        case .kabyle: "kab"
        }
    }

    var isRightToLeft: Bool { self == .arabic }
}
