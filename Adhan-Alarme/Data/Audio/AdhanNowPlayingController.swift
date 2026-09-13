import Foundation
import MediaPlayer

/// Écran verrouillé et commandes casque/CarPlay pour l'Adhan.
/// Info statique en v1 (titre + état, sans progression temps réel).
/// Durée de vie = celle du service (handlers jamais retirés, `[weak self]`).
@MainActor
final class AdhanNowPlayingController {
    var onPlay: (@MainActor () -> Void)?
    var onPause: (@MainActor () -> Void)?
    private var isPlaying = false

    private let commandCenter = MPRemoteCommandCenter.shared()
    private let nowPlaying = MPNowPlayingInfoCenter.default()

    init() {
        _ = commandCenter.playCommand.addTarget { [weak self] _ in
            guard let self else { return .noActionableNowPlayingItem }
            Task { @MainActor in self.onPlay?() }
            return .success
        }
        _ = commandCenter.pauseCommand.addTarget { [weak self] _ in
            guard let self else { return .noActionableNowPlayingItem }
            Task { @MainActor in self.onPause?() }
            return .success
        }
        _ = commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
            guard let self else { return .noActionableNowPlayingItem }
            Task { @MainActor in
                if self.isPlaying {
                    self.onPause?()
                } else {
                    self.onPlay?()
                }
            }
            return .success
        }
        clear()
    }

    func update(title: String, duration: TimeInterval?, isPlaying: Bool) {
        self.isPlaying = isPlaying
        nowPlaying.nowPlayingInfo = AdhanNowPlayingInfo.dictionary(
            title: title,
            duration: duration,
            isPlaying: isPlaying
        )
        commandCenter.playCommand.isEnabled = !isPlaying
        commandCenter.pauseCommand.isEnabled = isPlaying
        commandCenter.togglePlayPauseCommand.isEnabled = true
    }

    func clear() {
        isPlaying = false
        nowPlaying.nowPlayingInfo = nil
        commandCenter.playCommand.isEnabled = false
        commandCenter.pauseCommand.isEnabled = false
        commandCenter.togglePlayPauseCommand.isEnabled = false
    }
}
