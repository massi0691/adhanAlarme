import Foundation

/// Identifiants stables : catégorie, action et clés `userInfo`.
/// Lus à chaud par le délégué (`PrayerAlertActionHandler`, lot F).
enum PrayerAlertCategories {
    static let adhan = "ADHAN_ALERT"
    static let listenAction = "LISTEN_ADHAN"
}

/// Clés `userInfo` (valeurs plist : String/Double uniquement).
enum PrayerAlertUserInfo {
    nonisolated static let prayer = "prayer"
    nonisolated static let muezzinID = "muezzinID"
    nonisolated static let mode = "mode"
    nonisolated static let fireDate = "fireDate"
}
