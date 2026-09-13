import Foundation
import Testing
@testable import Adhan_Alarme

struct PrayerTimesCacheTests {
    private let paris = TimeZone(identifier: "Europe/Paris") ?? .current
    private let evry = Coordinates(latitude: 48.6298, longitude: 2.4412)

    private func cache() throws -> PrayerTimesCache {
        PrayerTimesCache(userDefaults: try #require(UserDefaults(suiteName: "test.\(UUID().uuidString)")))
    }

    private func times() -> PrayerTimes {
        let base = Date(timeIntervalSince1970: 1_789_000_000)
        return PrayerTimes(
            date: base,
            timeZone: paris,
            fajr: base.addingTimeInterval(3600),
            sunrise: base.addingTimeInterval(7200),
            dhuhr: base.addingTimeInterval(10800),
            asr: base.addingTimeInterval(14400),
            maghrib: base.addingTimeInterval(18000),
            isha: base.addingTimeInterval(21600)
        )
    }

    private func day(_ day: Int) throws -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = paris
        return try #require(calendar.date(from: DateComponents(year: 2026, month: 1, day: day)))
    }

    @Test func missOnEmptyCache() async throws {
        let cache = try cache()
        let configuration = PrayerCalculationConfiguration()
        #expect(cache.cached(date: try day(13), coordinates: evry, timeZone: paris, configuration: configuration) == nil)
    }

    @Test func storeThenHit() async throws {
        let cache = try cache()
        let configuration = PrayerCalculationConfiguration()
        let day = try day(13)
        cache.store(times(), date: day, coordinates: evry, timeZone: paris, configuration: configuration)
        #expect(cache.cached(date: day, coordinates: evry, timeZone: paris, configuration: configuration) == times())
    }

    @Test func configurationChange_misses() async throws {
        let cache = try cache()
        let day = try day(13)
        cache.store(times(), date: day, coordinates: evry, timeZone: paris, configuration: PrayerCalculationConfiguration())

        var diyanet = PrayerCalculationConfiguration()
        diyanet.method = .diyanet
        #expect(cache.cached(date: day, coordinates: evry, timeZone: paris, configuration: diyanet) == nil)

        var adjusted = PrayerCalculationConfiguration()
        adjusted.manualAdjustments = [.fajr: 2]
        #expect(cache.cached(date: day, coordinates: evry, timeZone: paris, configuration: adjusted) == nil)
    }

    @Test func differentDay_misses() async throws {
        let cache = try cache()
        let configuration = PrayerCalculationConfiguration()
        cache.store(times(), date: try day(13), coordinates: evry, timeZone: paris, configuration: configuration)
        #expect(cache.cached(date: try day(14), coordinates: evry, timeZone: paris, configuration: configuration) == nil)
    }

    @Test func beyondCapacity_evictsOldest() async throws {
        let cache = try cache()
        let configuration = PrayerCalculationConfiguration()
        for dayNumber in 1...31 {
            cache.store(times(), date: try day(dayNumber), coordinates: evry, timeZone: paris, configuration: configuration)
        }
        #expect(cache.cached(date: try day(1), coordinates: evry, timeZone: paris, configuration: configuration) == nil)
        #expect(cache.cached(date: try day(31), coordinates: evry, timeZone: paris, configuration: configuration) != nil)
    }
}
