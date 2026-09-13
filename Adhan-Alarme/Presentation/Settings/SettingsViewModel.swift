import Foundation
import Observation

/// ViewModel de l'écran Réglages (section voix) : sélection persistée,
/// disponibilités, téléchargements avec progression, aperçu de lecture.
/// L'état de lecture est observé en direct (service `@Observable`).
@Observable
@MainActor
final class SettingsViewModel {
    private let settingsStore: any SettingsStoring
    private let audioStore: any MuezzinAudioStore
    private let playback: any AdhanPlaybackService
    private let alertScheduler: SchedulePrayerAlertsUseCase
    private let alertService: any PrayerAlertService

    let voices: [Muezzin] = Muezzin.catalog
    private(set) var selectedMuezzinID: String
    private(set) var availability: [String: MuezzinAudioAvailability] = [:]
    private(set) var downloadProgress: [String: Double] = [:]
    private(set) var errorKey: String?
    private(set) var alertAuthorization: PrayerAlertAuthorization = .notDetermined
    /// Miroir de l'interrupteur global (partagé avec l'accueil).
    private(set) var alertsEnabled = true
    private(set) var alertModes: [Prayer: PrayerAlertMode] = [:]

    /// Lecture directe du service : suivi temps réel (interruptions, fin…).
    var playbackState: AdhanPlaybackState { playback.state }

    init(
        settingsStore: any SettingsStoring,
        audioStore: any MuezzinAudioStore,
        playback: any AdhanPlaybackService,
        alertScheduler: SchedulePrayerAlertsUseCase,
        alertService: any PrayerAlertService
    ) {
        self.settingsStore = settingsStore
        self.audioStore = audioStore
        self.playback = playback
        self.alertScheduler = alertScheduler
        self.alertService = alertService
        self.selectedMuezzinID = settingsStore.settings.selectedMuezzinID
        refreshAvailability()
        syncAlertState()
    }

    func refresh() {
        selectedMuezzinID = settingsStore.settings.selectedMuezzinID
        refreshAvailability()
        syncAlertState()
    }

    /// Sélection globale : voix par défaut + propagation aux 6 prières
    /// (les alertes embarquent la voix de chaque prière ; voix par prière
    /// personnalisables dans une phase ultérieure).
    func select(_ muezzin: Muezzin) {
        var settings = settingsStore.settings
        settings.selectedMuezzinID = muezzin.id
        for prayer in Prayer.allCases {
            settings.prayerPreferences[prayer]?.selectedMuezzinID = muezzin.id
        }
        settingsStore.settings = settings
        selectedMuezzinID = muezzin.id
        Task { await refreshAlerts() }
    }

    func togglePlay(_ muezzin: Muezzin) async {
        errorKey = nil
        switch playback.state {
        case .playing(let id) where id == muezzin.id:
            playback.pause()
        case .paused(let id) where id == muezzin.id:
            playback.resume()
        default:
            do {
                try await playback.playAdhan(muezzin)
            } catch let error as AdhanPlaybackError {
                errorKey = Self.errorKey(for: error)
            } catch {
                errorKey = "audio.error.failed"
            }
        }
    }

    func stop() {
        playback.stop()
    }

    func download(_ muezzin: Muezzin) async {
        guard downloadProgress[muezzin.id] == nil else { return }
        errorKey = nil
        downloadProgress[muezzin.id] = 0
        do {
            for try await progress in audioStore.download(muezzin) {
                downloadProgress[muezzin.id] = progress
            }
        } catch let error as AdhanPlaybackError {
            errorKey = Self.errorKey(for: error)
        } catch is CancellationError {
        } catch {
            errorKey = "audio.error.downloadFailed"
        }
        downloadProgress.removeValue(forKey: muezzin.id)
        refreshAvailability()
    }

    func deleteDownload(_ muezzin: Muezzin) {
        errorKey = nil
        do {
            if playbackState.activeMuezzinID == muezzin.id {
                playback.stop()
            }
            try audioStore.deleteDownload(of: muezzin)
        } catch {
            errorKey = "audio.error.failed"
        }
        refreshAvailability()
    }

    // MARK: - Alertes

    /// Active les alertes : demande système puis planification.
    func enableAlerts() async {
        let granted = (try? await alertService.requestAuthorization()) ?? false
        alertAuthorization = await alertService.authorizationStatus()
        guard granted else { return }
        settingsStore.settings.globalAdhanEnabled = true
        alertsEnabled = true
        await refreshAlerts()
    }

    /// Coupe les alertes (les notifications planifiées sont annulées).
    func disableAlerts() {
        settingsStore.settings.globalAdhanEnabled = false
        alertsEnabled = false
        Task { await refreshAlerts() }
    }

    /// Mode d'une prière (Adhan / notification / silencieux).
    func setAlertMode(_ mode: PrayerAlertMode, for prayer: Prayer) {
        settingsStore.settings.prayerPreferences[prayer]?.mode = mode
        alertModes[prayer] = mode
        Task { await refreshAlerts() }
    }

    /// État de l'autorisation système (lu à l'ouverture de Réglages).
    func loadAlertAuthorization() async {
        alertAuthorization = await alertService.authorizationStatus()
    }

    private func syncAlertState() {
        alertsEnabled = settingsStore.settings.globalAdhanEnabled
        alertModes = Dictionary(uniqueKeysWithValues: settingsStore.settings.prayerPreferences.map {
            ($0.key, $0.value.mode)
        })
    }

    private func refreshAlerts() async {
        do {
            let requests = try await alertScheduler.execute(now: Date(), settings: settingsStore.settings)
            try await alertService.schedule(requests)
        } catch {
            // Best-effort : les réglages restent valides sans planification.
        }
    }

    private func refreshAvailability() {
        availability = Dictionary(uniqueKeysWithValues: voices.map { ($0.id, audioStore.availability(of: $0)) })
    }

    private static func errorKey(for error: AdhanPlaybackError) -> String {
        switch error {
        case .audioUnavailable: return "audio.error.unavailable"
        case .remoteSourceNotConfigured: return "audio.error.notConfigured"
        case .downloadFailed: return "audio.error.downloadFailed"
        case .audioSessionFailed: return "audio.error.sessionFailed"
        case .fileUnreadable: return "audio.error.unreadable"
        }
    }
}
