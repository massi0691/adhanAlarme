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
        var components = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: request.fireDate
        )
        // Fuseau explicite : le déclencheur reste déterministe même si
        // l'appareil voyage entre la planification et l'échéance.
        components.calendar = calendar
        components.timeZone = request.timeZone
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        return UNNotificationRequest(identifier: request.identifier, content: content, trigger: trigger)
    }
}
