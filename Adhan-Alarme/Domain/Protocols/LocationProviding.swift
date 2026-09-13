import Foundation

enum LocationError: Error, Sendable, Hashable {
    case notAuthorized
    case serviceDisabled
    case requestFailed
}

/// Service de localisation one-shot, économe en batterie.
/// Implémentations confinées au MainActor (Core Location).
protocol LocationProviding: AnyObject {
    func authorizationStatus() -> LocationAuthorization
    func requestAuthorization() async -> LocationAuthorization
    func currentCoordinates() async throws -> Coordinates
}
