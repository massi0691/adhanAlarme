import AVFoundation
import Foundation
import Observation

/// Moteur de lecture de l'Adhan via `AVPlayer` (voix, app active).
/// Session `.playback` + `.spokenAudio` (optimisé voix ; Bluetooth A2DP et
/// AirPlay gérés par le système). Interruptions (appels, Siri) et
/// débranchement casque gérés selon les recommandations Apple.
/// Observateurs enregistrés une fois (durée de vie = celle de l'app via
/// `AppContainer`), closures `[weak self]` : aucune fuite, rien à retirer.
/// Poursuite en arrière-plan : capacité `audio` (Info.plist) + Now Playing.
@MainActor
@Observable
final class AVPlayerAdhanPlaybackService: AdhanPlaybackService {
    private let audioStore: any MuezzinAudioStore
    /// Langue de l'app (`nil` = tests/outils → locale appareil).
    private let language: LanguageSettings?
    private let nowPlaying: AdhanNowPlayingController
    private var player: AVPlayer?
    private var currentMuezzinID: String?
    private var currentTitle: String?
    private var currentDuration: TimeInterval?
    private var wasPlayingBeforeInterruption = false

    private(set) var state: AdhanPlaybackState = .stopped

    init(
        audioStore: any MuezzinAudioStore,
        nowPlaying: AdhanNowPlayingController = AdhanNowPlayingController(),
        language: LanguageSettings? = nil
    ) {
        self.audioStore = audioStore
        self.nowPlaying = nowPlaying
        self.language = language
        nowPlaying.onPlay = { [weak self] in self?.resume() }
        nowPlaying.onPause = { [weak self] in self?.pause() }
        let center = NotificationCenter.default
        _ = center.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self else { return }
            // Swift 6 : `Notification` n'est pas `Sendable` — extraire les
            // scalaires AVANT le saut vers le MainActor.
            let rawType = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
            let rawOptions = notification.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt
            Task { @MainActor in self.handleInterruption(rawType: rawType, rawOptions: rawOptions) }
        }
        _ = center.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self else { return }
            let rawReason = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt
            Task { @MainActor in self.handleRouteChange(rawReason: rawReason) }
        }
        _ = center.addObserver(
            forName: AVPlayerItem.didPlayToEndTimeNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self else { return }
            // Identité `Sendable` de l'item (comparée à l'item courant sur le MainActor).
            let itemID = (notification.object as? AVPlayerItem).map(ObjectIdentifier.init)
            Task { @MainActor in self.handlePlaybackEnd(itemID: itemID) }
        }
        _ = center.addObserver(
            forName: AVPlayerItem.failedToPlayToEndTimeNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self else { return }
            let itemID = (notification.object as? AVPlayerItem).map(ObjectIdentifier.init)
            Task { @MainActor in self.handlePlaybackFailure(itemID: itemID) }
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
        let duration = try? await asset.load(.duration)
        let durationSeconds: TimeInterval? = {
            guard let duration, duration.isNumeric, duration.seconds.isFinite, duration.seconds > 0 else {
                return nil
            }
            return duration.seconds
        }()
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
        currentDuration = durationSeconds
        let format = if let appLanguage = language?.appLanguage {
            AppLocalization.string(forKey: "audio.nowPlayingTitle", language: appLanguage)
        } else {
            Bundle.main.localizedString(forKey: "audio.nowPlayingTitle", value: nil, table: nil)
        }
        let title = String(format: format, muezzin.name)
        currentTitle = title
        player.play()
        state = .playing(muezzinID: muezzin.id)
        nowPlaying.update(title: title, duration: durationSeconds, isPlaying: true)
    }

    func stop() {
        finishNaturally()
    }

    func pause() {
        guard case .playing(let id) = state else { return }
        player?.pause()
        state = .paused(muezzinID: id)
        if let currentTitle {
            nowPlaying.update(title: currentTitle, duration: currentDuration, isPlaying: false)
        }
    }

    func resume() {
        guard case .paused(let id) = state else { return }
        player?.play()
        state = .playing(muezzinID: id)
        if let currentTitle {
            nowPlaying.update(title: currentTitle, duration: currentDuration, isPlaying: true)
        }
    }

    // MARK: - Interruptions et routes

    private func handleInterruption(rawType: UInt?, rawOptions: UInt?) {
        guard let rawType, let type = AVAudioSession.InterruptionType(rawValue: rawType) else { return }
        switch type {
        case .began:
            if case .playing = state {
                wasPlayingBeforeInterruption = true
                pause()
            } else {
                wasPlayingBeforeInterruption = false
            }
        case .ended:
            let options = AVAudioSession.InterruptionOptions(rawValue: rawOptions ?? 0)
            if wasPlayingBeforeInterruption, options.contains(.shouldResume) {
                resume()
            }
            wasPlayingBeforeInterruption = false
        @unknown default:
            break
        }
    }

    private func handleRouteChange(rawReason: UInt?) {
        guard let rawReason, let reason = AVAudioSession.RouteChangeReason(rawValue: rawReason) else { return }
        // Casque débranché : pause (jamais de haut-parleur surprise).
        if reason == .oldDeviceUnavailable {
            pause()
        }
    }

    private func handlePlaybackEnd(itemID: ObjectIdentifier?) {
        guard let itemID, let current = player?.currentItem, ObjectIdentifier(current) == itemID else { return }
        finishNaturally()
    }

    private func handlePlaybackFailure(itemID: ObjectIdentifier?) {
        guard let itemID, let current = player?.currentItem, ObjectIdentifier(current) == itemID else { return }
        finishNaturally()
    }

    private func finishNaturally() {
        stopPlayback()
        state = .stopped
        currentMuezzinID = nil
        currentTitle = nil
        currentDuration = nil
        nowPlaying.clear()
        // Libère la session poliment (les apps interrompues peuvent reprendre).
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func stopPlayback() {
        player?.pause()
        player = nil
    }
}
