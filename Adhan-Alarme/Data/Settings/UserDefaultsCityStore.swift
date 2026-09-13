import Foundation
import Observation

/// Villes enregistrées + ville active, persistées en `UserDefaults`
/// (JSON versionné, 20 villes max). Source unique du mode manuel.
@Observable
@MainActor
final class UserDefaultsCityStore: CityStoring {
    private static let storageKey = "app.cities.v1"
    private static let maxCities = 20

    private struct Persisted: Codable {
        var cities: [SavedCity] = []
        var activeCityID: UUID?
    }

    private let userDefaults: UserDefaults

    private(set) var cities: [SavedCity] {
        didSet { save() }
    }

    var activeCityID: UUID? {
        didSet { save() }
    }

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        if let data = userDefaults.data(forKey: Self.storageKey),
           let decoded = try? JSONDecoder().decode(Persisted.self, from: data) {
            self.cities = decoded.cities
            self.activeCityID = decoded.activeCityID
        } else {
            self.cities = []
            self.activeCityID = nil
        }
    }

    func add(_ city: SavedCity) {
        cities.append(city)
        if cities.count > Self.maxCities {
            cities.removeFirst(cities.count - Self.maxCities)
        }
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

    private func save() {
        let persisted = Persisted(cities: cities, activeCityID: activeCityID)
        guard let data = try? JSONEncoder().encode(persisted) else { return }
        userDefaults.set(data, forKey: Self.storageKey)
    }
}
