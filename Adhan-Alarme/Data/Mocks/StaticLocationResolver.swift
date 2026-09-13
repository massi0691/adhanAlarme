import Foundation

/// Résolveur figé pour les previews (Évry-Courcouronnes, sans GPS ni réseau).
@MainActor
final class StaticLocationResolver: ActiveLocationResolving {
    func resolveActiveLocation() async throws -> ActiveLocation {
        ActiveLocation(
            coordinates: Coordinates(latitude: 48.6298, longitude: 2.4412),
            displayName: "Évry-Courcouronnes",
            timeZone: TimeZone(identifier: "Europe/Paris") ?? .current
        )
    }
}
