import Foundation

/// Récupère les horaires d'une journée via le dépôt.
/// Garde la couche Présentation découplée de la source de données.
struct GetPrayerTimesUseCase: Sendable {
    private let repository: any PrayerTimesRepository

    init(repository: any PrayerTimesRepository) {
        self.repository = repository
    }

    func execute(for date: Date) async throws -> PrayerTimes {
        try await repository.prayerTimes(for: date)
    }
}
