import Foundation
import Observation

/// Journée affichée : horaires + prochaine échéance.
struct PrayerDay: Sendable, Equatable {
    let times: PrayerTimes
    let next: NextPrayer?
}

/// État de l'écran d'accueil.
enum HomeViewState: Sendable, Equatable {
    case loading
    case loaded(PrayerDay)
    case failed
}

/// ViewModel de l'écran d'accueil.
/// Résout la position active (GPS ou ville), puis charge les horaires
/// via le dépôt (cache → API → calcul local).
@Observable
@MainActor
final class HomeViewModel {
    private let getPrayerTimes: GetPrayerTimesUseCase
    private let getNextPrayer = GetNextPrayerUseCase()
    private let settingsStore: any SettingsStoring
    private let resolver: any ActiveLocationResolving
    private let calendar: Calendar

    private(set) var state: HomeViewState = .loading
    private(set) var cityName: String = ""
    private(set) var adhanEnabled: Bool = true
    private var isLoading = false

    init(
        getPrayerTimes: GetPrayerTimesUseCase,
        settingsStore: any SettingsStoring,
        resolver: any ActiveLocationResolving,
        calendar: Calendar = .current
    ) {
        self.getPrayerTimes = getPrayerTimes
        self.settingsStore = settingsStore
        self.resolver = resolver
        self.calendar = calendar
        self.adhanEnabled = settingsStore.settings.globalAdhanEnabled
    }

    /// Charge les horaires du jour (et le Fajr du lendemain pour le
    /// compte à rebours après Isha). Protégé contre les appels concurrents.
    func load() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        state = .loading
        do {
            let now = Date()
            let location = try await resolver.resolveActiveLocation()
            let configuration = settingsStore.settings.calculation
            let today = try await getPrayerTimes.execute(
                for: now,
                coordinates: location.coordinates,
                timeZone: location.timeZone,
                configuration: configuration
            )
            var tomorrowFajr: Date?
            var zoneCalendar = Calendar(identifier: .gregorian)
            zoneCalendar.timeZone = location.timeZone
            if let tomorrow = zoneCalendar.date(byAdding: .day, value: 1, to: now),
               let times = try? await getPrayerTimes.execute(
                   for: tomorrow,
                   coordinates: location.coordinates,
                   timeZone: location.timeZone,
                   configuration: configuration
               ) {
                tomorrowFajr = times.fajr
            }
            let next = getNextPrayer.resolve(now: now, today: today, tomorrowFajr: tomorrowFajr)
            cityName = location.displayName ?? String(localized: "home.location.current")
            adhanEnabled = settingsStore.settings.globalAdhanEnabled
            state = .loaded(PrayerDay(times: today, next: next))
        } catch {
            state = .failed
        }
    }

    /// Bascule immédiate de l'Adhan, persistée aussitôt.
    func toggleAdhan() {
        settingsStore.setGlobalAdhanEnabled(!adhanEnabled)
        adhanEnabled = settingsStore.settings.globalAdhanEnabled
    }

    /// Recharge les horaires si le jour a changé (appelée chaque minute
    /// par la `TimelineView` de `HomeView`).
    func refreshIfNeeded(now: Date) {
        guard case .loaded(let day) = state else { return }
        guard !calendar.isDate(day.times.date, inSameDayAs: now) else { return }
        Task { await load() }
    }
}
