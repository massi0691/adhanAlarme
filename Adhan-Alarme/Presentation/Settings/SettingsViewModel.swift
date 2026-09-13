import Foundation
import Observation

/// ViewModel de l'écran Réglages (voix, alertes, calcul) : sélection
/// persistée, téléchargements, aperçu de lecture, modes d'alerte,
/// méthode et ajustements de calcul.
/// L'état de lecture est observé en direct (service `@Observable`).
@Observable
@MainActor
final class SettingsViewModel {
    private let settingsStore: any SettingsStoring
    private let audioStore: any MuezzinAudioStore
    private let playback: any AdhanPlaybackService
    private let alertScheduler: SchedulePrayerAlertsUseCase
    private let alertService: any PrayerAlertService
    private let segments: any AdhanSegmentStore
    private let language: LanguageSettings

    let voices: [Muezzin] = Muezzin.catalog
    private(set) var selectedMuezzinID: String
    private(set) var availability: [String: MuezzinAudioAvailability] = [:]
    private(set) var downloadProgress: [String: Double] = [:]
    private(set) var errorKey: String?
    private(set) var alertAuthorization: PrayerAlertAuthorization = .notDetermined
    /// Miroir de l'interrupteur global (partagé avec l'accueil).
    private(set) var alertsEnabled = true
    private(set) var alertModes: [Prayer: PrayerAlertMode] = [:]
    private(set) var longAdhanEnabled = false
    private(set) var isPreparingLongAdhan = false
    private(set) var calculationMethod: CalculationMethod = .muslimWorldLeague
    private(set) var asrMethod: AsrMethod = .standard
    private(set) var highLatitudeRule: HighLatitudeRule = .middleOfNight
    private(set) var usesCustomAngles = false
    private(set) var fajrAngle: Double = 18
    private(set) var ishaAngle: Double = 17
    private(set) var manualAdjustments: [Prayer: Int] = [:]
    private(set) var appLanguage: AppLanguage = .system

    /// Lecture directe du service : suivi temps réel (interruptions, fin…).
    var playbackState: AdhanPlaybackState { playback.state }

    init(
        settingsStore: any SettingsStoring,
        audioStore: any MuezzinAudioStore,
        playback: any AdhanPlaybackService,
        alertScheduler: SchedulePrayerAlertsUseCase,
        alertService: any PrayerAlertService,
        segments: any AdhanSegmentStore,
        language: LanguageSettings
    ) {
        self.settingsStore = settingsStore
        self.audioStore = audioStore
        self.playback = playback
        self.alertScheduler = alertScheduler
        self.alertService = alertService
        self.segments = segments
        self.language = language
        self.selectedMuezzinID = settingsStore.settings.selectedMuezzinID
        refreshAvailability()
        syncAlertState()
        syncCalculationState()
        syncLanguageState()
    }

    func refresh() {
        selectedMuezzinID = settingsStore.settings.selectedMuezzinID
        refreshAvailability()
        syncAlertState()
        syncCalculationState()
        syncLanguageState()
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
        alertAuthorization = await alertService.requestAuthorization()
        guard alertAuthorization.canSchedule else { return }
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

    /// Hack « Adhan long » (expérimental, opt-in) : à l'activation,
    /// découpe la voix globale en segments de 30 s puis replanifie
    /// (v1 : seule la voix globale est découpée, propagée aux prières).
    func setLongAdhanEnabled(_ enabled: Bool) async {
        guard enabled else {
            settingsStore.settings.longAdhanEnabled = false
            longAdhanEnabled = false
            await refreshAlerts()
            return
        }
        guard let muezzin = Muezzin.withID(settingsStore.settings.selectedMuezzinID),
              let sourceURL = audioStore.localURL(for: muezzin) else {
            errorKey = "settings.alerts.longAdhanNeedsDownload"
            return
        }
        errorKey = nil
        isPreparingLongAdhan = true
        do {
            _ = try await segments.prepareSegments(for: muezzin, sourceURL: sourceURL)
            settingsStore.settings.longAdhanEnabled = true
            longAdhanEnabled = true
            await refreshAlerts()
        } catch {
            errorKey = "audio.error.failed"
        }
        isPreparingLongAdhan = false
    }

    /// État de l'autorisation système (lu à l'ouverture de Réglages).
    func loadAlertAuthorization() async {
        alertAuthorization = await alertService.authorizationStatus()
    }

    private func syncAlertState() {
        alertsEnabled = settingsStore.settings.globalAdhanEnabled
        longAdhanEnabled = settingsStore.settings.longAdhanEnabled
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

    // MARK: - Langue

    /// Langue de l'interface (replanifie les alertes : les chaînes des
    /// notifications sont pré-rendues dans la langue de l'app).
    func setAppLanguage(_ language: AppLanguage) {
        self.language.setAppLanguage(language)
        syncLanguageState()
        Task { await refreshAlerts() }
    }

    private func syncLanguageState() {
        appLanguage = language.appLanguage
    }

    // MARK: - Calcul

    /// Méthode de calcul (MWL, UOIF…).
    func setCalculationMethod(_ method: CalculationMethod) {
        var calculation = settingsStore.settings.calculation
        calculation.method = method
        settingsStore.settings.calculation = calculation
        syncCalculationState()
        Task { await refreshAlerts() }
    }

    /// Convention Asr (standard / Hanafi).
    func setAsrMethod(_ method: AsrMethod) {
        var calculation = settingsStore.settings.calculation
        calculation.asrMethod = method
        settingsStore.settings.calculation = calculation
        syncCalculationState()
        Task { await refreshAlerts() }
    }

    /// Règle de haute latitude.
    func setHighLatitudeRule(_ rule: HighLatitudeRule) {
        var calculation = settingsStore.settings.calculation
        calculation.highLatitudeRule = rule
        settingsStore.settings.calculation = calculation
        syncCalculationState()
        Task { await refreshAlerts() }
    }

    /// Angles personnalisés : à l'activation, reprend les angles de la
    /// méthode comme point de départ ; à la coupure, les efface.
    /// (Les deux angles sont toujours posés/effacés ensemble.)
    func setUsesCustomAngles(_ enabled: Bool) {
        var calculation = settingsStore.settings.calculation
        if enabled {
            let defaults = calculation.method.defaultPrayerParameters
            calculation.fajrAngleOverride = defaults.fajrAngle
            if case .angle(let angle) = defaults.isha {
                calculation.ishaAngleOverride = angle
            } else {
                calculation.ishaAngleOverride = 17
            }
        } else {
            calculation.fajrAngleOverride = nil
            calculation.ishaAngleOverride = nil
        }
        settingsStore.settings.calculation = calculation
        syncCalculationState()
        Task { await refreshAlerts() }
    }

    /// Angle Fajr personnalisé (borné 5–25°).
    func setFajrAngle(_ angle: Double) {
        var calculation = settingsStore.settings.calculation
        calculation.fajrAngleOverride = min(25, max(5, angle))
        settingsStore.settings.calculation = calculation
        syncCalculationState()
        Task { await refreshAlerts() }
    }

    /// Angle Isha personnalisé (borné 5–25°) ; remplace aussi un
    /// intervalle fixe (Umm al-Qura, Qatar) par un angle.
    func setIshaAngle(_ angle: Double) {
        var calculation = settingsStore.settings.calculation
        calculation.ishaAngleOverride = min(25, max(5, angle))
        settingsStore.settings.calculation = calculation
        syncCalculationState()
        Task { await refreshAlerts() }
    }

    /// Ajustement manuel d'une prière, en minutes (0 = effacé).
    func setManualAdjustment(_ minutes: Int, for prayer: Prayer) {
        var calculation = settingsStore.settings.calculation
        if minutes == 0 {
            calculation.manualAdjustments.removeValue(forKey: prayer)
        } else {
            calculation.manualAdjustments[prayer] = min(120, max(-120, minutes))
        }
        settingsStore.settings.calculation = calculation
        syncCalculationState()
        Task { await refreshAlerts() }
    }

    private func syncCalculationState() {
        let config = settingsStore.settings.calculation
        calculationMethod = config.method
        asrMethod = config.asrMethod
        highLatitudeRule = config.highLatitudeRule
        usesCustomAngles = config.fajrAngleOverride != nil || config.ishaAngleOverride != nil
        let defaults = config.method.defaultPrayerParameters
        fajrAngle = config.fajrAngleOverride ?? defaults.fajrAngle
        if let override = config.ishaAngleOverride {
            ishaAngle = override
        } else if case .angle(let angle) = defaults.isha {
            ishaAngle = angle
        } else {
            ishaAngle = 17
        }
        manualAdjustments = config.manualAdjustments
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
