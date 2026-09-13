import Foundation
import Testing
import UserNotifications

@testable import Adhan_Alarme

/// Fabrique pure : titres pré-rendus, catégorie, niveau, son, `userInfo`.
@MainActor
struct PrayerAlertContentFactoryTests {
    private static let utc = TimeZone(identifier: "UTC") ?? .current

    private func request(mode: PrayerAlertMode) -> PrayerAlertRequest {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = Self.utc
        let parts = DateComponents(year: 2026, month: 9, day: 13, hour: 5)
        return PrayerAlertRequest(
            prayer: .fajr,
            fireDate: calendar.date(from: parts) ?? .distantPast,
            timeZone: Self.utc,
            mode: mode,
            muezzinID: "makkah"
        )
    }

    private static func localize(_ key: String) -> String {
        "<\(key)>"
    }

    @Test func adhanModeSetsCategoryTimeSensitiveAndCustomSound() {
        let content = PrayerAlertContentFactory.content(
            for: request(mode: .adhan),
            localize: Self.localize,
            customSoundName: "adhan-short.caf"
        )
        #expect(content.title == "<prayer.fajr>")
        #expect(content.body == "<alert.notification.body>")
        #expect(content.categoryIdentifier == PrayerAlertCategories.adhan)
        #expect(content.interruptionLevel == .timeSensitive)
        #expect(content.sound != nil)
        #expect(content.userInfo[PrayerAlertUserInfo.prayer] as? String == "fajr")
        #expect(content.userInfo[PrayerAlertUserInfo.muezzinID] as? String == "makkah")
        #expect(content.userInfo[PrayerAlertUserInfo.mode] as? String == "adhan")
        #expect(content.userInfo[PrayerAlertUserInfo.fireDate] as? Double != nil)
    }

    @Test func notificationOnlyUsesDefaultSoundAndActiveLevel() {
        let content = PrayerAlertContentFactory.content(
            for: request(mode: .notificationOnly),
            localize: Self.localize,
            customSoundName: "adhan-short.caf"
        )
        #expect(content.categoryIdentifier == "")
        #expect(content.interruptionLevel == .active)
        #expect(content.sound != nil)
    }

    @Test func silentFallsBackToQuietContent() {
        let content = PrayerAlertContentFactory.content(
            for: request(mode: .silent),
            localize: Self.localize,
            customSoundName: nil
        )
        #expect(content.sound == nil)
        #expect(content.userInfo[PrayerAlertUserInfo.prayer] as? String == "fajr")
    }
}
