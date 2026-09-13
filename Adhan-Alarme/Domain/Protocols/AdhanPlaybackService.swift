import Foundation

/// Lecture de l'Adhan complet via le moteur audio de l'app (AVFoundation).
/// Utilisé quand l'app est active ; les notifications système restent courtes
/// (< 30 s, limite iOS — voir `docs/IOS_LIMITATIONS.md`).
/// Non-`Sendable` (précédent phase 2) : implémentation `@MainActor`,
/// appelants `@MainActor`.
protocol AdhanPlaybackService {
    /// État actuel (observé par l'interface via le ViewModel).
    var state: AdhanPlaybackState { get }
    /// Joue l'Adhan complet (résolution bundle → cache, sinon erreur claire).
    func playAdhan(_ muezzin: Muezzin) async throws
    func stop()
    func pause()
}
