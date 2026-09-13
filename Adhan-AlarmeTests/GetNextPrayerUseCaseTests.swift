import Foundation
import Testing
@testable import Adhan_Alarme

struct GetNextPrayerUseCaseTests {
    private let useCase = GetNextPrayerUseCase()
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Paris") ?? .current
        return calendar
    }()

    private func date(on day: Date, hour: Int, minute: Int) throws -> Date {
        try #require(
            calendar.date(
                byAdding: DateComponents(hour: hour, minute: minute),
                to: calendar.startOfDay(for: day)
            )
        )
    }

    private func todayFixture() throws -> PrayerTimes {
        let day = try #require(
            calendar.date(from: DateComponents(year: 2026, month: 9, day: 13))
        )
        return PrayerTimes(
            date: calendar.startOfDay(for: day),
            timeZone: calendar.timeZone,
            fajr: try date(on: day, hour: 5, minute: 12),
            sunrise: try date(on: day, hour: 6, minute: 48),
            dhuhr: try date(on: day, hour: 12, minute: 47),
            asr: try date(on: day, hour: 16, minute: 32),
            maghrib: try date(on: day, hour: 19, minute: 41),
            isha: try date(on: day, hour: 21, minute: 5)
        )
    }

    private func tomorrowFajr(after today: PrayerTimes) throws -> Date {
        try #require(calendar.date(byAdding: .day, value: 1, to: today.fajr))
    }

    @Test func beforeFajr_returnsFajrToday() async throws {
        let today = try todayFixture()
        let now = try date(on: today.date, hour: 4, minute: 30)

        let next = useCase.resolve(now: now, today: today, tomorrowFajr: nil)

        #expect(next?.prayer == .fajr)
        #expect(next?.date == today.fajr)
        #expect(next?.isTomorrow == false)
    }

    @Test func midMorning_returnsDhuhr() async throws {
        // Exemple du cahier des charges : à 11h24, prochaine prière = Dhuhr 12h47.
        let today = try todayFixture()
        let now = try date(on: today.date, hour: 11, minute: 24)

        let next = useCase.resolve(now: now, today: today, tomorrowFajr: nil)

        #expect(next?.prayer == .dhuhr)
        #expect(next?.date == today.dhuhr)
        #expect(next?.isTomorrow == false)
    }

    @Test func sunrise_isPartOfTheSequence() async throws {
        let today = try todayFixture()
        let now = try date(on: today.date, hour: 6, minute: 0)

        let next = useCase.resolve(now: now, today: today, tomorrowFajr: nil)

        #expect(next?.prayer == .sunrise)
        #expect(next?.date == today.sunrise)
    }

    @Test func exactlyAtPrayerTime_movesToNext() async throws {
        // Comparaison stricte : l'heure exacte est considérée comme atteinte.
        let today = try todayFixture()

        let next = useCase.resolve(now: today.dhuhr, today: today, tomorrowFajr: nil)

        #expect(next?.prayer == .asr)
        #expect(next?.date == today.asr)
    }

    @Test func afterIsha_returnsTomorrowFajr() async throws {
        let today = try todayFixture()
        let fajr = try tomorrowFajr(after: today)
        let now = try date(on: today.date, hour: 22, minute: 0)

        let next = useCase.resolve(now: now, today: today, tomorrowFajr: fajr)

        #expect(next?.prayer == .fajr)
        #expect(next?.date == fajr)
        #expect(next?.isTomorrow == true)
    }

    @Test func afterIsha_withoutTomorrowData_returnsNil() async throws {
        let today = try todayFixture()
        let now = try date(on: today.date, hour: 22, minute: 0)

        let next = useCase.resolve(now: now, today: today, tomorrowFajr: nil)

        #expect(next == nil)
    }
}
