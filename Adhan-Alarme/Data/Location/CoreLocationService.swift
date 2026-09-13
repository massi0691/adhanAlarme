import CoreLocation
import Foundation

extension LocationAuthorization {
    init(_ status: CLAuthorizationStatus) {
        switch status {
        case .authorizedAlways, .authorizedWhenInUse: self = .authorized
        case .denied: self = .denied
        case .restricted: self = .restricted
        case .notDetermined: self = .notDetermined
        @unknown default: self = .notDetermined
        }
    }
}

/// Localisation one-shot via Core Location.
/// `requestLocation()` + précision kilométrique : économe en batterie
/// (aucun suivi continu). Requiert `NSLocationWhenInUseUsageDescription`.
@MainActor
final class CoreLocationService: NSObject, LocationProviding, CLLocationManagerDelegate {
    private let manager: CLLocationManager
    private var authorizationContinuation: CheckedContinuation<LocationAuthorization, Never>?
    private var locationContinuation: CheckedContinuation<Coordinates, Error>?

    override init() {
        self.manager = CLLocationManager()
        super.init()
        manager.delegate = self
        // Précision ville (~km) : suffisante pour les horaires, rapide et économe.
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    func authorizationStatus() -> LocationAuthorization {
        LocationAuthorization(manager.authorizationStatus)
    }

    func requestAuthorization() async -> LocationAuthorization {
        let current = authorizationStatus()
        guard current == .notDetermined else { return current }
        return await withCheckedContinuation { continuation in
            authorizationContinuation = continuation
            manager.requestWhenInUseAuthorization()
        }
    }

    func currentCoordinates() async throws -> Coordinates {
        guard CLLocationManager.locationServicesEnabled() else {
            throw LocationError.serviceDisabled
        }
        switch authorizationStatus() {
        case .authorized:
            break
        case .notDetermined:
            let status = await requestAuthorization()
            guard status == .authorized else { throw LocationError.notAuthorized }
        case .denied, .restricted:
            throw LocationError.notAuthorized
        }
        return try await withCheckedThrowingContinuation { continuation in
            locationContinuation = continuation
            manager.requestLocation()
        }
    }

    // MARK: - CLLocationManagerDelegate (non isolés : relais vers le MainActor)

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            self.authorizationContinuation?.resume(returning: LocationAuthorization(status))
            self.authorizationContinuation = nil
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let coordinate = locations.last?.coordinate else { return }
        let latitude = coordinate.latitude
        let longitude = coordinate.longitude
        Task { @MainActor in
            self.locationContinuation?.resume(returning: Coordinates(latitude: latitude, longitude: longitude))
            self.locationContinuation = nil
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        let code = (error as? CLError)?.code
        Task { @MainActor in
            let mapped: LocationError = code == .denied ? .notAuthorized : .requestFailed
            self.locationContinuation?.resume(throwing: mapped)
            self.locationContinuation = nil
        }
    }
}
