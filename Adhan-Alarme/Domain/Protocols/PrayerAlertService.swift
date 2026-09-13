import Foundation

/// Planification des alertes système (notifications locales).
/// Volontairement séparé de la lecture audio (voir `AdhanPlaybackService`).
/// Non-`Sendable` (précédent phases 2/3) : implémentation `@MainActor`,
/// appelants `@MainActor`.
protocol PrayerAlertService {
    /// Statut actuel (sans jamais déclencher la demande système).
    func authorizationStatus() async -> PrayerAlertAuthorization
    /// Demande système (bannière iOS, une seule fois par installation).
    func requestAuthorization() async -> PrayerAlertAuthorization
    /// Remplace toute la planification par `requests` (annule d'abord).
    /// Erreurs : `permissionDenied`, `schedulingFailed`.
    func schedule(_ requests: [PrayerAlertRequest]) async throws
    func cancelAllAlerts() async
    /// Annule les segments restants d'une occurrence (Adhan long),
    /// par préfixe `adhan.<prière>.<AAAAMMJJ>` (voir `dayIdentifier`).
    /// Sans effet sur les notifications uniques déjà tirées.
    func cancelChainedSegments(dayIdentifier: String) async
}
