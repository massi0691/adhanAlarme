import Foundation

enum AladhanError: Error, Sendable, Hashable {
    case invalidURL
    case requestFailed
    case invalidResponse
    case missingTimezone
    case invalidTimeFormat
}

/// Fournisseur API Aladhan (https://aladhan.com/prayer-times-api).
/// Gratuit, sans clé, documenté. Numéros de méthodes, `school` et
/// `latitudeAdjustmentMethod` vérifiés le 2026-09-13 par appels réels
/// (voir `docs/ARCHITECTURE.md`).
///
/// Note : les angles personnalisés ne sont pas transmis à l'API (format
/// `methodSettings` non vérifiable) — le dépôt contourne l'API dans ce cas
/// et utilise le calcul local, en ligne comme hors-ligne.
struct AladhanAPIProvider: PrayerTimesProvider {
    typealias DataLoader = @Sendable (URL) async throws -> (Data, URLResponse)

    private let dataLoader: DataLoader

    init(dataLoader: @escaping DataLoader = AladhanAPIProvider.liveLoader) {
        self.dataLoader = dataLoader
    }

    nonisolated static func liveLoader(url: URL) async throws -> (Data, URLResponse) {
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        return try await URLSession.shared.data(for: request)
    }

    func fetchPrayerTimes(
        date: Date,
        coordinates: Coordinates,
        timeZone: TimeZone,
        configuration: PrayerCalculationConfiguration
    ) async throws -> PrayerTimes {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let day = calendar.startOfDay(for: date)
        let parts = calendar.dateComponents([.year, .month, .day], from: day)
        guard let year = parts.year, let month = parts.month, let dayNumber = parts.day else {
            throw AladhanError.invalidResponse
        }

        var components = URLComponents()
        components.scheme = "https"
        components.host = "api.aladhan.com"
        components.path = "/v1/timings/\(String(format: "%02d-%02d-%04d", dayNumber, month, year))"
        components.queryItems = [
            URLQueryItem(name: "latitude", value: String(coordinates.latitude)),
            URLQueryItem(name: "longitude", value: String(coordinates.longitude)),
            URLQueryItem(name: "method", value: String(Self.methodID(for: configuration.method))),
            URLQueryItem(name: "school", value: configuration.asrMethod == .hanafi ? "1" : "0"),
            URLQueryItem(
                name: "latitudeAdjustmentMethod",
                value: String(Self.latitudeAdjustmentID(for: configuration.highLatitudeRule))
            ),
        ]
        guard let url = components.url else { throw AladhanError.invalidURL }

        let data: Data
        do {
            (data, _) = try await dataLoader(url)
        } catch {
            throw AladhanError.requestFailed
        }

        let response: AladhanTimingsResponse
        do {
            response = try JSONDecoder().decode(AladhanTimingsResponse.self, from: data)
        } catch {
            throw AladhanError.invalidResponse
        }
        guard response.code == 200 else { throw AladhanError.invalidResponse }
        guard let zone = response.data.meta.timezone.flatMap(TimeZone.init(identifier:)) else {
            throw AladhanError.missingTimezone
        }

        var zoneCalendar = Calendar(identifier: .gregorian)
        zoneCalendar.timeZone = zone
        let zoneDay = zoneCalendar.startOfDay(for: day)
        let zoneParts = zoneCalendar.dateComponents([.year, .month, .day], from: zoneDay)
        guard let zoneYear = zoneParts.year, let zoneMonth = zoneParts.month, let zoneDayNumber = zoneParts.day else {
            throw AladhanError.invalidResponse
        }

        return PrayerTimes(
            date: zoneDay,
            timeZone: zone,
            fajr: try time(response.data.timings.fajr, year: zoneYear, month: zoneMonth, day: zoneDayNumber, calendar: zoneCalendar),
            sunrise: try time(response.data.timings.sunrise, year: zoneYear, month: zoneMonth, day: zoneDayNumber, calendar: zoneCalendar),
            dhuhr: try time(response.data.timings.dhuhr, year: zoneYear, month: zoneMonth, day: zoneDayNumber, calendar: zoneCalendar),
            asr: try time(response.data.timings.asr, year: zoneYear, month: zoneMonth, day: zoneDayNumber, calendar: zoneCalendar),
            maghrib: try time(response.data.timings.maghrib, year: zoneYear, month: zoneMonth, day: zoneDayNumber, calendar: zoneCalendar),
            isha: try time(response.data.timings.isha, year: zoneYear, month: zoneMonth, day: zoneDayNumber, calendar: zoneCalendar)
        )
    }

    // MARK: - Mapping documenté et vérifié

    private static func methodID(for method: CalculationMethod) -> Int {
        switch method {
        case .muslimWorldLeague: 3
        case .egyptian: 5
        case .karachi: 1
        case .ummAlQura: 4
        case .isna: 2
        case .diyanet: 13
        case .kuwait: 9
        case .qatar: 10
        case .singapore: 11
        case .tehran: 7
        case .jafari: 0
        case .uoif: 12
        }
    }

    private static func latitudeAdjustmentID(for rule: HighLatitudeRule) -> Int {
        switch rule {
        case .middleOfNight: 1
        case .oneSeventh: 2
        case .angleBased: 3
        }
    }

    // MARK: - Parsing

    /// Formats acceptés : "05:34" ou "05:34 (CEST)".
    private func time(
        _ raw: String,
        year: Int,
        month: Int,
        day: Int,
        calendar: Calendar
    ) throws -> Date {
        let clock = raw.components(separatedBy: " ").first ?? raw
        let fields = clock.components(separatedBy: ":")
        guard fields.count == 2,
              let hour = Int(fields[0]),
              let minute = Int(fields[1]),
              (0..<24).contains(hour),
              (0..<60).contains(minute) else {
            throw AladhanError.invalidTimeFormat
        }
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        guard let result = calendar.date(from: components) else {
            throw AladhanError.invalidTimeFormat
        }
        return result
    }

    // MARK: - DTO (clés excédentaires ignorées)

    private struct AladhanTimingsResponse: Decodable {
        let code: Int
        let data: AladhanData
    }

    private struct AladhanData: Decodable {
        let timings: AladhanTimings
        let meta: AladhanMeta
    }

    private struct AladhanTimings: Decodable {
        let fajr: String
        let sunrise: String
        let dhuhr: String
        let asr: String
        let maghrib: String
        let isha: String

        private enum CodingKeys: String, CodingKey {
            case fajr = "Fajr"
            case sunrise = "Sunrise"
            case dhuhr = "Dhuhr"
            case asr = "Asr"
            case maghrib = "Maghrib"
            case isha = "Isha"
        }
    }

    private struct AladhanMeta: Decodable {
        let timezone: String?
    }
}
