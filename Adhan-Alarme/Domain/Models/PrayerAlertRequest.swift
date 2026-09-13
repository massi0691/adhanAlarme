import Foundation

/// Une alerte à planifier : une prière à une date/heure donnée.
/// Construit par `SchedulePrayerAlertsUseCase`, mappé vers
/// `UNNotificationRequest` (voir `PrayerAlertRequestMapper`).
/// Adhan long (hack opt-in) : `segmentIndex` non-`nil` = un des
/// segments chaînés, avec son propre son et identifiant.
struct PrayerAlertRequest: Sendable, Hashable {
    let prayer: Prayer
    let fireDate: Date
    /// Fuseau du lieu (déclencheur calendaire exact).
    let timeZone: TimeZone
    let mode: PrayerAlertMode
    let muezzinID: String
    /// Son propre (segment d'Adhan long) ; `nil` = résolution globale.
    let soundName: String?
    /// Index du segment (Adhan long) ; `nil` = notification unique.
    let segmentIndex: Int?

    init(
        prayer: Prayer,
        fireDate: Date,
        timeZone: TimeZone,
        mode: PrayerAlertMode,
        muezzinID: String,
        soundName: String? = nil,
        segmentIndex: Int? = nil
    ) {
        self.prayer = prayer
        self.fireDate = fireDate
        self.timeZone = timeZone
        self.mode = mode
        self.muezzinID = muezzinID
        self.soundName = soundName
        self.segmentIndex = segmentIndex
    }

    /// Identifiant stable : `adhan.<prière>.<AAAAMMJJ>` (jour UTC),
    /// suffixé `.s<k>` pour les segments. Replanifier remplace au
    /// lieu de dupliquer. Calcul sans état partagé (sûr entre acteurs).
    var identifier: String {
        let base = Self.dayIdentifier(prayer: prayer, fireDate: fireDate)
        if let segmentIndex {
            return "\(base).s\(segmentIndex)"
        }
        return base
    }

    /// `adhan.<prière>.<AAAAMMJJ>` (jour UTC) : partagé avec le délégué
    /// (annulation des segments restants à l'ouverture de l'app).
    static func dayIdentifier(prayer: Prayer, fireDate: Date) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        let parts = calendar.dateComponents([.year, .month, .day], from: fireDate)
        let day = String(format: "%04d%02d%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
        return "adhan.\(prayer.rawValue).\(day)"
    }
}
