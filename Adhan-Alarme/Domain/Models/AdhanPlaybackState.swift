import Foundation

/// État de lecture de l'Adhan, exposé à l'interface via le ViewModel.
enum AdhanPlaybackState: Sendable, Hashable {
    case stopped
    case playing(muezzinID: String)
    case paused(muezzinID: String)

    /// Voix active (lecture ou pause), `nil` si arrêté.
    var activeMuezzinID: String? {
        switch self {
        case .stopped: return nil
        case .playing(let id), .paused(let id): return id
        }
    }
}
