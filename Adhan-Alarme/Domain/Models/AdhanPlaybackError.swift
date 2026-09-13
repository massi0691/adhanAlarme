import Foundation

/// Erreurs du moteur audio et du téléchargement (mappées vers des
/// messages localisés dans les ViewModels, jamais affichées brutes).
enum AdhanPlaybackError: Error, Sendable, Hashable {
    /// Fichier ni dans le bundle ni téléchargé.
    case audioUnavailable(muezzinID: String)
    /// Aucune URL configurée pour cette voix (propriétaire de l'app).
    case remoteSourceNotConfigured(muezzinID: String)
    /// Échec réseau pendant le téléchargement.
    case downloadFailed(muezzinID: String)
    /// Session audio impossible (appel prioritaire, matériel…).
    case audioSessionFailed
    /// Fichier présent mais illisible ou corrompu.
    case fileUnreadable(muezzinID: String)
}
