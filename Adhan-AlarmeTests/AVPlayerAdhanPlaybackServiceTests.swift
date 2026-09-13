import AVFoundation
import Foundation
import Testing

@testable import Adhan_Alarme

/// Moteur réel + store bouchonné. Fichiers WAV de silence synthétisés
/// en code (aucun binaire dans le repo) pour les chemins de lecture.
@MainActor
struct AVPlayerAdhanPlaybackServiceTests {
    private final class StubAudioStore: MuezzinAudioStore {
        var local: URL?
        func availability(of muezzin: Muezzin) -> MuezzinAudioAvailability { .unavailable }
        func localURL(for muezzin: Muezzin) -> URL? { local }
        func download(_ muezzin: Muezzin) -> AsyncThrowingStream<Double, Error> {
            AsyncThrowingStream { $0.finish() }
        }
        func deleteDownload(of muezzin: Muezzin) throws {}
    }

    private func voice(remoteURL: URL? = nil) -> Muezzin {
        Muezzin(id: "test", name: "Test", audioFile: "test.wav", remoteURL: remoteURL, language: nil, duration: nil)
    }

    /// WAV PCM 8 kHz mono silencieux (en-tête 44 octets + échantillons).
    private func silentWAVFile(duration: TimeInterval) throws -> URL {
        let sampleRate = 8000
        let samples = Int(duration * Double(sampleRate))
        var data = Data()
        func append(_ text: String) { data.append(contentsOf: text.utf8) }
        func append32(_ value: UInt32) {
            var little = value.littleEndian
            withUnsafeBytes(of: &little) { data.append(contentsOf: $0) }
        }
        func append16(_ value: UInt16) {
            var little = value.littleEndian
            withUnsafeBytes(of: &little) { data.append(contentsOf: $0) }
        }
        append("RIFF")
        append32(UInt32(36 + samples * 2))
        append("WAVE")
        append("fmt ")
        append32(16)
        append16(1)
        append16(1)
        append32(UInt32(sampleRate))
        append32(UInt32(sampleRate * 2))
        append16(2)
        append16(16)
        append("data")
        append32(UInt32(samples * 2))
        data.append(contentsOf: repeatElement(UInt8(0), count: samples * 2))
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("wav")
        try data.write(to: url)
        return url
    }

    @Test func missingLocalWithoutRemoteThrowsNotConfigured() async {
        let service = AVPlayerAdhanPlaybackService(audioStore: StubAudioStore())
        do {
            try await service.playAdhan(voice())
            #expect(Bool(false), "aurait dû jeter")
        } catch let error as AdhanPlaybackError {
            #expect(error == .remoteSourceNotConfigured(muezzinID: "test"))
        } catch {
            #expect(Bool(false), "mauvais type d'erreur")
        }
        #expect(service.state == .stopped)
    }

    @Test func missingLocalWithRemoteThrowsUnavailable() async {
        guard let remote = URL(string: "https://example.com/test.mp3") else {
            #expect(Bool(false), "URL invalide")
            return
        }
        let service = AVPlayerAdhanPlaybackService(audioStore: StubAudioStore())
        do {
            try await service.playAdhan(voice(remoteURL: remote))
            #expect(Bool(false), "aurait dû jeter")
        } catch let error as AdhanPlaybackError {
            #expect(error == .audioUnavailable(muezzinID: "test"))
        } catch {
            #expect(Bool(false), "mauvais type d'erreur")
        }
        #expect(service.state == .stopped)
    }

    @Test func unreadableFileThrowsFileUnreadable() async throws {
        let garbage = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: garbage) }
        try ("pas du audio".data(using: .utf8) ?? Data()).write(to: garbage)
        let stub = StubAudioStore()
        stub.local = garbage
        let service = AVPlayerAdhanPlaybackService(audioStore: stub)
        do {
            try await service.playAdhan(voice())
            #expect(Bool(false), "aurait dû jeter")
        } catch let error as AdhanPlaybackError {
            #expect(error == .fileUnreadable(muezzinID: "test"))
        } catch {
            #expect(Bool(false), "mauvais type d'erreur")
        }
        #expect(service.state == .stopped)
    }

    @Test func validFilePlaysPausesResumesAndStops() async throws {
        let file = try silentWAVFile(duration: 5)
        defer { try? FileManager.default.removeItem(at: file) }
        let stub = StubAudioStore()
        stub.local = file
        let service = AVPlayerAdhanPlaybackService(audioStore: stub)
        try await service.playAdhan(voice())
        #expect(service.state == .playing(muezzinID: "test"))
        service.pause()
        #expect(service.state == .paused(muezzinID: "test"))
        service.resume()
        #expect(service.state == .playing(muezzinID: "test"))
        service.stop()
        #expect(service.state == .stopped)
    }

    @Test func pauseResumeStopAreNoOpsWhenStopped() {
        let service = AVPlayerAdhanPlaybackService(audioStore: StubAudioStore())
        service.pause()
        service.resume()
        service.stop()
        #expect(service.state == .stopped)
    }

    @Test func playbackEndReturnsToStopped() async throws {
        let file = try silentWAVFile(duration: 0.3)
        defer { try? FileManager.default.removeItem(at: file) }
        let stub = StubAudioStore()
        stub.local = file
        let service = AVPlayerAdhanPlaybackService(audioStore: stub)
        try await service.playAdhan(voice())
        #expect(service.state == .playing(muezzinID: "test"))
        try await Task.sleep(for: .seconds(1))
        #expect(service.state == .stopped)
    }

    @Test func interruptionPausesAndResumes() async throws {
        let file = try silentWAVFile(duration: 30)
        defer { try? FileManager.default.removeItem(at: file) }
        let stub = StubAudioStore()
        stub.local = file
        let service = AVPlayerAdhanPlaybackService(audioStore: stub)
        try await service.playAdhan(voice())
        #expect(service.state == .playing(muezzinID: "test"))
        NotificationCenter.default.post(
            name: AVAudioSession.interruptionNotification,
            object: nil,
            userInfo: [AVAudioSessionInterruptionTypeKey: AVAudioSession.InterruptionType.began.rawValue]
        )
        try await Task.sleep(for: .milliseconds(300))
        #expect(service.state == .paused(muezzinID: "test"))
        NotificationCenter.default.post(
            name: AVAudioSession.interruptionNotification,
            object: nil,
            userInfo: [
                AVAudioSessionInterruptionTypeKey: AVAudioSession.InterruptionType.ended.rawValue,
                AVAudioSessionInterruptionOptionKey: AVAudioSession.InterruptionOptions.shouldResume.rawValue,
            ]
        )
        try await Task.sleep(for: .milliseconds(300))
        #expect(service.state == .playing(muezzinID: "test"))
        service.stop()
    }

    @Test func interruptionWhileStoppedDoesNothing() async throws {
        let service = AVPlayerAdhanPlaybackService(audioStore: StubAudioStore())
        NotificationCenter.default.post(
            name: AVAudioSession.interruptionNotification,
            object: nil,
            userInfo: [AVAudioSessionInterruptionTypeKey: AVAudioSession.InterruptionType.began.rawValue]
        )
        try await Task.sleep(for: .milliseconds(200))
        #expect(service.state == .stopped)
        NotificationCenter.default.post(
            name: AVAudioSession.interruptionNotification,
            object: nil,
            userInfo: [
                AVAudioSessionInterruptionTypeKey: AVAudioSession.InterruptionType.ended.rawValue,
                AVAudioSessionInterruptionOptionKey: AVAudioSession.InterruptionOptions.shouldResume.rawValue,
            ]
        )
        try await Task.sleep(for: .milliseconds(200))
        #expect(service.state == .stopped)
    }

    @Test func headphoneUnplugPauses() async throws {
        let file = try silentWAVFile(duration: 30)
        defer { try? FileManager.default.removeItem(at: file) }
        let stub = StubAudioStore()
        stub.local = file
        let service = AVPlayerAdhanPlaybackService(audioStore: stub)
        try await service.playAdhan(voice())
        #expect(service.state == .playing(muezzinID: "test"))
        NotificationCenter.default.post(
            name: AVAudioSession.routeChangeNotification,
            object: nil,
            userInfo: [AVAudioSessionRouteChangeReasonKey: AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue]
        )
        try await Task.sleep(for: .milliseconds(300))
        #expect(service.state == .paused(muezzinID: "test"))
        service.stop()
    }
}
