import Foundation
import Testing

@testable import Adhan_Alarme

@MainActor
struct SettingsViewModelTests {
    private final class MockAudioStore: MuezzinAudioStore {
        var availabilityMap: [String: MuezzinAudioAvailability] = [:]
        var localURLMap: [String: URL] = [:]
        var downloadStream: (Muezzin) -> AsyncThrowingStream<Double, Error> = { _ in
            AsyncThrowingStream { $0.finish() }
        }
        var deletedIDs: [String] = []
        var deleteError: Error?
        func availability(of muezzin: Muezzin) -> MuezzinAudioAvailability {
            availabilityMap[muezzin.id] ?? .unavailable
        }
        func localURL(for muezzin: Muezzin) -> URL? { localURLMap[muezzin.id] }
        func download(_ muezzin: Muezzin) -> AsyncThrowingStream<Double, Error> {
            downloadStream(muezzin)
        }
        func deleteDownload(of muezzin: Muezzin) throws {
            if let deleteError { throw deleteError }
            deletedIDs.append(muezzin.id)
        }
    }

    private final class MockPlayback: AdhanPlaybackService {
        var state: AdhanPlaybackState = .stopped
        var playedIDs: [String] = []
        var playError: Error?
        func playAdhan(_ muezzin: Muezzin) async throws {
            if let playError { throw playError }
            playedIDs.append(muezzin.id)
            state = .playing(muezzinID: muezzin.id)
        }
        func stop() { state = .stopped }
        func pause() {
            if case .playing(let id) = state { state = .paused(muezzinID: id) }
        }
        func resume() {
            if case .paused(let id) = state { state = .playing(muezzinID: id) }
        }
    }

    private struct StubSegments: AdhanSegmentStore {
        var names: [String]?
        func segmentSoundNames(for muezzinID: String) -> [String]? { names }
        func prepareSegments(for muezzin: Muezzin, sourceURL: URL) async throws -> [String] { names ?? [] }
    }

    private final class MockAlertService: PrayerAlertService {
        var status: PrayerAlertAuthorization = .authorized
        var scheduled: [[PrayerAlertRequest]] = []
        var cancelledPrefixes: [String] = []
        func authorizationStatus() async -> PrayerAlertAuthorization { status }
        func requestAuthorization() async -> PrayerAlertAuthorization { status }
        func schedule(_ requests: [PrayerAlertRequest]) async throws { scheduled.append(requests) }
        func cancelAllAlerts() async {}
        func cancelChainedSegments(dayIdentifier: String) async { cancelledPrefixes.append(dayIdentifier) }
    }

    private func makeWorld(
        store: MockAudioStore = MockAudioStore(),
        playback: MockPlayback = MockPlayback(),
        alerts: MockAlertService = MockAlertService(),
        segments: StubSegments = StubSegments()
    ) -> (viewModel: SettingsViewModel, defaults: UserDefaults, alerts: MockAlertService)? {
        guard let defaults = UserDefaults(suiteName: "test.\(UUID().uuidString)") else { return nil }
        let local = LocalCalculationProvider()
        let language = LanguageSettings(settingsStore: UserDefaultsSettingsStore(userDefaults: defaults))
        let viewModel = SettingsViewModel(
            settingsStore: UserDefaultsSettingsStore(userDefaults: defaults),
            audioStore: store,
            playback: playback,
            alertScheduler: SchedulePrayerAlertsUseCase(
                prayerTimes: GetPrayerTimesUseCase(repository: DefaultPrayerTimesRepository(
                    api: local,
                    local: local,
                    cache: PrayerTimesCache(userDefaults: defaults)
                )),
                resolver: StaticLocationResolver(),
                segments: StubSegments()
            ),
            alertService: alerts,
            segments: segments,
            language: language
        )
        return (viewModel, defaults, alerts)
    }

    @Test func selectPersistsMuezzinID() {
        guard let world = makeWorld() else {
            #expect(Bool(false), "réglages inaccessibles")
            return
        }
        let makkah = Muezzin.catalog[0]
        world.viewModel.select(makkah)
        #expect(world.viewModel.selectedMuezzinID == makkah.id)
        let reloaded = UserDefaultsSettingsStore(userDefaults: world.defaults)
        #expect(reloaded.settings.selectedMuezzinID == makkah.id)
    }

    @Test func availabilityMirrorsStore() {
        let store = MockAudioStore()
        store.availabilityMap = ["makkah": .bundled]
        guard let world = makeWorld(store: store) else {
            #expect(Bool(false), "réglages inaccessibles")
            return
        }
        #expect(world.viewModel.availability["makkah"] == .bundled)
        #expect(world.viewModel.availability["madinah"] == .unavailable)
    }

    @Test func togglePlayCyclesThroughPauseAndResume() async {
        guard let world = makeWorld() else {
            #expect(Bool(false), "réglages inaccessibles")
            return
        }
        let makkah = Muezzin.catalog[0]
        await world.viewModel.togglePlay(makkah)
        #expect(world.viewModel.playbackState == .playing(muezzinID: makkah.id))
        await world.viewModel.togglePlay(makkah)
        #expect(world.viewModel.playbackState == .paused(muezzinID: makkah.id))
        await world.viewModel.togglePlay(makkah)
        #expect(world.viewModel.playbackState == .playing(muezzinID: makkah.id))
        world.viewModel.stop()
        #expect(world.viewModel.playbackState == .stopped)
    }

    @Test func playbackErrorsMapToKeys() async {
        let cases: [(AdhanPlaybackError, String)] = [
            (.audioUnavailable(muezzinID: "t"), "audio.error.unavailable"),
            (.remoteSourceNotConfigured(muezzinID: "t"), "audio.error.notConfigured"),
            (.downloadFailed(muezzinID: "t"), "audio.error.downloadFailed"),
            (.audioSessionFailed, "audio.error.sessionFailed"),
            (.fileUnreadable(muezzinID: "t"), "audio.error.unreadable"),
        ]
        for (error, key) in cases {
            let playback = MockPlayback()
            playback.playError = error
            guard let world = makeWorld(playback: playback) else {
                #expect(Bool(false), "réglages inaccessibles")
                return
            }
            await world.viewModel.togglePlay(Muezzin.catalog[0])
            #expect(world.viewModel.errorKey == key)
        }
    }

    @Test func unexpectedPlaybackErrorMapsToFailed() async {
        struct Boom: Error {}
        let playback = MockPlayback()
        playback.playError = Boom()
        guard let world = makeWorld(playback: playback) else {
            #expect(Bool(false), "réglages inaccessibles")
            return
        }
        await world.viewModel.togglePlay(Muezzin.catalog[0])
        #expect(world.viewModel.errorKey == "audio.error.failed")
    }

    @Test func downloadCompletesAndClearsProgress() async {
        let store = MockAudioStore()
        store.downloadStream = { _ in
            AsyncThrowingStream { continuation in
                continuation.yield(0.25)
                continuation.yield(0.75)
                continuation.finish()
            }
        }
        guard let world = makeWorld(store: store) else {
            #expect(Bool(false), "réglages inaccessibles")
            return
        }
        let makkah = Muezzin.catalog[0]
        await world.viewModel.download(makkah)
        #expect(world.viewModel.downloadProgress[makkah.id] == nil)
        #expect(world.viewModel.errorKey == nil)
    }

    @Test func downloadErrorMapsToKey() async {
        let store = MockAudioStore()
        store.downloadStream = { _ in
            AsyncThrowingStream { continuation in
                continuation.finish(throwing: AdhanPlaybackError.downloadFailed(muezzinID: "t"))
            }
        }
        guard let world = makeWorld(store: store) else {
            #expect(Bool(false), "réglages inaccessibles")
            return
        }
        let makkah = Muezzin.catalog[0]
        await world.viewModel.download(makkah)
        #expect(world.viewModel.errorKey == "audio.error.downloadFailed")
        #expect(world.viewModel.downloadProgress[makkah.id] == nil)
    }

    @Test func deleteDownloadRemovesAndStopsActivePlayback() {
        let store = MockAudioStore()
        let playback = MockPlayback()
        playback.state = .playing(muezzinID: "makkah")
        guard let world = makeWorld(store: store, playback: playback) else {
            #expect(Bool(false), "réglages inaccessibles")
            return
        }
        world.viewModel.deleteDownload(Muezzin.catalog[0])
        #expect(store.deletedIDs == ["makkah"])
        #expect(world.viewModel.playbackState == .stopped)
    }

    @Test func enableAlertsGrantsAndSchedules() async {
        guard let world = makeWorld() else {
            #expect(Bool(false), "réglages inaccessibles")
            return
        }
        await world.viewModel.enableAlerts()
        #expect(world.viewModel.alertsEnabled == true)
        #expect(world.alerts.scheduled.count == 1)
        guard let batch = world.alerts.scheduled.first else {
            #expect(Bool(false), "aucune planification")
            return
        }
        #expect(batch.allSatisfy { $0.fireDate > Date() })
        #expect((30...42).contains(batch.count))
    }

    @Test func enableAlertsDeniedKeepsDisabled() async {
        let alerts = MockAlertService()
        alerts.status = .denied
        guard let world = makeWorld(alerts: alerts) else {
            #expect(Bool(false), "réglages inaccessibles")
            return
        }
        await world.viewModel.enableAlerts()
        #expect(world.viewModel.alertsEnabled == false)
        #expect(world.alerts.scheduled.isEmpty)
        #expect(world.viewModel.alertAuthorization == .denied)
    }

    @Test func disableAlertsCancelsThroughEmptySchedule() async {
        guard let world = makeWorld() else {
            #expect(Bool(false), "réglages inaccessibles")
            return
        }
        world.viewModel.disableAlerts()
        for _ in 0..<100 {
            if !world.alerts.scheduled.isEmpty { break }
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        #expect(world.alerts.scheduled.count == 1)
        #expect(world.alerts.scheduled.first?.isEmpty == true)
    }

    @Test func setAlertModeUpdatesSettingsAndReschedules() async {
        guard let world = makeWorld() else {
            #expect(Bool(false), "réglages inaccessibles")
            return
        }
        world.viewModel.setAlertMode(.silent, for: .fajr)
        #expect(world.viewModel.alertModes[.fajr] == .silent)
        for _ in 0..<100 {
            if !world.alerts.scheduled.isEmpty { break }
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        guard let batch = world.alerts.scheduled.first else {
            #expect(Bool(false), "aucune replanification")
            return
        }
        #expect(!batch.contains { $0.prayer == .fajr })
    }

    @Test func setCalculationMethodPersistsAndReschedules() async {
        guard let world = makeWorld() else {
            #expect(Bool(false), "réglages inaccessibles")
            return
        }
        world.viewModel.setCalculationMethod(.uoif)
        #expect(world.viewModel.calculationMethod == .uoif)
        let reloaded = UserDefaultsSettingsStore(userDefaults: world.defaults)
        #expect(reloaded.settings.calculation.method == .uoif)
        for _ in 0..<100 {
            if !world.alerts.scheduled.isEmpty { break }
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        #expect(!world.alerts.scheduled.isEmpty)
    }

    @Test func setAsrAndRulePersist() {
        guard let world = makeWorld() else {
            #expect(Bool(false), "réglages inaccessibles")
            return
        }
        world.viewModel.setAsrMethod(.hanafi)
        world.viewModel.setHighLatitudeRule(.angleBased)
        #expect(world.viewModel.asrMethod == .hanafi)
        #expect(world.viewModel.highLatitudeRule == .angleBased)
        let reloaded = UserDefaultsSettingsStore(userDefaults: world.defaults)
        #expect(reloaded.settings.calculation.asrMethod == .hanafi)
        #expect(reloaded.settings.calculation.highLatitudeRule == .angleBased)
    }

    @Test func customAnglesSeedFromMethodThenClear() {
        guard let world = makeWorld() else {
            #expect(Bool(false), "réglages inaccessibles")
            return
        }
        // Méthode par défaut (MWL : 18/17).
        world.viewModel.setUsesCustomAngles(true)
        #expect(world.viewModel.usesCustomAngles == true)
        #expect(world.viewModel.fajrAngle == 18)
        #expect(world.viewModel.ishaAngle == 17)
        world.viewModel.setFajrAngle(12.5)
        #expect(world.viewModel.fajrAngle == 12.5)
        world.viewModel.setUsesCustomAngles(false)
        #expect(world.viewModel.usesCustomAngles == false)
        let reloaded = UserDefaultsSettingsStore(userDefaults: world.defaults)
        #expect(reloaded.settings.calculation.fajrAngleOverride == nil)
        #expect(reloaded.settings.calculation.ishaAngleOverride == nil)
    }

    @Test func anglesAreClamped() {
        guard let world = makeWorld() else {
            #expect(Bool(false), "réglages inaccessibles")
            return
        }
        world.viewModel.setFajrAngle(99)
        world.viewModel.setIshaAngle(-3)
        #expect(world.viewModel.fajrAngle == 25)
        #expect(world.viewModel.ishaAngle == 5)
    }

    @Test func manualAdjustmentZeroRemoves() {
        guard let world = makeWorld() else {
            #expect(Bool(false), "réglages inaccessibles")
            return
        }
        world.viewModel.setManualAdjustment(5, for: .fajr)
        #expect(world.viewModel.manualAdjustments[.fajr] == 5)
        world.viewModel.setManualAdjustment(0, for: .fajr)
        let reloaded = UserDefaultsSettingsStore(userDefaults: world.defaults)
        #expect(reloaded.settings.calculation.manualAdjustments[.fajr] == nil)
    }

    @Test func longAdhanRequiresDownloadedVoice() async {
        guard let world = makeWorld() else {
            #expect(Bool(false), "réglages inaccessibles")
            return
        }
        await world.viewModel.setLongAdhanEnabled(true)
        #expect(world.viewModel.longAdhanEnabled == false)
        #expect(world.viewModel.errorKey == "settings.alerts.longAdhanNeedsDownload")
    }

    @Test func longAdhanToggleChainsEndToEnd() async {
        let store = MockAudioStore()
        store.localURLMap = ["makkah": URL(filePath: "/tmp/fake-adhan.mp3")]
        let segments = StubSegments(names: ["a.caf", "b.caf"])
        guard let world = makeWorld(store: store, segments: segments) else {
            #expect(Bool(false), "réglages inaccessibles")
            return
        }
        await world.viewModel.setLongAdhanEnabled(true)
        #expect(world.viewModel.longAdhanEnabled == true)
        #expect(world.viewModel.errorKey == nil)
        guard let batch = world.alerts.scheduled.last else {
            #expect(Bool(false), "aucune planification")
            return
        }
        #expect(batch.contains { $0.segmentIndex != nil })
        await world.viewModel.setLongAdhanEnabled(false)
        #expect(world.viewModel.longAdhanEnabled == false)
    }
}
