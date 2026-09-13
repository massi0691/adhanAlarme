import Foundation

/// Proposition de ville issue de la recherche (MapKit).
struct CitySearchResult: Sendable, Hashable, Identifiable {
    let title: String
    let subtitle: String

    var id: String { "\(title)|\(subtitle)" }
}
