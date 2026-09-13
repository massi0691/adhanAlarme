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
    /// Configurée par le propriétaire de l'app (voir `Resources/Adhan/README.md`,
    /// section « Sources distantes » : droits et conditions du site source).
    let remoteURL: URL?
    let language: String?
    let duration: TimeInterval?

    /// Catalogue embarqué. Les fichiers bundle correspondants vont dans
    /// `Resources/Adhan/` ; les URLs distantes ci-dessous pointent vers
    /// les fichiers du site source (téléchargement chez l'utilisateur
    /// final, rien n'est redistribué par l'app — voir le README audio).
    static let catalog: [Muezzin] = [
        Muezzin(id: "makkah", name: "Makkah", audioFile: "makkah.mp3", remoteURL: URL(string: "https://media.assabile.com/assabile/adhan_3435370/a3c148ae770f.mp3"), language: "ar", duration: 214),
        Muezzin(id: "madinah", name: "Madinah", audioFile: "madinah.mp3", remoteURL: URL(string: "https://media.assabile.com/assabile/adhan_3435370/b30ca9a3e115.mp3"), language: "ar", duration: 189),
        Muezzin(id: "alafasy", name: "Mishary Alafasy", audioFile: "alafasy.mp3", remoteURL: URL(string: "https://media.assabile.com/assabile/adhan_3435370/b45e93f1efb3.mp3"), language: "ar", duration: 240),
        Muezzin(id: "abdul-basit", name: "Abdul Basit", audioFile: "abdul-basit.mp3", remoteURL: URL(string: "https://media.assabile.com/assabile/adhan_3435370/02f1bec971bb.mp3"), language: "ar", duration: 200),
    ]

    static let defaultID = "makkah"

    static func withID(_ id: String) -> Muezzin? {
        catalog.first { $0.id == id }
    }
}
