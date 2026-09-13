import AVFoundation
import Foundation
import Observation
import os

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
    private var stallRetries = 0

    private(set) var state: AdhanPlaybackState = .stopped

    /// Journal de bord audio (Console.app, catégorie « audio ») : permet
    /// de trancher (interruption iOS, route, micro-coupure, arrêt
    /// demandé…) quand la lecture s'arrête hors de l'app, par exemple
    /// au verrouillage de l'écran. Niveau `info` : visible par défaut
    /// dans Console.app (le niveau `debug` y est caché par défaut).
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "Adhan-Alarme",
        category: "audio"
    )

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
        _ = center.addObserver(
            forName: AVPlayerItem.playbackStalledNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self else { return }
            let itemID = (notification.object as? AVPlayerItem).map(ObjectIdentifier.init)
            Task { @MainActor in self.handlePlaybackStall(itemID: itemID) }
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
        // Diagnostic : quelles clés générées atterrissent vraiment dans
        // l'app installée (le mécanisme INFOPLIST_KEY_ est suspecté).
        let info = Bundle.main.infoDictionary ?? [:]
        let bgModes = String(describing: info["UIBackgroundModes"])
        let storyboard = String(describing: info["UILaunchStoryboardName"])
        let locDesc = String(describing: info["NSLocationWhenInUseUsageDescription"])
        let version = String(describing: info["CFBundleShortVersionString"])
        Self.logger.info("ADHAN-DIAG-3 playAdhan \(muezzin.id, privacy: .public) bgmodes=\(bgModes, privacy: .public) storyboard=\(storyboard, privacy: .public) locdesc=\(locDesc, privacy: .public) version=\(version, privacy: .public)")
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .spokenAudio)
            try session.setActive(true)
        } catch {
            Self.logger.error("session audio refusee : \(String(describing: error), privacy: .public)")
            throw AdhanPlaybackError.audioSessionFailed
        }
        stopPlayback()
        stallRetries = 0
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
        Self.logger.info("stop() appele (etat avant : \(String(describing: self.state), privacy: .public))")
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
        Self.logger.info("interruption \(String(describing: type), privacy: .public)")
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
            Self.logger.info("interruption finie, reprise systeme : \(options.contains(.shouldResume), privacy: .public)")
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
        Self.logger.info("route audio : \(String(describing: reason), privacy: .public)")
        // Casque débranché : pause (jamais de haut-parleur surprise).
        if reason == .oldDeviceUnavailable {
            pause()
        }
    }

    private func handlePlaybackEnd(itemID: ObjectIdentifier?) {
        guard let itemID, let current = player?.currentItem, ObjectIdentifier(current) == itemID else { return }
        Self.logger.info("lecture terminee (fin de fichier)")
        finishNaturally()
    }

    private func handlePlaybackFailure(itemID: ObjectIdentifier?) {
        guard let itemID, let current = player?.currentItem, ObjectIdentifier(current) == itemID else { return }
        Self.logger.error("echec lecture : \(String(describing: self.player?.currentItem?.error), privacy: .public)")
        finishNaturally()
    }

    /// Micro-coupure de lecture (ex. à l'extinction d'écran) : relance
    /// best-effort, 2 essais maximum puis arrêt propre (pas de boucle).
    private func handlePlaybackStall(itemID: ObjectIdentifier?) {
        guard let itemID, let current = player?.currentItem, ObjectIdentifier(current) == itemID else { return }
        if stallRetries < 2, case .playing = state {
            stallRetries += 1
            Self.logger.info("micro-coupure, relance \(self.stallRetries, privacy: .public)/2")
            player?.play()
        } else {
            Self.logger.info("micro-coupure persistante, arret propre")
            finishNaturally()
        }
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
