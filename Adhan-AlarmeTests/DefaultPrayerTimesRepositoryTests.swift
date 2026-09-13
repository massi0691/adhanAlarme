import Foundation
import Testing
@testable import Adhan_Alarme

/// Tests de la chaîne de fallback : cache → API → calcul local.
struct DefaultPrayerTimesRepositoryTests {
    private struct StubProvider: PrayerTimesProvider {
        enum Outcome: Sendable {
            case value(PrayerTimes)
            case failure
        }
        let outcome: Outcome

        func fetchPrayerTimes(
            date: Date,
            coordinates: Coordinates,
            timeZone: TimeZone,
            configuration: PrayerCalculationConfiguration
        ) async throws -> PrayerTimes {
            switch outcome {
            case .value(let times):
                return times
            case .failure:
                throw AladhanError.requestFailed
            }
        }
    }

    private let paris = TimeZone(identifier: "Europe/Paris") ?? .current
    private let evry = Coordinates(latitude: 48.6298, longitude: 2.4412)

    private func isolatedDefaults() throws -> UserDefaults {
        try #require(UserDefaults(suiteName: "test.\(UUID().uuidString)"))
    }

    private func sentinel(base: TimeInterval) -> PrayerTimes {
        let date = Date(timeIntervalSince1970: base)
        return PrayerTimes(
            date: date,
            timeZone: paris,
            fajr: date.addingTimeInterval(3600),
            sunrise: date.addingTimeInterval(7200),
            dhuhr: date.addingTimeInterval(10800),
            asr: date.addingTimeInterval(14400),
            maghrib: date.addingTimeInterval(18000),
            isha: date.addingTimeInterval(21600)
        )
    }

    private func day() throws -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = paris
        return try #require(calendar.date(from: DateComponents(year: 2026, month: 9, day: 13)))
    }

    @Test func apiSuccess_isCachedAndReturned() async throws {
        let cache = PrayerTimesCache(userDefaults: try isolatedDefaults())
        let apiTimes = sentinel(base: 1_789_000_000)
        let day = try day()
        let configuration = PrayerCalculationConfiguration()

        let repository = DefaultPrayerTimesRepository(
            api: StubProvider(outcome: .value(apiTimes)),
            local: StubProvider(outcome: .failure),
            cache: cache
        )
        let first = try await repository.fetchPrayerTimes(
            date: day, coordinates: evry, timeZone: paris, configuration: configuration
        )
        #expect(first == apiTimes)

        // Second dépôt, même cache, API en panne : le cache répond.
        let offline = DefaultPrayerTimesRepository(
            api: StubProvider(outcome: .failure),
            local: StubProvider(outcome: .failure),
            cache: cache
        )
        let second = try await offline.fetchPrayerTimes(
            date: day, coordinates: evry, timeZone: paris, configuration: configuration
        )
        #expect(second == apiTimes)
    }

    @Test func apiFailure_fallsBackToLocal() async throws {
        let repository = DefaultPrayerTimesRepository(
            api: StubProvider(outcome: .failure),
            local: StubProvider(outcome: .value(sentinel(base: 2_000_000_000))),
            cache: PrayerTimesCache(userDefaults: try isolatedDefaults())
        )
        let result = try await repository.fetchPrayerTimes(
            date: try day(),
            coordinates: evry,
            timeZone: paris,
            configuration: PrayerCalculationConfiguration()
        )
        #expect(result == sentinel(base: 2_000_000_000))
    }

    @Test func customAngles_bypassHealthyAPI() async throws {
        var configuration = PrayerCalculationConfiguration()
        configuration.fajrAngleOverride = 19
        let repository = DefaultPrayerTimesRepository(
            api: StubProvider(outcome: .value(sentinel(base: 1_000_000_000))),
            local: StubProvider(outcome: .value(sentinel(base: 2_000_000_000))),
            cache: PrayerTimesCache(userDefaults: try isolatedDefaults())
        )
        let result = try await repository.fetchPrayerTimes(
            date: try day(), coordinates: evry, timeZone: paris, configuration: configuration
        )
        #expect(result == sentinel(base: 2_000_000_000))
    }

    @Test func localPath_addsMethodAndManualAdjustments() async throws {
        var configuration = PrayerCalculationConfiguration()
        configuration.method = .diyanet
        configuration.manualAdjustments = [.dhuhr: 1, .fajr: 2]
        let raw = sentinel(base: 1_500_000_000)
        let repository = DefaultPrayerTimesRepository(
            api: StubProvider(outcome: .failure),
            local: StubProvider(outcome: .value(raw)),
            cache: PrayerTimesCache(userDefaults: try isolatedDefaults())
        )
        let result = try await repository.fetchPrayerTimes(
            date: try day(), coordinates: evry, timeZone: paris, configuration: configuration
        )
        // Diyanet : lever −7, dhuhr +5, asr +4, maghrib +7 ; manuels ajoutés.
        #expect(result.sunrise == raw.sunrise.addingTimeInterval(-420))
        #expect(result.dhuhr == raw.dhuhr.addingTimeInterval(360))
        #expect(result.asr == raw.asr.addingTimeInterval(240))
        #expect(result.maghrib == raw.maghrib.addingTimeInterval(420))
        #expect(result.fajr == raw.fajr.addingTimeInterval(120))
        #expect(result.isha == raw.isha)
    }

    @Test func apiPath_appliesOnlyManualAdjustments() async throws {
        // L'API inclut déjà les offsets de méthode : pas de double application.
        var configuration = PrayerCalculationConfiguration()
        configuration.method = .diyanet
        let raw = sentinel(base: 1_500_000_000)
        let repository = DefaultPrayerTimesRepository(
            api: StubProvider(outcome: .value(raw)),
            local: StubProvider(outcome: .failure),
            cache: PrayerTimesCache(userDefaults: try isolatedDefaults())
        )
        let result = try await repository.fetchPrayerTimes(
            date: try day(), coordinates: evry, timeZone: paris, configuration: configuration
        )
        #expect(result == raw)
    }
}
