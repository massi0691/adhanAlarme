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
