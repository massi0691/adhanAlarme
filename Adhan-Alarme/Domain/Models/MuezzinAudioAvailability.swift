import Foundation

/// Disponibilité du fichier audio d'un Muadhin (ordre de résolution :
/// bundle embarqué → cache téléchargé → source distante).
enum MuezzinAudioAvailability: Sendable, Hashable {
    /// Dans le bundle : lecture immédiate, non supprimable.
    case bundled
    /// Téléchargé en cache : lecture immédiate, supprimable.
    case downloaded
    /// URL configurée : à télécharger.
    case remoteAvailable
    /// Ni bundle, ni cache, ni URL configurée.
    case unavailable
}
