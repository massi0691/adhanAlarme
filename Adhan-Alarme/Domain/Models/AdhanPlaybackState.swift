import Foundation

/// État de lecture de l'Adhan, exposé à l'interface via le ViewModel.
enum AdhanPlaybackState: Sendable, Hashable {
    case stopped
    case playing(muezzinID: String)
    case paused(muezzinID: String)
}
