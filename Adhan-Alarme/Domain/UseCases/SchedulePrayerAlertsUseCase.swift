import Foundation

/// Calcule les occurrences à planifier sur `days` jours (aujourd'hui + suivants).
/// Ignore le passé, les prières silencieuses/désactivées, et tout si
/// l'interrupteur global est coupé. Adhan long (opt-in) : les occurrences
/// en mode Adhan sont expansées en segments chaînés (requêtes à +30 s,
/// identifiants suffixés) ; sans segments prêts, repli sur une notification
/// unique. Les réglages sont passés en capture (l'appelant `@MainActor`
/// les lit). Erreur : `timesUnavailable` (horaires ou position).
struct SchedulePrayerAlertsUseCase {
    /// Espacement des segments chaînés (doit égaler la durée des segments
    /// découpés, elle-même bornée par la limite iOS de 30 s par son).
    private static let segmentSpacing: TimeInterval = 30

    private let prayerTimes: GetPrayerTimesUseCase
    private let resolver: any ActiveLocationResolving
    private let segments: any AdhanSegmentStore
    /// Jours couverts (7 × 6 = 42 < 64, limite iOS — hors Adhan long,
    /// où le service garde les 64 premières, soit ~1 jour).
    private let days: Int

    init(
        prayerTimes: GetPrayerTimesUseCase,
        resolver: any ActiveLocationResolving,
        segments: any AdhanSegmentStore,
        days: Int = 7
    ) {
        self.prayerTimes = prayerTimes
        self.resolver = resolver
        self.segments = segments
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
                    timeZone: timeZone,
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
                appendRequests(
                    for: prayer,
                    fireDate: fireDate,
                    timeZone: location.timeZone,
                    preference: preference,
                    settings: settings,
                    to: &requests
                )
            }
        }
        return requests
    }

    private func appendRequests(
        for prayer: Prayer,
        fireDate: Date,
        timeZone: TimeZone,
        preference: PrayerNotificationPreference,
        settings: AppSettings,
        to requests: inout [PrayerAlertRequest]
    ) {
        if settings.longAdhanEnabled,
           preference.mode == .adhan,
           let sounds = segments.segmentSoundNames(for: preference.selectedMuezzinID),
           !sounds.isEmpty {
            for (index, sound) in sounds.enumerated() {
                requests.append(PrayerAlertRequest(
                    prayer: prayer,
                    fireDate: fireDate.addingTimeInterval(Double(index) * Self.segmentSpacing),
                    timeZone: timeZone,
                    mode: preference.mode,
                    muezzinID: preference.selectedMuezzinID,
                    soundName: sound,
                    segmentIndex: index
                ))
            }
        } else {
            requests.append(PrayerAlertRequest(
                prayer: prayer,
                fireDate: fireDate,
                timeZone: timeZone,
                mode: preference.mode,
                muezzinID: preference.selectedMuezzinID
            ))
        }
    }
}
