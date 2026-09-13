import Foundation

/// Point d'entrée unique vers les horaires.
/// Phase 1 : dépôt simulé. Phase 2 : chaîne de fallback
/// (API → cache local → calcul local).
protocol PrayerTimesRepository: Sendable {
    func prayerTimes(for date: Date) async throws -> PrayerTimes
}
