import Foundation

/// Dépôt simulé : horaires fixes et déterministes pour la journée demandée,
/// dans le fuseau fourni. Conservé pour d'éventuels tests d'intégration ;
/// la production utilise `DefaultPrayerTimesRepository` depuis la phase 2.
struct MockPrayerTimesRepository: PrayerTimesRepository {
    enum MockError: Error {
        case invalidDateComponents
    }

    func fetchPrayerTimes(
        date: Date,
        coordinates: Coordinates,
        timeZone: TimeZone,
        configuration: PrayerCalculationConfiguration
    ) async throws -> PrayerTimes {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone

        func time(hour: Int, minute: Int) throws -> Date {
            var components = calendar.dateComponents([.year, .month, .day], from: date)
            components.hour = hour
            components.minute = minute
            components.second = 0
            guard let result = calendar.date(from: components) else {
                throw MockError.invalidDateComponents
            }
            return result
        }

        return PrayerTimes(
            date: calendar.startOfDay(for: date),
            timeZone: timeZone,
            fajr: try time(hour: 5, minute: 12),
            sunrise: try time(hour: 6, minute: 48),
            dhuhr: try time(hour: 12, minute: 47),
            asr: try time(hour: 16, minute: 32),
            maghrib: try time(hour: 19, minute: 41),
            isha: try time(hour: 21, minute: 5)
        )
    }
}
