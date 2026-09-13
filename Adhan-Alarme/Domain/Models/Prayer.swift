import Foundation

/// Prières et événement solaire affichés sur l'écran principal.
///
/// `sunrise` (Chourouk) n'est pas une prière obligatoire mais un repère
/// affiché et pris en compte dans le compte à rebours.
enum Prayer: String, Sendable, Codable, CaseIterable, Identifiable, Hashable {
    case fajr
    case sunrise
    case dhuhr
    case asr
    case maghrib
    case isha

    var id: String { rawValue }

    /// Clé de localisation du nom affiché (français / anglais / arabe / kabyle).
    var titleKey: String { "prayer.\(rawValue)" }

    /// Nom arabe canonique, identique dans toutes les langues.
    var arabicName: String {
        switch self {
        case .fajr: "الفجر"
        case .sunrise: "الشروق"
        case .dhuhr: "الظهر"
        case .asr: "العصر"
        case .maghrib: "المغرب"
        case .isha: "العشاء"
        }
    }

    /// `false` pour le lever du soleil, qui n'est pas une prière.
    var isObligatory: Bool { self != .sunrise }
}
