import Foundation

/// Coordonnées solaires : déclinaison (degrés) et équation du temps (heures).
struct SolarCoordinates: Sendable, Hashable {
    let declination: Double
    let equationOfTime: Double
}

/// Position du Soleil (algorithme basse précision standard, type Meeus/NOAA).
/// Mathématiques astronomiques publiques, implémentées sans dépendance.
enum SolarCalculator {
    /// Jour julien à 0h UTC pour une date calendaire.
    static func julianDay(year: Int, month: Int, day: Int) -> Double {
        var y = year
        var m = month
        if m <= 2 {
            y -= 1
            m += 12
        }
        let a = floor(Double(y) / 100)
        let b = 2 - a + floor(a / 4)
        return floor(365.25 * Double(y + 4716))
            + floor(30.6001 * Double(m + 1))
            + Double(day) + b - 1524.5
    }

    /// Déclinaison et équation du temps pour un jour julien (fractionnaire).
    static func sunPosition(julianDay: Double) -> SolarCoordinates {
        let d = julianDay - 2451545.0
        let meanAnomaly = fixAngle(357.529 + 0.98560028 * d)
        let meanLongitude = fixAngle(280.459 + 0.98564736 * d)
        let eclipticLongitude = fixAngle(
            meanLongitude + 1.915 * sind(meanAnomaly) + 0.020 * sind(2 * meanAnomaly)
        )
        let obliquity = 23.439 - 0.00000036 * d
        let rightAscension = rtd(atan2(
            cosd(obliquity) * sind(eclipticLongitude),
            cosd(eclipticLongitude)
        )) / 15
        let declination = rtd(asin(sind(obliquity) * sind(eclipticLongitude)))
        let equationOfTime = meanLongitude / 15 - fixHour(rightAscension)
        return SolarCoordinates(declination: declination, equationOfTime: equationOfTime)
    }

    // MARK: - Helpers d'angles (degrés)

    static func fixAngle(_ angle: Double) -> Double { fix(angle, 360) }
    static func fixHour(_ hour: Double) -> Double { fix(hour, 24) }

    static func sind(_ degrees: Double) -> Double { sin(degrees * .pi / 180) }
    static func cosd(_ degrees: Double) -> Double { cos(degrees * .pi / 180) }
    static func tand(_ degrees: Double) -> Double { tan(degrees * .pi / 180) }
    static func rtd(_ radians: Double) -> Double { radians * 180 / .pi }

    private static func fix(_ value: Double, _ bound: Double) -> Double {
        var result = value.truncatingRemainder(dividingBy: bound)
        if result < 0 { result += bound }
        return result
    }
}
