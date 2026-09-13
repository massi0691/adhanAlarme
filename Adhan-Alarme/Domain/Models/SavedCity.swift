import Foundation

/// Ville enregistrée par l'utilisateur (sélection manuelle).
/// Une seule ville est active à la fois (voir `AppSettings.activeCityID`).
struct SavedCity: Sendable, Codable, Hashable, Identifiable {
    let id: UUID
    let name: String
    let country: String?
    let coordinates: Coordinates
    /// Identifiant IANA optionnel ; `nil` = fuseau horaire de l'appareil.
    let timeZoneIdentifier: String?

    init(
        id: UUID = UUID(),
        name: String,
        country: String? = nil,
        coordinates: Coordinates,
        timeZoneIdentifier: String? = nil
    ) {
        self.id = id
        self.name = name
        self.country = country
        self.coordinates = coordinates
        self.timeZoneIdentifier = timeZoneIdentifier
    }
}
