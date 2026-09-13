import Foundation

/// Stockage des fichiers audio : bundle embarqué + cache téléchargé.
/// Résolution : bundle → cache → (téléchargement explicite).
/// Non-`Sendable` (précédent phase 2) : implémentation `@MainActor`,
/// appelants `@MainActor`.
protocol MuezzinAudioStore {
    /// Disponibilité locale actuelle (bundle, cache, distante, aucune).
    func availability(of muezzin: Muezzin) -> MuezzinAudioAvailability
    /// URL locale lisible (bundle ou cache), `nil` si rien en local.
    func localURL(for muezzin: Muezzin) -> URL?
    /// Télécharge depuis `remoteURL` (progression 0.0 → 1.0 puis fin).
    /// Erreurs : `remoteSourceNotConfigured`, `downloadFailed`.
    func download(_ muezzin: Muezzin) -> AsyncThrowingStream<Double, Error>
    /// Supprime le fichier téléchargé (jamais le bundle).
    func deleteDownload(of muezzin: Muezzin) throws
}
