import Foundation
import UserNotifications

/// Mapper pur : `PrayerAlertRequest` → `UNNotificationRequest`
/// (identifiant stable, déclencheur calendaire exact, non répété).
enum PrayerAlertRequestMapper {
    static func unRequest(
        for request: PrayerAlertRequest,
        content: UNMutableNotificationContent
    ) -> UNNotificationRequest {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = request.timeZone
        let components = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: request.fireDate
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        return UNNotificationRequest(identifier: request.identifier, content: content, trigger: trigger)
    }
}
