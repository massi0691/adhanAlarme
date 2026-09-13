import Foundation
import Testing
@testable import Adhan_Alarme

struct PrayerTimesTests {
    private func fixture() -> PrayerTimes {
        let base = Date(timeIntervalSince1970: 1_789_000_000)
        return PrayerTimes(
            date: base,
            timeZone: TimeZone(identifier: "Europe/Paris") ?? .current,
            fajr: base.addingTimeInterval(3_600),
            sunrise: base.addingTimeInterval(7_200),
            dhuhr: base.addingTimeInterval(10_800),
            asr: base.addingTimeInterval(14_400),
            maghrib: base.addingTimeInterval(18_000),
            isha: base.addingTimeInterval(21_600)
        )
    }

    @Test func timeForPrayer_returnsEachTime() async throws {
        let times = fixture()

        #expect(times.time(for: .fajr) == times.fajr)
        #expect(times.time(for: .sunrise) == times.sunrise)
        #expect(times.time(for: .dhuhr) == times.dhuhr)
        #expect(times.time(for: .asr) == times.asr)
        #expect(times.time(for: .maghrib) == times.maghrib)
        #expect(times.time(for: .isha) == times.isha)
    }

    @Test func orderedTimes_areChronological() async throws {
        let ordered = fixture().orderedTimes

        #expect(ordered.map { $0.prayer } == Prayer.allCases)
        let dates = ordered.map { $0.date }
        #expect(dates == dates.sorted())
    }

    @Test func timeZone_isRestoredFromIdentifier() async throws {
        #expect(fixture().timeZone.identifier == "Europe/Paris")
    }

    @Test func sunrise_isNotObligatory() async throws {
        #expect(Prayer.sunrise.isObligatory == false)
        #expect(Prayer.allCases.filter(\.isObligatory).count == 5)
    }
}

struct CoordinatesTests {
    @Test func parisCoordinates_areValid() async throws {
        #expect(Coordinates(latitude: 48.85, longitude: 2.35).isValid)
    }

    @Test func outOfRangeCoordinates_areInvalid() async throws {
        #expect(!Coordinates(latitude: 91, longitude: 0).isValid)
        #expect(!Coordinates(latitude: 0, longitude: -200).isValid)
        #expect(!Coordinates(latitude: .nan, longitude: 0).isValid)
    }
}
