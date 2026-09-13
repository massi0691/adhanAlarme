import Foundation

/// Récupère les horaires via le dépôt (cache → API → calcul local).
/// Garde la couche Présentation découplée de la source de données.
struct GetPrayerTimesUseCase {
    private let repository: any PrayerTimesRepository

    init(repository: any PrayerTimesRepository) {
        self.repository = repository
    }

    func execute(
        for date: Date,
        coordinates: Coordinates,
        timeZone: TimeZone,
        configuration: PrayerCalculationConfiguration
    ) async throws -> PrayerTimes {
        try await repository.fetchPrayerTimes(
            date: date,
            coordinates: coordinates,
            timeZone: timeZone,
            configuration: configuration
        )
    }
}
