import Foundation

/// Résout la position active : GPS (mode auto) ou ville (mode manuel).
/// Cascade de secours en mode auto : GPS → dernière position connue →
/// ville active → erreur (l'UI propose alors de choisir une ville).
/// Le nom GPS est géocodé au plus une fois par déplacement significatif.
@MainActor
final class ActiveLocationResolver: ActiveLocationResolving {
    /// Seuil de re-géocodage (~500 m, en degrés).
    private static let geocodeThreshold = 0.005

    private let settingsStore: any SettingsStoring
    private let cityStore: any CityStoring
    private let locationService: any LocationProviding
    private let geocoder: any ReverseGeocoding

    init(
        settingsStore: any SettingsStoring,
        cityStore: any CityStoring,
        locationService: any LocationProviding,
        geocoder: any ReverseGeocoding
    ) {
        self.settingsStore = settingsStore
        self.cityStore = cityStore
        self.locationService = locationService
        self.geocoder = geocoder
    }

    func resolveActiveLocation() async throws -> ActiveLocation {
        if settingsStore.settings.useAutomaticLocation {
            do {
                let coordinates = try await locationService.currentCoordinates()
                let displayName = await refreshedDisplayName(for: coordinates)
                settingsStore.settings.lastAutomaticCoordinates = coordinates
                if let displayName {
                    settingsStore.settings.lastAutomaticDisplayName = displayName
                }
                return ActiveLocation(coordinates: coordinates, displayName: displayName, timeZone: .current)
            } catch {
                if let last = settingsStore.settings.lastAutomaticCoordinates {
                    return ActiveLocation(
                        coordinates: last,
                        displayName: settingsStore.settings.lastAutomaticDisplayName,
                        timeZone: .current
                    )
                }
                if let city = cityStore.city(id: cityStore.activeCityID) {
                    return location(for: city)
                }
                throw error
            }
        }
        guard let city = cityStore.city(id: cityStore.activeCityID) else {
            throw ActiveLocationError.noCitySelected
        }
        return location(for: city)
    }

    private func location(for city: SavedCity) -> ActiveLocation {
        let zone: TimeZone
        if let identifier = city.timeZoneIdentifier, let parsed = TimeZone(identifier: identifier) {
            zone = parsed
        } else {
            zone = .current
        }
        return ActiveLocation(coordinates: city.coordinates, displayName: city.name, timeZone: zone)
    }

    private func refreshedDisplayName(for coordinates: Coordinates) async -> String? {
        let settings = settingsStore.settings
        if let last = settings.lastAutomaticCoordinates,
           abs(last.latitude - coordinates.latitude) < Self.geocodeThreshold,
           abs(last.longitude - coordinates.longitude) < Self.geocodeThreshold,
           let cached = settings.lastAutomaticDisplayName {
            return cached
        }
        return await geocoder.localityName(for: coordinates)
    }
}
