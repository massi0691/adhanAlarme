import AVFoundation
import Foundation

/// Moteur de lecture de l'Adhan via `AVPlayer` (voix, app active).
/// Session `.playback` + `.spokenAudio` (optimisé voix ; Bluetooth A2DP et
/// AirPlay gérés par le système). Interruptions (appels, Siri) et
/// débranchement casque gérés selon les recommandations Apple.
/// Observateurs enregistrés une fois (durée de vie = celle de l'app via
/// `AppContainer`), closures `[weak self]` : aucune fuite, rien à retirer.
/// Continuation en arrière-plan + Now Playing : voir lot D (phase 3).
@MainActor
final class AVPlayerAdhanPlaybackService: AdhanPlaybackService {
    private let audioStore: any MuezzinAudioStore
    private var player: AVPlayer?
    private var currentMuezzinID: String?
    private var wasPlayingBeforeInterruption = false

    private(set) var state: AdhanPlaybackState = .stopped

    init(audioStore: any MuezzinAudioStore) {
        self.audioStore = audioStore
        let center = NotificationCenter.default
        _ = center.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self else { return }
            Task { @MainActor in self.handleInterruption(notification) }
        }
        _ = center.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self else { return }
            Task { @MainActor in self.handleRouteChange(notification) }
        }
        _ = center.addObserver(
            forName: AVPlayerItem.didPlayToEndTimeNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self else { return }
            Task { @MainActor in self.handlePlaybackEnd(notification) }
        }
        _ = center.addObserver(
            forName: AVPlayerItem.failedToPlayToEndTimeNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self else { return }
            Task { @MainActor in self.handlePlaybackFailure(notification) }
        }
    }

    func playAdhan(_ muezzin: Muezzin) async throws {
        guard let url = audioStore.localURL(for: muezzin) else {
            if muezzin.remoteURL == nil {
                throw AdhanPlaybackError.remoteSourceNotConfigured(muezzinID: muezzin.id)
            } else {
                throw AdhanPlaybackError.audioUnavailable(muezzinID: muezzin.id)
            }
        }
        // Validation réelle (lisible et jouable) avant de toucher la session.
        let asset = AVURLAsset(url: url)
        let playable = (try? await asset.load(.isPlayable)) ?? false
        guard playable else {
            throw AdhanPlaybackError.fileUnreadable(muezzinID: muezzin.id)
        }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .spokenAudio)
            try session.setActive(true)
        } catch {
            throw AdhanPlaybackError.audioSessionFailed
        }
        stopPlayback()
        let item = AVPlayerItem(asset: asset)
        let player = AVPlayer(playerItem: item)
        self.player = player
        currentMuezzinID = muezzin.id
        player.play()
        state = .playing(muezzinID: muezzin.id)
    }

    func stop() {
        finishNaturally()
    }

    func pause() {
        guard case .playing(let id) = state else { return }
        player?.pause()
        state = .paused(muezzinID: id)
    }

    func resume() {
        guard case .paused(let id) = state else { return }
        player?.play()
        state = .playing(muezzinID: id)
    }

    // MARK: - Interruptions et routes

    private func handleInterruption(_ notification: Notification) {
        guard let rawType = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: rawType) else { return }
        switch type {
        case .began:
            if case .playing = state {
                wasPlayingBeforeInterruption = true
                pause()
            } else {
                wasPlayingBeforeInterruption = false
            }
        case .ended:
            let rawOptions = notification.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
            let options = AVAudioSession.InterruptionOptions(rawValue: rawOptions)
            if wasPlayingBeforeInterruption, options.contains(.shouldResume) {
                resume()
            }
            wasPlayingBeforeInterruption = false
        @unknown default:
            break
        }
    }

    private func handleRouteChange(_ notification: Notification) {
        guard let rawReason = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: rawReason) else { return }
        // Casque débranché : pause (jamais de haut-parleur surprise).
        if reason == .oldDeviceUnavailable {
            pause()
        }
    }

    private func handlePlaybackEnd(_ notification: Notification) {
        guard notification.object as? AVPlayerItem === player?.currentItem else { return }
        finishNaturally()
    }

    private func handlePlaybackFailure(_ notification: Notification) {
        guard notification.object as? AVPlayerItem === player?.currentItem else { return }
        finishNaturally()
    }

    private func finishNaturally() {
        stopPlayback()
        state = .stopped
        currentMuezzinID = nil
        // Libère la session poliment (les apps interrompues peuvent reprendre).
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func stopPlayback() {
        player?.pause()
        player = nil
    }
}
