import Foundation
import Testing

@testable import Adhan_Alarme

@MainActor
struct SettingsViewModelTests {
    private final class MockAudioStore: MuezzinAudioStore {
        var availabilityMap: [String: MuezzinAudioAvailability] = [:]
        var downloadStream: (Muezzin) -> AsyncThrowingStream<Double, Error> = { _ in
            AsyncThrowingStream { $0.finish() }
        }
        var deletedIDs: [String] = []
        var deleteError: Error?
        func availability(of muezzin: Muezzin) -> MuezzinAudioAvailability {
            availabilityMap[muezzin.id] ?? .unavailable
        }
        func localURL(for muezzin: Muezzin) -> URL? { nil }
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

    private final class MockAlertService: PrayerAlertService {
        var status: PrayerAlertAuthorization = .authorized
        var scheduled: [[PrayerAlertRequest]] = []
        func authorizationStatus() async -> PrayerAlertAuthorization { status }
        func requestAuthorization() async -> PrayerAlertAuthorization { status }
        func schedule(_ requests: [PrayerAlertRequest]) async throws { scheduled.append(requests) }
        func cancelAllAlerts() async {}
    }

    private func makeWorld(
        store: MockAudioStore = MockAudioStore(),
        playback: MockPlayback = MockPlayback(),
        alerts: MockAlertService = MockAlertService()
    ) -> (viewModel: SettingsViewModel, defaults: UserDefaults, alerts: MockAlertService)? {
        guard let defaults = UserDefaults(suiteName: "test.\(UUID().uuidString)") else { return nil }
        let local = LocalCalculationProvider()
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
                resolver: StaticLocationResolver()
            ),
            alertService: alerts
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
}
