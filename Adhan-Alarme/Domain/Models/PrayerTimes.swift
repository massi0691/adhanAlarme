import Foundation

/// Horaires d'une journée de prière dans un fuseau horaire donné.
struct PrayerTimes: Sendable, Codable, Hashable {
    /// Jour concerné (début du jour dans `timeZone`).
    let date: Date
    /// Identifiant IANA du fuseau (ex. "Europe/Paris").
    /// Stocké plutôt que `TimeZone` pour un `Codable` robuste.
    let timeZoneIdentifier: String
    let fajr: Date
    let sunrise: Date
    let dhuhr: Date
    let asr: Date
    let maghrib: Date
    let isha: Date

    init(
        date: Date,
        timeZone: TimeZone,
        fajr: Date,
        sunrise: Date,
        dhuhr: Date,
        asr: Date,
        maghrib: Date,
        isha: Date
    ) {
        self.date = date
        self.timeZoneIdentifier = timeZone.identifier
        self.fajr = fajr
        self.sunrise = sunrise
        self.dhuhr = dhuhr
        self.asr = asr
        self.maghrib = maghrib
        self.isha = isha
    }

    var timeZone: TimeZone {
        TimeZone(identifier: timeZoneIdentifier) ?? .current
    }

    func time(for prayer: Prayer) -> Date {
        switch prayer {
        case .fajr: fajr
        case .sunrise: sunrise
        case .dhuhr: dhuhr
        case .asr: asr
        case .maghrib: maghrib
        case .isha: isha
        }
    }

    /// Horaires triés dans l'ordre chronologique de la journée.
    var orderedTimes: [(prayer: Prayer, date: Date)] {
        Prayer.allCases.map { ($0, time(for: $0)) }
    }
}
