import Foundation
import Testing

@testable import Adhan_Alarme

/// Planification glissante : fenêtre, passé, silences, erreurs.
/// Horloge figée (UTC) + dépôt fixe (05/07/13/16/19/21 UTC).
@MainActor
struct SchedulePrayerAlertsUseCaseTests {
    private static let utc = TimeZone(identifier: "UTC") ?? .current

    private static func utcDate(day: Int, hour: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = utc
        let parts = DateComponents(year: 2026, month: 9, day: day, hour: hour)
        return calendar.date(from: parts) ?? .distantPast
    }

    /// Dépôt fixe : 6 horaires à heures UTC fixes chaque jour.
    private struct FixedRepository: PrayerTimesRepository {
        func fetchPrayerTimes(
            date: Date,
            coordinates: Coordinates,
            timeZone: TimeZone,
            configuration: PrayerCalculationConfiguration
        ) async throws -> PrayerTimes {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = timeZone
            let start = calendar.startOfDay(for: date)
            func at(_ hour: Int) -> Date {
                start.addingTimeInterval(Double(hour * 3600))
            }
            return PrayerTimes(
                date: start,
                timeZone: timeZone,
                fajr: at(5),
                sunrise: at(7),
                dhuhr: at(13),
                asr: at(16),
                maghrib: at(19),
                isha: at(21)
            )
        }
    }

    private struct FixedResolver: ActiveLocationResolving {
        func resolveActiveLocation() async throws -> ActiveLocation {
            ActiveLocation(
                coordinates: Coordinates(latitude: 48.85, longitude: 2.35),
                displayName: "Test",
                timeZone: TimeZone(identifier: "UTC") ?? .current
            )
        }
    }

    private struct Boom: Error {}

    private struct ThrowingRepository: PrayerTimesRepository {
        func fetchPrayerTimes(
            date: Date,
            coordinates: Coordinates,
            timeZone: TimeZone,
            configuration: PrayerCalculationConfiguration
        ) async throws -> PrayerTimes {
            throw Boom()
        }
    }

    private struct ThrowingResolver: ActiveLocationResolving {
        func resolveActiveLocation() async throws -> ActiveLocation {
            throw Boom()
        }
    }

    /// Segments factices : `nil` = non préparés (repli notification unique).
    private struct StubSegments: AdhanSegmentStore {
        var names: [String]?
        func segmentSoundNames(for muezzinID: String) -> [String]? { names }
        func prepareSegments(for muezzin: Muezzin, sourceURL: URL) async throws -> [String] { names ?? [] }
    }

    private func useCase(
        repository: any PrayerTimesRepository = FixedRepository(),
        resolver: any ActiveLocationResolving = FixedResolver(),
        segments: StubSegments = StubSegments(),
        days: Int = 7
    ) -> SchedulePrayerAlertsUseCase {
        SchedulePrayerAlertsUseCase(
            prayerTimes: GetPrayerTimesUseCase(repository: repository),
            resolver: resolver,
            segments: segments,
            days: days
        )
    }

    @Test func globalSwitchOffReturnsEmptyWithoutFetching() async throws {
        var settings = AppSettings.default
        settings.globalAdhanEnabled = false
        let requests = try await useCase(
            repository: ThrowingRepository(),
            resolver: ThrowingResolver()
        ).execute(now: Self.utcDate(day: 13, hour: 10), settings: settings)
        #expect(requests.isEmpty)
    }

    @Test func coversSevenDaysSkippingPast() async throws {
        let now = Self.utcDate(day: 13, hour: 10)
        let requests = try await useCase().execute(now: now, settings: AppSettings.default)
        // Aujourd'hui : 4 restantes (13/16/19/21) + 6 jours × 6.
        #expect(requests.count == 40)
        #expect(requests.allSatisfy { $0.fireDate > now })
        #expect(requests.first?.prayer == .dhuhr)
        #expect(requests.first?.fireDate == Self.utcDate(day: 13, hour: 13))
        #expect(requests.last?.prayer == .isha)
        #expect(requests.last?.fireDate == Self.utcDate(day: 19, hour: 21))
    }

    @Test func skipsSilentAndDisabled() async throws {
        var settings = AppSettings.default
        settings.prayerPreferences[.fajr]?.mode = .silent
        settings.prayerPreferences[.dhuhr]?.enabled = false
        let requests = try await useCase().execute(now: Self.utcDate(day: 13, hour: 10), settings: settings)
        #expect(requests.count == 27)
        #expect(!requests.contains { $0.prayer == .fajr || $0.prayer == .dhuhr })
    }

    @Test func locationFailureThrowsTimesUnavailable() async {
        await #expect(throws: PrayerAlertError.timesUnavailable) {
            try await self.useCase(resolver: ThrowingResolver()).execute(
                now: Self.utcDate(day: 13, hour: 10),
                settings: AppSettings.default
            )
        }
    }

    @Test func timesFailureThrowsTimesUnavailable() async {
        await #expect(throws: PrayerAlertError.timesUnavailable) {
            try await self.useCase(repository: ThrowingRepository()).execute(
                now: Self.utcDate(day: 13, hour: 10),
                settings: AppSettings.default
            )
        }
    }

    @Test func customDayWindow() async throws {
        let requests = try await useCase(days: 2).execute(
            now: Self.utcDate(day: 13, hour: 10),
            settings: AppSettings.default
        )
        #expect(requests.count == 10)
    }
}
