import Foundation

/// Racine de composition (injection de dépendances).
/// Phase 1 : dépôt simulé. Phase 2 : dépôt réel branché ici
/// (API → cache → calcul local), sans toucher aux Views ni ViewModels.
@MainActor
final class AppContainer {
    private let settingsStore: any SettingsStoring
    private let prayerTimesRepository: any PrayerTimesRepository

    init(settingsStore: any SettingsStoring, prayerTimesRepository: any PrayerTimesRepository) {
        self.settingsStore = settingsStore
        self.prayerTimesRepository = prayerTimesRepository
    }

    static var production: AppContainer {
        AppContainer(
            settingsStore: UserDefaultsSettingsStore(),
            prayerTimesRepository: MockPrayerTimesRepository()
        )
    }

    static var preview: AppContainer {
        let previewDefaults = UserDefaults(suiteName: "preview") ?? .standard
        return AppContainer(
            settingsStore: UserDefaultsSettingsStore(userDefaults: previewDefaults),
            prayerTimesRepository: MockPrayerTimesRepository()
        )
    }

    func makeHomeViewModel() -> HomeViewModel {
        HomeViewModel(
            getPrayerTimes: GetPrayerTimesUseCase(repository: prayerTimesRepository),
            settingsStore: settingsStore
        )
    }
}
