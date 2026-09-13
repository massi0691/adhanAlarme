import Foundation
import MediaPlayer

/// Fabrique pure des métadonnées « En cours de lecture » (testable).
/// Titre localisé fourni par le service (voir `audio.nowPlayingTitle`).
enum AdhanNowPlayingInfo {
    static func dictionary(
        title: String,
        duration: TimeInterval?,
        isPlaying: Bool
    ) -> [String: Any] {
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: title,
            MPMediaItemPropertyArtist: Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName")
                ?? Bundle.main.object(forInfoDictionaryKey: kCFBundleNameKey as String)
                ?? "Adhan-Alarme",
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0,
        ]
        if let duration, duration.isFinite, duration > 0 {
            info[MPMediaItemPropertyPlaybackDuration] = duration
        }
        return info
    }
}
