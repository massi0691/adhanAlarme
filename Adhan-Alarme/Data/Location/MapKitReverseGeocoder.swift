import CoreLocation
import Foundation
import MapKit

/// Géocodage inverse via MapKit (gratuit, Apple). Best-effort : `nil` si échec.
/// API iOS 26 : CLGeocoder déprécié → MKReverseGeocodingRequest +
/// addressRepresentations (cityName, cityWithContext).
@MainActor
final class MapKitReverseGeocoder: ReverseGeocoding {
    func localityName(for coordinates: Coordinates) async -> String? {
        let location = CLLocation(latitude: coordinates.latitude, longitude: coordinates.longitude)
        guard let request = MKReverseGeocodingRequest(location: location),
              let items = try? await request.mapItems,
              let item = items.first else {
            return nil
        }
        let representations = item.addressRepresentations
        return representations?.cityName
            ?? representations?.cityWithContext
            ?? item.name
    }
}
