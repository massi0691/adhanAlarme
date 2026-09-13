import Foundation

/// Mode d'alerte pour une prière donnée.
enum PrayerAlertMode: String, Sendable, Codable, CaseIterable, Hashable {
    /// Notification système (+ lecture de l'Adhan quand l'app est active).
    case adhan
    /// Notification visuelle/sonore courte, sans lecture Adhan.
    case notificationOnly
    /// Aucune alerte.
    case silent
}

extension PrayerAlertMode {
    /// Clé localisée du libellé affiché dans Réglages.
    var labelKey: String {
        switch self {
        case .adhan: return "settings.alerts.mode.adhan"
        case .notificationOnly: return "settings.alerts.mode.notification"
        case .silent: return "settings.alerts.mode.silent"
        }
    }
}
