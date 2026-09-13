import CoreLocation
import Foundation

/// Géocodage inverse via CLGeocoder (gratuit, Apple). Best-effort : `nil` si échec.
@MainActor
final class CLGeocoderReverseGeocoder: ReverseGeocoding {
    func localityName(for coordinates: Coordinates) async -> String? {
        let location = CLLocation(latitude: coordinates.latitude, longitude: coordinates.longitude)
        guard let placemarks = try? await CLGeocoder().reverseGeocodeLocation(location),
              let placemark = placemarks.first else {
            return nil
        }
        return placemark.locality
            ?? placemark.subAdministrativeArea
            ?? placemark.administrativeArea
            ?? placemark.country
    }
}
