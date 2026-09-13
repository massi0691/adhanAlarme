import Foundation

/// Calcule les occurrences à planifier sur `days` jours (aujourd'hui + suivants).
/// Ignore le passé, les prières silencieuses/désactivées, et tout si
/// l'interrupteur global est coupé. Les réglages sont passés en capture
/// (l'appelant `@MainActor` les lit) : ce use case reste non isolé.
/// Erreur : `timesUnavailable` (horaires ou position).
struct SchedulePrayerAlertsUseCase {
    private let prayerTimes: GetPrayerTimesUseCase
    private let resolver: any ActiveLocationResolving
    /// Jours couverts (7 × 6 = 42 < 64, limite iOS).
    private let days: Int

    init(
        prayerTimes: GetPrayerTimesUseCase,
        resolver: any ActiveLocationResolving,
        days: Int = 7
    ) {
        self.prayerTimes = prayerTimes
        self.resolver = resolver
        self.days = days
    }

    func execute(now: Date = Date(), settings: AppSettings) async throws -> [PrayerAlertRequest] {
        guard settings.globalAdhanEnabled else { return [] }
        let location: ActiveLocation
        do {
            location = try await resolver.resolveActiveLocation()
        } catch {
            throw PrayerAlertError.timesUnavailable
        }
        var zoneCalendar = Calendar(identifier: .gregorian)
        zoneCalendar.timeZone = location.timeZone
        let startOfToday = zoneCalendar.startOfDay(for: now)
        var requests: [PrayerAlertRequest] = []
        requests.reserveCapacity(days * Prayer.allCases.count)
        for offset in 0..<days {
            guard let day = zoneCalendar.date(byAdding: .day, value: offset, to: startOfToday) else { continue }
            let times: PrayerTimes
            do {
                times = try await prayerTimes.execute(
                    for: day,
                    coordinates: location.coordinates,
                    timeZone: location.timeZone,
                    configuration: settings.calculation
                )
            } catch {
                throw PrayerAlertError.timesUnavailable
            }
            for prayer in Prayer.allCases {
                guard let preference = settings.prayerPreferences[prayer],
                      preference.enabled, preference.mode != .silent else { continue }
                let fireDate = times.time(for: prayer)
                guard fireDate > now else { continue }
                requests.append(PrayerAlertRequest(
                    prayer: prayer,
                    fireDate: fireDate,
                    timeZone: location.timeZone,
                    mode: preference.mode,
                    muezzinID: preference.selectedMuezzinID
                ))
            }
        }
        return requests
    }
}
