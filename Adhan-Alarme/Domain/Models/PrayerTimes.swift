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

    /// Décale chaque prière de son ajustement (minutes). Appliqué une seule
    /// fois par le dépôt, après récupération (API, cache ou calcul local).
    func applyingAdjustments(_ adjustments: [Prayer: Int]) -> PrayerTimes {
        func shifted(_ date: Date, for prayer: Prayer) -> Date {
            guard let minutes = adjustments[prayer], minutes != 0 else { return date }
            return date.addingTimeInterval(TimeInterval(minutes * 60))
        }
        return PrayerTimes(
            date: date,
            timeZone: timeZone,
            fajr: shifted(fajr, for: .fajr),
            sunrise: shifted(sunrise, for: .sunrise),
            dhuhr: shifted(dhuhr, for: .dhuhr),
            asr: shifted(asr, for: .asr),
            maghrib: shifted(maghrib, for: .maghrib),
            isha: shifted(isha, for: .isha)
        )
    }
}
