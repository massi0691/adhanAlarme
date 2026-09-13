import Foundation

/// Dépôt composite : cache → API → calcul local.
///
/// Politique :
/// - Le cache passe en premier : les horaires sont déterministes
///   (jour + lieu + méthode), une entrée n'est jamais périmée.
/// - L'API est contournée quand des angles personnalisés sont définis
///   (elle ne les prend pas en charge) : le calcul local garantit alors
///   des résultats cohérents en ligne comme hors-ligne.
/// - Seuls les succès API sont mis en cache (jamais le calcul local),
///   afin de préférer l'API dès qu'elle redevient disponible.
/// - Ajustements : l'API inclut déjà les offsets officiels des méthodes
///   (vérifié : Diyanet), on n'y ajoute que les ajustements manuels ;
///   le calcul local reçoit offsets de méthode + manuels (additionnés).
struct DefaultPrayerTimesRepository: PrayerTimesRepository {
    private let api: any PrayerTimesProvider
    private let local: any PrayerTimesProvider
    private let cache: PrayerTimesCache

    init(api: any PrayerTimesProvider, local: any PrayerTimesProvider, cache: PrayerTimesCache) {
        self.api = api
        self.local = local
        self.cache = cache
    }

    func fetchPrayerTimes(
        date: Date,
        coordinates: Coordinates,
        timeZone: TimeZone,
        configuration: PrayerCalculationConfiguration
    ) async throws -> PrayerTimes {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let day = calendar.startOfDay(for: date)

        if let cached = cache.cached(date: day, coordinates: coordinates, timeZone: timeZone, configuration: configuration) {
            return cached.applyingAdjustments(configuration.manualAdjustments)
        }

        let hasCustomAngles = configuration.fajrAngleOverride != nil || configuration.ishaAngleOverride != nil
        if !hasCustomAngles {
            do {
                let times = try await api.fetchPrayerTimes(
                    date: day,
                    coordinates: coordinates,
                    timeZone: timeZone,
                    configuration: configuration
                )
                cache.store(times, date: day, coordinates: coordinates, timeZone: timeZone, configuration: configuration)
                return times.applyingAdjustments(configuration.manualAdjustments)
            } catch {
                // Repli sur le calcul local ci-dessous.
            }
        }

        let times = try await local.fetchPrayerTimes(
            date: day,
            coordinates: coordinates,
            timeZone: timeZone,
            configuration: configuration
        )
        let methodAdjustments = configuration.method.defaultPrayerParameters.adjustments
        return times.applyingAdjustments(mergedAdjustments(method: methodAdjustments, manual: configuration.manualAdjustments))
    }

    private func mergedAdjustments(method: [Prayer: Int], manual: [Prayer: Int]) -> [Prayer: Int] {
        method.merging(manual) { $0 + $1 }
    }
}
