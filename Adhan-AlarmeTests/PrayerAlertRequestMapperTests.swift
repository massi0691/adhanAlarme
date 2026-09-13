import Foundation
import Testing
import UserNotifications

@testable import Adhan_Alarme

/// Mapper pur : identifiant stable + déclencheur calendaire exact, non répété.
@MainActor
struct PrayerAlertRequestMapperTests {
    private static let utc = TimeZone(identifier: "UTC") ?? .current

    private func request(
        prayer: Prayer = .fajr,
        day: Int = 13,
        hour: Int = 5,
        timeZone: TimeZone? = nil
    ) -> PrayerAlertRequest {
        let zone = timeZone ?? Self.utc
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        let parts = DateComponents(year: 2026, month: 9, day: day, hour: hour)
        return PrayerAlertRequest(
            prayer: prayer,
            fireDate: calendar.date(from: parts) ?? .distantPast,
            timeZone: zone,
            mode: .adhan,
            muezzinID: "makkah"
        )
    }

    @Test func identifierIsStablePerPrayerAndUTCDay() {
        #expect(request().identifier == "adhan.fajr.20260913")
        #expect(request(prayer: .isha, hour: 21).identifier == "adhan.isha.20260913")
    }

    @Test func unRequestCarriesIdentifierAndExactTrigger() {
        let mapped = PrayerAlertRequestMapper.unRequest(
            for: request(),
            content: UNMutableNotificationContent()
        )
        #expect(mapped.identifier == "adhan.fajr.20260913")
        guard let trigger = mapped.trigger as? UNCalendarNotificationTrigger else {
            #expect(Bool(false), "déclencheur calendaire attendu")
            return
        }
        #expect(trigger.repeats == false)
        let parts = trigger.dateComponents
        #expect(parts.year == 2026 && parts.month == 9 && parts.day == 13)
        #expect(parts.hour == 5 && parts.minute == 0)
    }

    @Test func triggerRespectsLocationTimeZone() {
        // 05:00 à Paris (UTC+2, heure d'été), même jour calendaire.
        let paris = TimeZone(identifier: "Europe/Paris") ?? Self.utc
        let mapped = PrayerAlertRequestMapper.unRequest(
            for: request(timeZone: paris),
            content: UNMutableNotificationContent()
        )
        guard let trigger = mapped.trigger as? UNCalendarNotificationTrigger else {
            #expect(Bool(false), "déclencheur calendaire attendu")
            return
        }
        #expect(trigger.dateComponents.hour == 5)
        #expect(trigger.dateComponents.day == 13)
    }
}
