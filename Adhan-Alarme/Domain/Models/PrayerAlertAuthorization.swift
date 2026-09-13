import Foundation

/// Statut d'autorisation des notifications système.
/// L'autorisation provisoire iOS est traitée comme autorisée
/// (les alertes sont planifiables dans les deux cas).
enum PrayerAlertAuthorization: Sendable, Hashable {
    case notDetermined
    case authorized
    case denied
    /// Contrôle parental / profil : impossible à accorder depuis l'app.
    case restricted

    /// La planification peut produire des alertes visibles.
    var canSchedule: Bool {
        self == .authorized
    }
}
