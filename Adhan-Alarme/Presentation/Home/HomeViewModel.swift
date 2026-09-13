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
/// Dépendances injectées (use case + magasin de réglages) : testable.
@Observable
@MainActor
final class HomeViewModel {
    private let getPrayerTimes: GetPrayerTimesUseCase
    private let getNextPrayer = GetNextPrayerUseCase()
    private let settingsStore: any SettingsStoring
    private let calendar: Calendar

    private(set) var state: HomeViewState = .loading
    private(set) var cityName: String = ""
    private(set) var adhanEnabled: Bool = true

    init(
        getPrayerTimes: GetPrayerTimesUseCase,
        settingsStore: any SettingsStoring,
        calendar: Calendar = .current
    ) {
        self.getPrayerTimes = getPrayerTimes
        self.settingsStore = settingsStore
        self.calendar = calendar
        self.cityName = settingsStore.settings.activeCityName
        self.adhanEnabled = settingsStore.settings.globalAdhanEnabled
    }

    /// Charge les horaires du jour (et le Fajr du lendemain pour le
    /// compte à rebours après Isha).
    func load() async {
        state = .loading
        do {
            let now = Date()
            let today = try await getPrayerTimes.execute(for: now)
            var tomorrowFajr: Date?
            if let tomorrow = calendar.date(byAdding: .day, value: 1, to: now),
               let times = try? await getPrayerTimes.execute(for: tomorrow) {
                tomorrowFajr = times.fajr
            }
            let next = getNextPrayer.resolve(now: now, today: today, tomorrowFajr: tomorrowFajr)
            cityName = settingsStore.settings.activeCityName
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
