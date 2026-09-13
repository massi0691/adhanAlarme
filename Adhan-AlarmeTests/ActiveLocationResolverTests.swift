import Foundation
import Testing
@testable import Adhan_Alarme

/// Tests du résolveur de position (cascade GPS → dernier connu → ville).
struct ActiveLocationResolverTests {
    private final class StubSettingsStore: SettingsStoring {
        var settings = AppSettings.default
    }

    private final class StubCityStore: CityStoring {
        var cities: [SavedCity] = []
        var activeCityID: UUID?

        func add(_ city: SavedCity) {
            cities.append(city)
        }

        func remove(id: UUID) {
            cities.removeAll { $0.id == id }
            if activeCityID == id {
                activeCityID = nil
            }
        }

        func city(id: UUID?) -> SavedCity? {
            guard let id else { return nil }
            return cities.first { $0.id == id }
        }
    }

    private final class StubLocationService: LocationProviding {
        var coordinatesToReturn: Coordinates?
        var errorToThrow: (any Error)?
        var status: LocationAuthorization = .authorized

        func authorizationStatus() -> LocationAuthorization { status }
        func requestAuthorization() async -> LocationAuthorization { status }

        func currentCoordinates() async throws -> Coordinates {
            if let errorToThrow { throw errorToThrow }
            if let coordinatesToReturn { return coordinatesToReturn }
            throw LocationError.requestFailed
        }
    }

    private final class StubGeocoder: ReverseGeocoding {
        var name: String?
        private(set) var callCount = 0

        func localityName(for coordinates: Coordinates) async -> String? {
            callCount += 1
            return name
        }
    }

    private let evry = Coordinates(latitude: 48.6298, longitude: 2.4412)

    private func makeResolver(
        settings: StubSettingsStore = StubSettingsStore(),
        cities: StubCityStore = StubCityStore(),
        location: StubLocationService = StubLocationService(),
        geocoder: StubGeocoder = StubGeocoder()
    ) -> (ActiveLocationResolver, StubSettingsStore, StubCityStore, StubLocationService, StubGeocoder) {
        let resolver = ActiveLocationResolver(
            settingsStore: settings,
            cityStore: cities,
            locationService: location,
            geocoder: geocoder
        )
        return (resolver, settings, cities, location, geocoder)
    }

    @Test func automaticMode_returnsGPSLocation() async throws {
        let (resolver, settings, _, location, geocoder) = makeResolver()
        location.coordinatesToReturn = evry
        geocoder.name = "Évry-Courcouronnes"

        let resolved = try await resolver.resolveActiveLocation()

        #expect(resolved.coordinates == evry)
        #expect(resolved.displayName == "Évry-Courcouronnes")
        #expect(resolved.timeZone == .current)
        #expect(settings.settings.lastAutomaticCoordinates == evry)
        #expect(settings.settings.lastAutomaticDisplayName == "Évry-Courcouronnes")
    }

    @Test func gpsFailure_fallsBackToLastKnown() async throws {
        let (resolver, settings, _, location, _) = makeResolver()
        settings.settings.lastAutomaticCoordinates = evry
        settings.settings.lastAutomaticDisplayName = "Évry-Courcouronnes"
        location.errorToThrow = LocationError.notAuthorized

        let resolved = try await resolver.resolveActiveLocation()

        #expect(resolved.coordinates == evry)
        #expect(resolved.displayName == "Évry-Courcouronnes")
    }

    @Test func gpsFailure_fallsBackToActiveCity() async throws {
        let (resolver, _, cities, location, _) = makeResolver()
        let city = SavedCity(
            name: "Tizi Ouzou",
            country: "Algérie",
            coordinates: Coordinates(latitude: 36.7167, longitude: 4.05),
            timeZoneIdentifier: "Africa/Algiers"
        )
        cities.cities = [city]
        cities.activeCityID = city.id
        location.errorToThrow = LocationError.serviceDisabled

        let resolved = try await resolver.resolveActiveLocation()

        #expect(resolved.coordinates == city.coordinates)
        #expect(resolved.displayName == "Tizi Ouzou")
        #expect(resolved.timeZone.identifier == "Africa/Algiers")
    }

    @Test func gpsFailureWithoutFallback_rethrows() async throws {
        let (resolver, _, _, location, _) = makeResolver()
        location.errorToThrow = LocationError.notAuthorized

        await #expect(throws: LocationError.notAuthorized) {
            try await resolver.resolveActiveLocation()
        }
    }

    @Test func manualMode_returnsActiveCity() async throws {
        let (resolver, settings, cities, _, _) = makeResolver()
        settings.settings.useAutomaticLocation = false
        let city = SavedCity(
            name: "Casablanca",
            country: "Maroc",
            coordinates: Coordinates(latitude: 33.5731, longitude: -7.5898),
            timeZoneIdentifier: "Africa/Casablanca"
        )
        cities.cities = [city]
        cities.activeCityID = city.id

        let resolved = try await resolver.resolveActiveLocation()

        #expect(resolved.displayName == "Casablanca")
        #expect(resolved.timeZone.identifier == "Africa/Casablanca")
    }

    @Test func manualModeWithoutCity_throws() async throws {
        let (resolver, settings, _, _, _) = makeResolver()
        settings.settings.useAutomaticLocation = false

        await #expect(throws: ActiveLocationError.noCitySelected) {
            try await resolver.resolveActiveLocation()
        }
    }

    @Test func geocoding_isSkippedWhenCloseToLastKnown() async throws {
        let (resolver, settings, _, location, geocoder) = makeResolver()
        settings.settings.lastAutomaticCoordinates = evry
        settings.settings.lastAutomaticDisplayName = "Évry-Courcouronnes"
        location.coordinatesToReturn = Coordinates(latitude: 48.6300, longitude: 2.4415)
        geocoder.name = "ShouldNotBeUsed"

        let resolved = try await resolver.resolveActiveLocation()

        #expect(geocoder.callCount == 0)
        #expect(resolved.displayName == "Évry-Courcouronnes")
    }
}
