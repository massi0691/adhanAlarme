import Foundation

/// Villes enregistrées + ville active. Source unique pour le mode manuel.
protocol CityStoring: AnyObject {
    var cities: [SavedCity] { get }
    var activeCityID: UUID? { get set }
    func add(_ city: SavedCity)
    func remove(id: UUID)
    func city(id: UUID?) -> SavedCity?
}
