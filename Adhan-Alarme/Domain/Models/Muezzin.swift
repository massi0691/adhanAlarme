import Foundation

/// Voix d'Adhan sélectionnable par l'utilisateur.
/// Audio résolu dans l'ordre : fichier bundle → cache téléchargé →
/// téléchargement depuis `remoteURL` (voir `MuezzinAudioStore`).
struct Muezzin: Sendable, Codable, Hashable, Identifiable {
    let id: String
    /// Nom d'affichage (nom propre, non localisé).
    let name: String
    /// Nom complet du fichier audio, ex. "makkah.mp3" (bundle ou cache).
    let audioFile: String
    /// URL de téléchargement (source autorisée). `nil` = bundle uniquement.
    /// Configurée par le propriétaire de l'app (voir `Resources/Adhan/README.md`).
    let remoteURL: URL?
    let language: String?
    let duration: TimeInterval?

    /// Catalogue embarqué. Les fichiers bundle correspondants vont dans
    /// `Resources/Adhan/` ; les URLs distantes se configurent ci-dessous
    /// (`remoteURL: nil` = téléchargement désactivé pour cette voix).
    static let catalog: [Muezzin] = [
        Muezzin(id: "makkah", name: "Makkah", audioFile: "makkah.mp3", remoteURL: nil, language: "ar", duration: nil),
        Muezzin(id: "madinah", name: "Madinah", audioFile: "madinah.mp3", remoteURL: nil, language: "ar", duration: nil),
        Muezzin(id: "alafasy", name: "Mishary Alafasy", audioFile: "alafasy.mp3", remoteURL: nil, language: "ar", duration: nil),
        Muezzin(id: "abdul-basit", name: "Abdul Basit", audioFile: "abdul-basit.mp3", remoteURL: nil, language: "ar", duration: nil),
    ]

    static let defaultID = "makkah"

    static func withID(_ id: String) -> Muezzin? {
        catalog.first { $0.id == id }
    }
}
