import Foundation

/// Identifiants stables : catégorie, action et clés `userInfo`.
/// Lus à chaud par le délégué (`PrayerAlertActionHandler`, lot F).
enum PrayerAlertCategories {
    static let adhan = "ADHAN_ALERT"
    static let listenAction = "LISTEN_ADHAN"
}

/// Clés `userInfo` (valeurs plist : String/Double uniquement).
enum PrayerAlertUserInfo {
    static let prayer = "prayer"
    static let muezzinID = "muezzinID"
    static let mode = "mode"
    static let fireDate = "fireDate"
}
