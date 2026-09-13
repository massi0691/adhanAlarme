import Foundation
import UserNotifications

/// Fabrique pure du contenu de notification (testable).
/// Chaînes pré-rendues via `localize` (locale de l'app au moment planifié,
/// identique à l'interface). Son : extrait custom (< 30 s) si fourni,
/// sinon son système.
enum PrayerAlertContentFactory {
    static func content(
        for request: PrayerAlertRequest,
        localize: (String) -> String,
        customSoundName: String?
    ) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = localize(request.prayer.titleKey)
        content.body = localize("alert.notification.body")
        switch request.mode {
        case .adhan:
            content.categoryIdentifier = PrayerAlertCategories.adhan
            content.interruptionLevel = .timeSensitive
            if let soundName = request.soundName ?? customSoundName {
                content.sound = UNNotificationSound(named: UNNotificationSoundName(soundName))
            } else {
                content.sound = .default
            }
        case .notificationOnly:
            content.interruptionLevel = .active
            content.sound = .default
        case .silent:
            // Inatteignable (filtré par le use case) : repli sûr, silencieux.
            break
        }
        content.userInfo = [
            PrayerAlertUserInfo.prayer: request.prayer.rawValue,
            PrayerAlertUserInfo.muezzinID: request.muezzinID,
            PrayerAlertUserInfo.mode: request.mode.rawValue,
            PrayerAlertUserInfo.fireDate: request.fireDate.timeIntervalSince1970,
        ]
        return content
    }
}
