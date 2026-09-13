import Foundation

/// Géocodage inverse best-effort (nom de ville depuis des coordonnées).
/// Ne lève jamais : `nil` en cas d'échec.
protocol ReverseGeocoding: AnyObject {
    func localityName(for coordinates: Coordinates) async -> String?
}
