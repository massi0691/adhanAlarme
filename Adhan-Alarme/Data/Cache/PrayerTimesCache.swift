import Foundation

/// Cache disque des horaires API (UserDefaults, JSON versionné).
/// Les horaires sont déterministes (jour + lieu + méthode) : une entrée
/// en cache n'est jamais périmée. Taille bornée (30 entrées, plus anciennes
/// évincées). Confiné au MainActor comme tout le flux de données.
@MainActor
final class PrayerTimesCache {
    private static let storageKey = "app.timingsCache.v1"
    private static let maxEntries = 30

    private struct Entry: Codable {
        let times: PrayerTimes
        let storedAt: Date
    }

    private let userDefaults: UserDefaults
    private var entries: [String: Entry]

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        if let data = userDefaults.data(forKey: Self.storageKey),
           let decoded = try? JSONDecoder().decode([String: Entry].self, from: data) {
            self.entries = decoded
        } else {
            self.entries = [:]
        }
    }

    func cached(
        date: Date,
        coordinates: Coordinates,
        timeZone: TimeZone,
        configuration: PrayerCalculationConfiguration
    ) -> PrayerTimes? {
        entries[Self.key(date: date, coordinates: coordinates, timeZone: timeZone, configuration: configuration)]?.times
    }

    func store(
        _ times: PrayerTimes,
        date: Date,
        coordinates: Coordinates,
        timeZone: TimeZone,
        configuration: PrayerCalculationConfiguration
    ) {
        entries[Self.key(date: date, coordinates: coordinates, timeZone: timeZone, configuration: configuration)] = Entry(
            times: times,
            storedAt: Date()
        )
        trim()
        save()
    }

    /// Clé = jour + fuseau + position arrondie (~1 km) + empreinte de config.
    /// Tout changement de méthode, Asr, règle de latitude, angles ou
    /// ajustements invalide l'entrée (nouvelle clé → nouvel appel API).
    static func key(
        date: Date,
        coordinates: Coordinates,
        timeZone: TimeZone,
        configuration: PrayerCalculationConfiguration
    ) -> String {
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC") ?? .current
        let parts = utc.dateComponents([.year, .month, .day], from: date)
        let latitude = (coordinates.latitude * 100).rounded() / 100
        let longitude = (coordinates.longitude * 100).rounded() / 100
        let adjustments = configuration.manualAdjustments
            .sorted { $0.key.rawValue < $1.key.rawValue }
            .map { "\($0.key.rawValue)=\($0.value)" }
            .joined(separator: ",")
        let fingerprint = [
            configuration.method.rawValue,
            configuration.asrMethod.rawValue,
            configuration.highLatitudeRule.rawValue,
            configuration.fajrAngleOverride.map { String(describing: $0) } ?? "-",
            configuration.ishaAngleOverride.map { String(describing: $0) } ?? "-",
            adjustments,
        ].joined(separator: "|")
        return "\(timeZone.identifier)|\(parts.year ?? 0)-\(parts.month ?? 0)-\(parts.day ?? 0)|\(latitude),\(longitude)|\(fingerprint)"
    }

    private func trim() {
        guard entries.count > Self.maxEntries else { return }
        let ordered = entries.sorted { $0.value.storedAt < $1.value.storedAt }
        for (key, _) in ordered.prefix(entries.count - Self.maxEntries) {
            entries.removeValue(forKey: key)
        }
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        userDefaults.set(data, forKey: Self.storageKey)
    }
}
