import Foundation

enum CalculationError: Error, Sendable, Hashable {
    case invalidCoordinates
    case dateConstructionFailed
}

/// Calcul astronomique local des horaires (aucun réseau, fonctionne hors-ligne).
/// Algorithme classique (type PrayTimes) : position solaire évaluée au fil de
/// la journée avec raffinement en deux passes, angles par méthode, Asr par
/// facteur d'ombre, ajustements haute latitude. Résultats arrondis à la minute.
struct PrayerCalculator: Sendable {
    /// Angle standard du lever/coucher du soleil (réfraction + demi-diamètre).
    private static let riseSetAngle = 0.833
    private static let passes = 2

    func calculate(
        date: Date,
        coordinates: Coordinates,
        timeZone: TimeZone,
        parameters: CalculationParameters
    ) throws -> PrayerTimes {
        guard coordinates.isValid else { throw CalculationError.invalidCoordinates }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let startOfDay = calendar.startOfDay(for: date)
        let parts = calendar.dateComponents([.year, .month, .day], from: startOfDay)
        guard let year = parts.year, let month = parts.month, let day = parts.day else {
            throw CalculationError.dateConstructionFailed
        }

        // Jour julien du minuit local (UTC décalé de la longitude).
        let julianDay = SolarCalculator.julianDay(year: year, month: month, day: day)
            - coordinates.longitude / 360

        // Estimations initiales (heures), raffinées à chaque passe.
        var fajr = 5.0
        var sunrise = 6.0
        var dhuhr = 12.0
        var asr = 13.0
        var sunset = 18.0
        var maghrib = 18.0
        var isha = 18.0

        for _ in 0..<Self.passes {
            dhuhr = midDay(julianDay: julianDay, fraction: dhuhr / 24)
            sunrise = sunAngleTime(
                angle: Self.riseSetAngle, julianDay: julianDay,
                latitude: coordinates.latitude, fraction: sunrise / 24, afterNoon: false
            )
            sunset = sunAngleTime(
                angle: Self.riseSetAngle, julianDay: julianDay,
                latitude: coordinates.latitude, fraction: sunset / 24, afterNoon: true
            )
            fajr = sunAngleTime(
                angle: parameters.fajrAngle, julianDay: julianDay,
                latitude: coordinates.latitude, fraction: fajr / 24, afterNoon: false
            )
            asr = asrTime(
                factor: parameters.asrShadowFactor, julianDay: julianDay,
                latitude: coordinates.latitude, fraction: asr / 24
            )
            switch parameters.maghrib {
            case .sunset:
                maghrib = sunset
            case .angle(let maghribAngle):
                maghrib = sunAngleTime(
                    angle: maghribAngle, julianDay: julianDay,
                    latitude: coordinates.latitude, fraction: maghrib / 24, afterNoon: true
                )
            }
            switch parameters.isha {
            case .angle(let ishaAngle):
                isha = sunAngleTime(
                    angle: ishaAngle, julianDay: julianDay,
                    latitude: coordinates.latitude, fraction: isha / 24, afterNoon: true
                )
            case .minutesAfterMaghrib(let minutes):
                isha = maghrib + minutes / 60
            }
        }

        adjustHighLatitudeTimes(
            fajr: &fajr, sunrise: sunrise,
            maghrib: &maghrib, isha: &isha, sunset: sunset,
            parameters: parameters
        )

        func date(at hour: Double) throws -> Date {
            // Arrondi à la minute ; le dépassement de minuit est géré par le calendrier.
            let totalMinutes = Int((SolarCalculator.fixHour(hour) * 60).rounded())
            guard let result = calendar.date(byAdding: .minute, value: totalMinutes, to: startOfDay) else {
                throw CalculationError.dateConstructionFailed
            }
            return result
        }

        return PrayerTimes(
            date: startOfDay,
            timeZone: timeZone,
            fajr: try date(at: fajr),
            sunrise: try date(at: sunrise),
            dhuhr: try date(at: dhuhr),
            asr: try date(at: asr),
            maghrib: try date(at: maghrib),
            isha: try date(at: isha)
        )
    }

    // MARK: - Formules

    /// Midi solaire (transit). Aucune minute ajoutée : le Dhuhr publié est le
    /// transit exact, arrondi à la minute (les méthodes ajoutent leurs
    /// ajustements officiels ensuite, ex. Diyanet +5).
    private func midDay(julianDay: Double, fraction: Double) -> Double {
        let equation = SolarCalculator.sunPosition(julianDay: julianDay + fraction).equationOfTime
        return SolarCalculator.fixHour(12 - equation)
    }

    private func sunDeclination(julianDay: Double, fraction: Double) -> Double {
        SolarCalculator.sunPosition(julianDay: julianDay + fraction).declination
    }

    private func sunAngleTime(
        angle: Double,
        julianDay: Double,
        latitude: Double,
        fraction: Double,
        afterNoon: Bool
    ) -> Double {
        let declination = sunDeclination(julianDay: julianDay, fraction: fraction)
        let noon = midDay(julianDay: julianDay, fraction: fraction)
        let numerator = -SolarCalculator.sind(angle)
            - SolarCalculator.sind(declination) * SolarCalculator.sind(latitude)
        let denominator = SolarCalculator.cosd(declination) * SolarCalculator.cosd(latitude)
        // Borné pour les régions polaires (soleil ne se levant/couchant pas).
        let term = min(1, max(-1, numerator / denominator))
        let time = SolarCalculator.rtd(acos(term)) / 15
        return noon + (afterNoon ? time : -time)
    }

    private func asrTime(
        factor: Double,
        julianDay: Double,
        latitude: Double,
        fraction: Double
    ) -> Double {
        let declination = sunDeclination(julianDay: julianDay, fraction: fraction)
        let angle = -SolarCalculator.rtd(atan(
            1 / (factor + SolarCalculator.tand(abs(latitude - declination)))
        ))
        return sunAngleTime(
            angle: angle, julianDay: julianDay,
            latitude: latitude, fraction: fraction, afterNoon: true
        )
    }

    /// Ajustements haute latitude (type PrayTimes) : Fajr borné par le lever
    /// du soleil, Isha et Maghrib (angulaires) bornés par le coucher.
    /// Une Isha à intervalle fixe (Umm al-Qura, Qatar) n'est pas ajustée.
    private func adjustHighLatitudeTimes(
        fajr: inout Double,
        sunrise: Double,
        maghrib: inout Double,
        isha: inout Double,
        sunset: Double,
        parameters: CalculationParameters
    ) {
        let night = SolarCalculator.fixHour(sunrise - sunset)

        let fajrLimit = nightPortion(angle: parameters.fajrAngle, rule: parameters.highLatitudeRule) * night
        if fajr.isNaN || SolarCalculator.fixHour(sunrise - fajr) > fajrLimit {
            fajr = sunrise - fajrLimit
        }

        if case .angle(let maghribAngle) = parameters.maghrib {
            let maghribLimit = nightPortion(angle: maghribAngle, rule: parameters.highLatitudeRule) * night
            if maghrib.isNaN || SolarCalculator.fixHour(maghrib - sunset) > maghribLimit {
                maghrib = sunset + maghribLimit
            }
        }

        if case .angle(let ishaAngle) = parameters.isha {
            let ishaLimit = nightPortion(angle: ishaAngle, rule: parameters.highLatitudeRule) * night
            if isha.isNaN || SolarCalculator.fixHour(isha - sunset) > ishaLimit {
                isha = sunset + ishaLimit
            }
        }
    }

    private func nightPortion(angle: Double, rule: HighLatitudeRule) -> Double {
        switch rule {
        case .middleOfNight: 1 / 2
        case .oneSeventh: 1 / 7
        case .angleBased: angle / 60
        }
    }
}
