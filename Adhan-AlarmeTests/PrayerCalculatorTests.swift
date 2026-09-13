import Foundation
import Testing
@testable import Adhan_Alarme

/// Tests du moteur astronomique local. Les valeurs "dorées" sont les
/// horaires réels de l'API Aladhan pour Évry le 13-09-2026 (Europe/Paris),
/// récupérés le 2026-09-13. Tolérance : ±2 minutes.
struct PrayerCalculatorTests {
    private let calculator = PrayerCalculator()
    private let paris = TimeZone(identifier: "Europe/Paris") ?? .current
    private let evry = Coordinates(latitude: 48.6298, longitude: 2.4412)

    private func calculate(
        method: CalculationMethod = .muslimWorldLeague,
        asrMethod: AsrMethod = .standard,
        highLatitudeRule: HighLatitudeRule = .middleOfNight,
        fajrAngleOverride: Double? = nil,
        ishaAngleOverride: Double? = nil,
        year: Int = 2026,
        month: Int = 9,
        day: Int = 13,
        coordinates: Coordinates? = nil,
        timeZone: TimeZone? = nil
    ) throws -> PrayerTimes {
        var configuration = PrayerCalculationConfiguration()
        configuration.method = method
        configuration.asrMethod = asrMethod
        configuration.highLatitudeRule = highLatitudeRule
        configuration.fajrAngleOverride = fajrAngleOverride
        configuration.ishaAngleOverride = ishaAngleOverride
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone ?? paris
        let date = try #require(calendar.date(from: DateComponents(year: year, month: month, day: day)))
        return try calculator.calculate(
            date: date,
            coordinates: coordinates ?? evry,
            timeZone: timeZone ?? paris,
            parameters: CalculationParameters(configuration: configuration)
        )
    }

    /// Heure attendue le 13-09-2026 à Évry (Europe/Paris).
    private func parisTime(hour: Int, minute: Int) throws -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = paris
        return try #require(calendar.date(from: DateComponents(
            year: 2026, month: 9, day: 13, hour: hour, minute: minute
        )))
    }

    private func isClose(_ actual: Date, _ expected: Date, tolerance: TimeInterval = 120) -> Bool {
        abs(actual.timeIntervalSince(expected)) <= tolerance
    }

    @Test func parisTimes_areOrdered() async throws {
        let dates = try calculate().orderedTimes.map { $0.date }
        #expect(dates == dates.sorted())
    }

    @Test func goldenMuslimWorldLeague() async throws {
        let times = try calculate()
        let fajr = try parisTime(hour: 5, minute: 34)
        let sunrise = try parisTime(hour: 7, minute: 24)
        let dhuhr = try parisTime(hour: 13, minute: 46)
        let asr = try parisTime(hour: 17, minute: 18)
        let maghrib = try parisTime(hour: 20, minute: 7)
        let isha = try parisTime(hour: 21, minute: 50)
        #expect(isClose(times.fajr, fajr))
        #expect(isClose(times.sunrise, sunrise))
        #expect(isClose(times.dhuhr, dhuhr))
        #expect(isClose(times.asr, asr))
        #expect(isClose(times.maghrib, maghrib))
        #expect(isClose(times.isha, isha))
    }

    @Test func goldenUoif() async throws {
        let times = try calculate(method: .uoif)
        let fajr = try parisTime(hour: 6, minute: 14)
        let isha = try parisTime(hour: 21, minute: 17)
        #expect(isClose(times.fajr, fajr))
        #expect(isClose(times.isha, isha))
    }

    @Test func goldenUmmAlQura() async throws {
        let times = try calculate(method: .ummAlQura)
        let fajr = try parisTime(hour: 5, minute: 31)
        let isha = try parisTime(hour: 21, minute: 37)
        #expect(isClose(times.fajr, fajr))
        #expect(isClose(times.isha, isha))
        // Intervalle fixe : 90 min après Maghrib (tolérance d'arrondi).
        #expect(abs(times.isha.timeIntervalSince(times.maghrib) - 5400) <= 60)
    }

    @Test func goldenTehranAndJafari() async throws {
        let tehran = try calculate(method: .tehran)
        let tehranFajr = try parisTime(hour: 5, minute: 37)
        let tehranMaghrib = try parisTime(hour: 20, minute: 30)
        let tehranIsha = try parisTime(hour: 21, minute: 30)
        #expect(isClose(tehran.fajr, tehranFajr))
        #expect(isClose(tehran.maghrib, tehranMaghrib))
        #expect(isClose(tehran.isha, tehranIsha))

        let jafari = try calculate(method: .jafari)
        let jafariFajr = try parisTime(hour: 5, minute: 48)
        let jafariMaghrib = try parisTime(hour: 20, minute: 27)
        #expect(isClose(jafari.fajr, jafariFajr))
        #expect(isClose(jafari.maghrib, jafariMaghrib))
    }

    @Test func goldenQatarIsha() async throws {
        let times = try calculate(method: .qatar)
        let isha = try parisTime(hour: 21, minute: 37)
        #expect(isClose(times.isha, isha))
    }

    @Test func hanafiAsr_isLaterThanStandardAsr() async throws {
        let standard = try calculate(asrMethod: .standard)
        let hanafi = try calculate(asrMethod: .hanafi)
        #expect(hanafi.asr > standard.asr)
    }

    @Test func higherFajrAngle_givesEarlierFajr() async throws {
        let mwl = try calculate(method: .muslimWorldLeague)
        let egyptian = try calculate(method: .egyptian)
        #expect(egyptian.fajr < mwl.fajr)
    }

    @Test func dhuhr_isEarlyAfternoonInParis() async throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = paris
        let hour = calendar.component(.hour, from: try calculate().dhuhr)
        #expect(hour == 13)
    }

    @Test func timeZoneAndDay_arePreserved() async throws {
        let times = try calculate()
        #expect(times.timeZone.identifier == "Europe/Paris")
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = paris
        let input = try #require(calendar.date(from: DateComponents(year: 2026, month: 9, day: 13)))
        #expect(times.date == calendar.startOfDay(for: input))
    }

    @Test func highLatitudeRules_boundTheNight() async throws {
        // Stockholm, 21-12-2026 : nuit longue. MiddleOfNight (moitié de la
        // nuit) est plus permissif que OneSeventh, dans tous les cas.
        let stockholm = Coordinates(latitude: 59.3293, longitude: 18.0686)
        let zone = TimeZone(identifier: "Europe/Stockholm") ?? paris
        let middle = try calculate(
            highLatitudeRule: .middleOfNight, year: 2026, month: 12, day: 21,
            coordinates: stockholm, timeZone: zone
        )
        let seventh = try calculate(
            highLatitudeRule: .oneSeventh, year: 2026, month: 12, day: 21,
            coordinates: stockholm, timeZone: zone
        )
        #expect(middle.fajr <= seventh.fajr)
        #expect(middle.isha >= seventh.isha)
    }

    @Test func polarNight_doesNotCrash() async throws {
        // Tromsø, 21-12-2026 : le soleil ne se lève pas. Le calcul reste fini.
        let tromso = Coordinates(latitude: 69.6496, longitude: 18.9560)
        let zone = TimeZone(identifier: "Europe/Oslo") ?? paris
        let times = try calculate(
            year: 2026, month: 12, day: 21, coordinates: tromso, timeZone: zone
        )
        #expect(times.orderedTimes.allSatisfy { $0.date.timeIntervalSince1970.isFinite })
    }

    @Test func calculation_isDeterministic() async throws {
        let first = try calculate()
        let second = try calculate()
        #expect(first == second)
    }

    @Test func customAngles_matchEquivalentMethods() async throws {
        // Un angle Fajr custom de 19,5° équivaut à la méthode égyptienne.
        let custom = try calculate(fajrAngleOverride: 19.5)
        let egyptian = try calculate(method: .egyptian)
        #expect(custom.fajr == egyptian.fajr)
    }

    @Test func invalidCoordinates_throw() async throws {
        let configuration = PrayerCalculationConfiguration()
        #expect(throws: CalculationError.invalidCoordinates) {
            try calculator.calculate(
                date: Date(),
                coordinates: Coordinates(latitude: 100, longitude: 0),
                timeZone: paris,
                parameters: CalculationParameters(configuration: configuration)
            )
        }
    }
}
