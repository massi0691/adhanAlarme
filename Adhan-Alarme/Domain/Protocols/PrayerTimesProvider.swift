import Foundation

/// Fournisseur d'horaires de prière (API externe, calcul local, mosquée…).
/// Les implémentations arrivent en phase 2.
protocol PrayerTimesProvider: Sendable {
    func fetchPrayerTimes(
        date: Date,
        coordinates: Coordinates,
        configuration: PrayerCalculationConfiguration
    ) async throws -> PrayerTimes
}
