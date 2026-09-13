import Foundation
import Testing
@testable import Adhan_Alarme

struct CountdownFormatterTests {
    private let now = Date(timeIntervalSince1970: 1_789_000_000)

    @Test func formatsHoursMinutesSeconds() async throws {
        // 1 h 23 min 42 s = 5 022 s.
        let target = now.addingTimeInterval(5_022)

        #expect(CountdownFormatter.string(until: target, from: now) == "01:23:42")
    }

    @Test func zeroInterval_returnsZeros() async throws {
        #expect(CountdownFormatter.string(until: now, from: now) == "00:00:00")
    }

    @Test func pastTarget_isClampedToZero() async throws {
        let target = now.addingTimeInterval(-60)

        #expect(CountdownFormatter.string(until: target, from: now) == "00:00:00")
    }

    @Test func hours_areNotBoundedTo24() async throws {
        let target = now.addingTimeInterval(25 * 3600 + 5 * 60 + 9)

        #expect(CountdownFormatter.string(until: target, from: now) == "25:05:09")
    }
}
