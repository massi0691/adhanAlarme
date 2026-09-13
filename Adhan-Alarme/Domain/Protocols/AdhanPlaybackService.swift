import Foundation

/// Lecture de l'Adhan complet via le moteur audio de l'app (AVFoundation).
/// Utilisé quand l'app est active ; les notifications système restent courtes
/// (< 30 s, limite iOS — voir `docs/IOS_LIMITATIONS.md`).
/// Implémentation en phase 3.
protocol AdhanPlaybackService: Sendable {
    func playAdhan(_ muezzin: Muezzin) async throws
    func stop()
    func pause()
}
