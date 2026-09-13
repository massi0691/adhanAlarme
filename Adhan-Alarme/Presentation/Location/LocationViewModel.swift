import Foundation
import Observation

/// ViewModel de l'écran Position : mode auto/manuel, recherche de ville
/// (avec protection contre les réponses dans le désordre), villes
/// enregistrées. Dépendances injectées : testable.
@Observable
@MainActor
final class LocationViewModel {
    private let settingsStore: any SettingsStoring
    private let cityStore: any CityStoring
    private let locationService: any LocationProviding
    private let searchService: any CitySearching
    private let selectCity: SelectCityUseCase

    private(set) var useAutomatic = true
    private(set) var authorization: LocationAuthorization = .notDetermined
    private(set) var searchResults: [CitySearchResult] = []
    private(set) var isSearching = false
    private(set) var cities: [SavedCity] = []
    private(set) var activeCityID: UUID?
    private(set) var errorKey: String?
    private var searchGeneration = 0

    init(
        settingsStore: any SettingsStoring,
        cityStore: any CityStoring,
        locationService: any LocationProviding,
        searchService: any CitySearching,
        selectCity: SelectCityUseCase
    ) {
        self.settingsStore = settingsStore
        self.cityStore = cityStore
        self.locationService = locationService
        self.searchService = searchService
        self.selectCity = selectCity
        syncMirrors()
    }

    func refresh() {
        authorization = locationService.authorizationStatus()
        syncMirrors()
    }

    func setAutomatic(_ enabled: Bool) async {
        errorKey = nil
        if enabled {
            let status = await locationService.requestAuthorization()
            authorization = status
            guard status == .authorized else { return }
            settingsStore.settings.useAutomaticLocation = true
        } else {
            settingsStore.settings.useAutomaticLocation = false
        }
        syncMirrors()
    }

    func search(query: String) async {
        searchGeneration += 1
        let generation = searchGeneration
        isSearching = true
        defer {
            if generation == searchGeneration { isSearching = false }
        }
        let results = (try? await searchService.searchCities(matching: query)) ?? []
        if generation == searchGeneration {
            searchResults = results
        }
    }

    func clearSearch() {
        searchGeneration += 1
        searchResults = []
        isSearching = false
    }

    func select(_ result: CitySearchResult) async {
        errorKey = nil
        do {
            try await selectCity.select(result)
        } catch {
            errorKey = "error.cityResolve"
        }
        clearSearch()
        syncMirrors()
    }

    func activate(_ city: SavedCity) {
        cityStore.activeCityID = city.id
        settingsStore.settings.useAutomaticLocation = false
        syncMirrors()
    }

    func remove(_ city: SavedCity) {
        cityStore.remove(id: city.id)
        syncMirrors()
    }

    func remove(at offsets: IndexSet) {
        for index in offsets {
            cityStore.remove(id: cities[index].id)
        }
        syncMirrors()
    }

    private func syncMirrors() {
        useAutomatic = settingsStore.settings.useAutomaticLocation
        cities = cityStore.cities
        activeCityID = cityStore.activeCityID
    }
}
