import Foundation

/// Point d'entrée unique vers les horaires.
/// Chaîne de fallback : cache → API → calcul local (voir
/// `DefaultPrayerTimesRepository` pour la politique exacte).
/// Non `Sendable` par choix : le dépôt détient des magasins MainActor et
/// tout le flux de données est sérialisé sur le MainActor (isolation par
/// défaut du projet) — voir `docs/ARCHITECTURE.md`.
protocol PrayerTimesRepository {
    func fetchPrayerTimes(
        date: Date,
        coordinates: Coordinates,
        timeZone: TimeZone,
        configuration: PrayerCalculationConfiguration
    ) async throws -> PrayerTimes
}
