import Foundation

/// Configuration complète du calcul des horaires.
struct PrayerCalculationConfiguration: Sendable, Codable, Hashable {
    var method: CalculationMethod = .muslimWorldLeague
    var asrMethod: AsrMethod = .standard
    var highLatitudeRule: HighLatitudeRule = .middleOfNight
    /// Angles personnalisés (degrés, valeurs positives) ; `nil` = angle de la méthode.
    var fajrAngleOverride: Double?
    var ishaAngleOverride: Double?
    /// Ajustements manuels en minutes, par prière.
    var manualAdjustments: [Prayer: Int] = [:]
}
