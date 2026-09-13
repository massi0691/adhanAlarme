import Foundation

/// Sélection d'une ville : résolution, ajout (sans doublon), activation
/// et bascule en mode manuel.
@MainActor
struct SelectCityUseCase {
    private let searchService: any CitySearching
    private let cityStore: any CityStoring
    private let settingsStore: any SettingsStoring

    init(
        searchService: any CitySearching,
        cityStore: any CityStoring,
        settingsStore: any SettingsStoring
    ) {
        self.searchService = searchService
        self.cityStore = cityStore
        self.settingsStore = settingsStore
    }

    @discardableResult
    func select(_ result: CitySearchResult) async throws -> SavedCity {
        let resolved = try await searchService.resolveCity(result)
        if let existing = cityStore.cities.first(where: {
            $0.name.lowercased() == resolved.name.lowercased()
        }) {
            cityStore.activeCityID = existing.id
            settingsStore.settings.useAutomaticLocation = false
            return existing
        }
        cityStore.add(resolved)
        cityStore.activeCityID = resolved.id
        settingsStore.settings.useAutomaticLocation = false
        return resolved
    }
}
