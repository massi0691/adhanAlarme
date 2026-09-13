import Foundation

/// État simplifié de l'autorisation de localisation (pour l'UI).
enum LocationAuthorization: Sendable, Hashable {
    case authorized
    case denied
    case restricted
    case notDetermined
}
