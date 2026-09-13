import Foundation

/// Voix d'Adhan sélectionnable par l'utilisateur.
struct Muezzin: Sendable, Codable, Hashable, Identifiable {
    let id: String
    /// Nom d'affichage (nom propre, non localisé).
    let name: String
    /// Nom complet du fichier audio embarqué, ex. "makkah.mp3".
    let audioFile: String
    let language: String?
    let duration: TimeInterval?

    /// Catalogue embarqué. Les fichiers correspondants doivent exister dans
    /// `Resources/Adhan/` (voir le README de ce dossier pour la licence).
    static let catalog: [Muezzin] = [
        Muezzin(id: "makkah", name: "Makkah", audioFile: "makkah.mp3", language: "ar", duration: nil),
        Muezzin(id: "madinah", name: "Madinah", audioFile: "madinah.mp3", language: "ar", duration: nil),
        Muezzin(id: "alafasy", name: "Mishary Alafasy", audioFile: "alafasy.mp3", language: "ar", duration: nil),
        Muezzin(id: "abdul-basit", name: "Abdul Basit", audioFile: "abdul-basit.mp3", language: "ar", duration: nil),
    ]

    static let defaultID = "makkah"

    static func withID(_ id: String) -> Muezzin? {
        catalog.first { $0.id == id }
    }
}
