import Foundation

/// Segments de 30 s pour l'Adhan long (hack expérimental, opt-in) :
/// noms des fichiers prêts + préparation (découpage du fichier complet).
/// Non-`Sendable` (précédent alertes/audio) : implémentation `@MainActor`,
/// appelants `@MainActor` (le découpage lui-même est détaché).
protocol AdhanSegmentStore {
    /// Noms des segments prêts, dans l'ordre (`nil` si non préparés).
    func segmentSoundNames(for muezzinID: String) -> [String]?
    /// Découpe le fichier complet en segments ≤ 30 s (idempotent :
    /// renvoie l'existant sans rien refaire).
    func prepareSegments(for muezzin: Muezzin, sourceURL: URL) async throws -> [String]
}
