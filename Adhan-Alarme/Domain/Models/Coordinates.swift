import Foundation

/// Coordonnées géographiques utilisées pour le calcul des horaires.
struct Coordinates: Sendable, Codable, Hashable {
    let latitude: Double
    let longitude: Double

    /// Coordonnées géographiques plausibles.
    var isValid: Bool {
        latitude.isFinite
            && longitude.isFinite
            && (-90...90).contains(latitude)
            && (-180...180).contains(longitude)
    }
}
