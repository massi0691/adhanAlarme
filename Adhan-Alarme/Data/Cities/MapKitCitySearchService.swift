import CoreLocation
import Foundation
import MapKit

/// Recherche de villes via MapKit (gratuit, sans clé API, mondial).
/// Autocomplétion pendant la frappe + résolution complète
/// (coordonnées, localité, pays, fuseau horaire).
@MainActor
final class MapKitCitySearchService: NSObject, CitySearching, MKLocalSearchCompleterDelegate {
    private let completer: MKLocalSearchCompleter
    private var searchContinuation: CheckedContinuation<[CitySearchResult], Never>?

    override init() {
        self.completer = MKLocalSearchCompleter()
        super.init()
        completer.delegate = self
        completer.resultTypes = .address
    }

    func searchCities(matching query: String) async throws -> [CitySearchResult] {
        // Annule la recherche précédente (la dernière frappe gagne).
        searchContinuation?.resume(returning: [])
        searchContinuation = nil
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else { return [] }
        return await withCheckedContinuation { continuation in
            searchContinuation = continuation
            completer.queryFragment = trimmed
        }
    }

    func resolveCity(_ result: CitySearchResult) async throws -> SavedCity {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = "\(result.title) \(result.subtitle)".trimmingCharacters(in: .whitespaces)
        request.resultTypes = .address
        let response = try? await MKLocalSearch(request: request).start()
        guard let item = response?.mapItems.first else {
            throw CitySearchError.noResults
        }
        let placemark = item.placemark
        let coordinates = Coordinates(
            latitude: placemark.coordinate.latitude,
            longitude: placemark.coordinate.longitude
        )
        guard coordinates.isValid else { throw CitySearchError.resolutionFailed }
        let timeZone = await resolveTimeZone(placemark: placemark, coordinates: coordinates)
        return SavedCity(
            name: placemark.locality ?? result.title,
            country: placemark.country,
            coordinates: coordinates,
            timeZoneIdentifier: timeZone.identifier
        )
    }

    private func resolveTimeZone(placemark: MKPlacemark, coordinates: Coordinates) async -> TimeZone {
        if let zone = placemark.timeZone {
            return zone
        }
        // Secours : géocodage inverse (renseigne toujours le fuseau).
        let location = CLLocation(latitude: coordinates.latitude, longitude: coordinates.longitude)
        if let placemarks = try? await CLGeocoder().reverseGeocodeLocation(location),
           let zone = placemarks.first?.timeZone {
            return zone
        }
        return .current
    }

    // MARK: - MKLocalSearchCompleterDelegate (non isolés : relais MainActor)

    nonisolated func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        let pairs = completer.results.map { ($0.title, $0.subtitle) }
        Task { @MainActor in
            self.searchContinuation?.resume(returning: pairs.map {
                CitySearchResult(title: $0.0, subtitle: $0.1)
            })
            self.searchContinuation = nil
        }
    }

    nonisolated func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        Task { @MainActor in
            // Autocomplétion : un échec (réseau…) vaut "aucun résultat".
            self.searchContinuation?.resume(returning: [])
            self.searchContinuation = nil
        }
    }
}
