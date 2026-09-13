import Foundation

/// Position active résolue : coordonnées + nom d'affichage + fuseau.
struct ActiveLocation: Sendable, Hashable {
    let coordinates: Coordinates
    /// Nom de ville, ou `nil` (position GPS non géocodée) : l'UI affiche
    /// alors un libellé localisé générique.
    let displayName: String?
    let timeZone: TimeZone
}
