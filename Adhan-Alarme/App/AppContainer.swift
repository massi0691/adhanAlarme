import Foundation

/// Racine de composition (injection de dépendances).
/// Production : dépôt réel (cache → API Aladhan → calcul local),
/// localisation Core Location, recherche MapKit, audio AVPlayer.
/// Previews : calcul local uniquement, position figée (aucun réseau).
@MainActor
final class AppContainer {
    private let settingsStore: any SettingsStoring
    private let cityStore: any CityStoring
    private let locationService: any LocationProviding
    private let searchService: any CitySearching
    private let geocoder: any ReverseGeocoding
    private let resolver: any ActiveLocationResolving
    private let prayerTimesRepository: any PrayerTimesRepository
    private let audioStore: any MuezzinAudioStore
    private let playbackService: any AdhanPlaybackService

    init(
        settingsStore: any SettingsStoring,
        cityStore: any CityStoring,
        locationService: any LocationProviding,
        searchService: any CitySearching,
        geocoder: any ReverseGeocoding,
        resolver: any ActiveLocationResolving,
        prayerTimesRepository: any PrayerTimesRepository,
        audioStore: any MuezzinAudioStore,
        playbackService: any AdhanPlaybackService
    ) {
        self.settingsStore = settingsStore
        self.cityStore = cityStore
        self.locationService = locationService
        self.searchService = searchService
        self.geocoder = geocoder
        self.resolver = resolver
        self.prayerTimesRepository = prayerTimesRepository
        self.audioStore = audioStore
        self.playbackService = playbackService
    }

    static var production: AppContainer {
        let settings = UserDefaultsSettingsStore()
        let cities = UserDefaultsCityStore()
        let location = CoreLocationService()
        let search = MapKitCitySearchService()
        let geocoder = MapKitReverseGeocoder()
        let resolver = ActiveLocationResolver(
            settingsStore: settings,
            cityStore: cities,
            locationService: location,
            geocoder: geocoder
        )
        let repository = DefaultPrayerTimesRepository(
            api: AladhanAPIProvider(),
            local: LocalCalculationProvider(),
            cache: PrayerTimesCache()
        )
        let audioStore = FileSystemMuezzinAudioStore()
        let playback = AVPlayerAdhanPlaybackService(audioStore: audioStore)
        return AppContainer(
            settingsStore: settings,
            cityStore: cities,
            locationService: location,
            searchService: search,
            geocoder: geocoder,
            resolver: resolver,
            prayerTimesRepository: repository,
            audioStore: audioStore,
            playbackService: playback
        )
    }

    static var preview: AppContainer {
        let previewDefaults = UserDefaults(suiteName: "preview") ?? .standard
        let settings = UserDefaultsSettingsStore(userDefaults: previewDefaults)
        let cities = UserDefaultsCityStore(userDefaults: previewDefaults)
        let location = CoreLocationService()
        let search = MapKitCitySearchService()
        let geocoder = MapKitReverseGeocoder()
        let local = LocalCalculationProvider()
        let repository = DefaultPrayerTimesRepository(
            api: local,
            local: local,
            cache: PrayerTimesCache(userDefaults: previewDefaults)
        )
        let audioStore = FileSystemMuezzinAudioStore()
        let playback = AVPlayerAdhanPlaybackService(audioStore: audioStore)
        return AppContainer(
            settingsStore: settings,
            cityStore: cities,
            locationService: location,
            searchService: search,
            geocoder: geocoder,
            resolver: StaticLocationResolver(),
            prayerTimesRepository: repository,
            audioStore: audioStore,
            playbackService: playback
        )
    }

    func makeHomeViewModel() -> HomeViewModel {
        HomeViewModel(
            getPrayerTimes: GetPrayerTimesUseCase(repository: prayerTimesRepository),
            settingsStore: settingsStore,
            resolver: resolver
        )
    }

    func makeLocationViewModel() -> LocationViewModel {
        LocationViewModel(
            settingsStore: settingsStore,
            cityStore: cityStore,
            locationService: locationService,
            searchService: searchService,
            selectCity: SelectCityUseCase(
                searchService: searchService,
                cityStore: cityStore,
                settingsStore: settingsStore
            )
        )
    }

    func makeSettingsViewModel() -> SettingsViewModel {
        SettingsViewModel(
            settingsStore: settingsStore,
            audioStore: audioStore,
            playback: playbackService
        )
    }
}
