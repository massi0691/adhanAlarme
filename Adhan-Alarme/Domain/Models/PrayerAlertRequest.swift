import Foundation

/// Une alerte à planifier : une prière à une date/heure donnée.
/// Construit par `SchedulePrayerAlertsUseCase`, mappé vers
/// `UNNotificationRequest` (voir `PrayerAlertRequestMapper`).
struct PrayerAlertRequest: Sendable, Hashable {
    let prayer: Prayer
    let fireDate: Date
    let mode: PrayerAlertMode
    let muezzinID: String

    /// Identifiant stable (`adhan.<prière>.<AAAAMMJJ>`, jour UTC) :
    /// replanifier remplace au lieu de dupliquer. Calcul sans état
    /// partagé (sûr entre acteurs).
    var identifier: String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        let parts = calendar.dateComponents([.year, .month, .day], from: fireDate)
        let day = String(format: "%04d%02d%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
        return "adhan.\(prayer.rawValue).\(day)"
    }
}
