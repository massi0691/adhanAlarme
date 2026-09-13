import Foundation

/// Erreurs de planification des alertes (mappées vers des messages
/// localisés ; la replanification silencieuse après chargement les ignore).
enum PrayerAlertError: Error, Sendable, Hashable {
    /// Autorisation refusée/restreinte : guider vers Réglages iOS.
    case permissionDenied
    /// Horaires ou position indisponibles pendant le calcul.
    case timesUnavailable
    /// Le système a rejeté une requête (rare).
    case schedulingFailed
}
