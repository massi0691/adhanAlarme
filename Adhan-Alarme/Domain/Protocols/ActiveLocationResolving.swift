import Foundation

enum ActiveLocationError: Error, Sendable, Hashable {
    case noCitySelected
}

/// Résout la position active (GPS ou ville manuelle) avec secours.
protocol ActiveLocationResolving: AnyObject {
    func resolveActiveLocation() async throws -> ActiveLocation
}
