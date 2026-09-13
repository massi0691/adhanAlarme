import Foundation

/// Magasin de réglages, confiné au `MainActor` (écritures depuis l'UI).
protocol SettingsStoring: AnyObject {
    var settings: AppSettings { get set }
    func setGlobalAdhanEnabled(_ enabled: Bool)
}
