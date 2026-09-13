import Foundation

/// Fournisseur de calcul local (moteur astronomique embarqué).
/// Toujours disponible, même hors-ligne.
struct LocalCalculationProvider: PrayerTimesProvider {
    private let calculator = PrayerCalculator()

    func fetchPrayerTimes(
        date: Date,
        coordinates: Coordinates,
        timeZone: TimeZone,
        configuration: PrayerCalculationConfiguration
    ) async throws -> PrayerTimes {
        try calculator.calculate(
            date: date,
            coordinates: coordinates,
            timeZone: timeZone,
            parameters: CalculationParameters(configuration: configuration)
        )
    }
}
