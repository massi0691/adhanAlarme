import Foundation

/// Données d'exemple pour les `#Preview` SwiftUI.
enum PreviewFixtures {
    static let city = SavedCity(
        name: "Évry-Courcouronnes",
        country: "France",
        coordinates: Coordinates(latitude: 48.6298, longitude: 2.4412),
        timeZoneIdentifier: "Europe/Paris"
    )

    static func samplePrayerTimes(for date: Date = Date()) -> PrayerTimes {
        let calendar = Calendar.current

        func time(hour: Int, minute: Int) -> Date {
            let startOfDay = calendar.startOfDay(for: date)
            return calendar.date(
                byAdding: DateComponents(hour: hour, minute: minute),
                to: startOfDay
            ) ?? startOfDay
        }

        return PrayerTimes(
            date: calendar.startOfDay(for: date),
            timeZone: calendar.timeZone,
            fajr: time(hour: 5, minute: 12),
            sunrise: time(hour: 6, minute: 48),
            dhuhr: time(hour: 12, minute: 47),
            asr: time(hour: 16, minute: 32),
            maghrib: time(hour: 19, minute: 41),
            isha: time(hour: 21, minute: 5)
        )
    }
}
