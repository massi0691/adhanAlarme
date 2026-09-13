import Foundation

/// Planification des alertes système (notifications locales).
/// Volontairement séparé de la lecture audio (voir `AdhanPlaybackService`).
/// Implémentation en phase 4.
protocol PrayerAlertService: Sendable {
    func schedulePrayerAlerts(for date: Date) async throws
    func cancelAllAlerts() async
}
