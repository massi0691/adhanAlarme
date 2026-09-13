import Foundation

enum CitySearchError: Error, Sendable, Hashable {
    case noResults
    case resolutionFailed
}

/// Recherche de villes (autocomplétion + résolution complète).
protocol CitySearching: AnyObject {
    /// Suggestions pour la frappe en cours. En pratique ne lève jamais :
    /// un échec (réseau…) vaut une liste vide.
    func searchCities(matching query: String) async throws -> [CitySearchResult]
    /// Résout une suggestion en ville complète (coordonnées + fuseau).
    func resolveCity(_ result: CitySearchResult) async throws -> SavedCity
}
