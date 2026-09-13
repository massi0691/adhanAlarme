import Foundation
import Testing

@testable import Adhan_Alarme

@MainActor
struct FileSystemMuezzinAudioStoreTests {
    private func voice(remoteURL: URL? = nil) -> Muezzin {
        Muezzin(id: "test", name: "Test", audioFile: "test.mp3", remoteURL: remoteURL, language: nil, duration: nil)
    }

    private func tempDir() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func writeDummy(_ text: String, to url: URL) throws {
        try (text.data(using: .utf8) ?? Data()).write(to: url)
    }

    @Test func unavailableWhenNothingConfigured() throws {
        let cache = try tempDir()
        defer { try? FileManager.default.removeItem(at: cache) }
        let store = FileSystemMuezzinAudioStore(cacheDirectory: cache)
        #expect(store.availability(of: voice()) == .unavailable)
        #expect(store.localURL(for: voice()) == nil)
    }

    @Test func remoteAvailableWhenURLConfigured() throws {
        guard let remote = URL(string: "https://example.com/test.mp3") else {
            #expect(Bool(false), "URL invalide")
            return
        }
        let cache = try tempDir()
        defer { try? FileManager.default.removeItem(at: cache) }
        let store = FileSystemMuezzinAudioStore(cacheDirectory: cache)
        #expect(store.availability(of: voice(remoteURL: remote)) == .remoteAvailable)
    }

    @Test func downloadedWhenFileInCache() throws {
        let cache = try tempDir()
        defer { try? FileManager.default.removeItem(at: cache) }
        let fileURL = cache.appendingPathComponent("test.mp3")
        try writeDummy("cache", to: fileURL)
        let store = FileSystemMuezzinAudioStore(cacheDirectory: cache)
        #expect(store.availability(of: voice()) == .downloaded)
        #expect(store.localURL(for: voice()) == fileURL)
    }

    @Test func bundledPrefersBundleOverCache() throws {
        let bundleDir = try tempDir()
        defer { try? FileManager.default.removeItem(at: bundleDir) }
        let cache = try tempDir()
        defer { try? FileManager.default.removeItem(at: cache) }
        let bundleFile = bundleDir.appendingPathComponent("test.mp3")
        try writeDummy("bundle", to: bundleFile)
        try writeDummy("cache", to: cache.appendingPathComponent("test.mp3"))
        let bundle = Bundle(url: bundleDir)
        let store = FileSystemMuezzinAudioStore(bundle: bundle, cacheDirectory: cache)
        #expect(store.availability(of: voice()) == .bundled)
        #expect(store.localURL(for: voice()) == bundleFile)
    }

    @Test func deleteDownloadRemovesCachedFile() throws {
        let cache = try tempDir()
        defer { try? FileManager.default.removeItem(at: cache) }
        try writeDummy("cache", to: cache.appendingPathComponent("test.mp3"))
        let store = FileSystemMuezzinAudioStore(cacheDirectory: cache)
        try store.deleteDownload(of: voice())
        #expect(store.availability(of: voice()) == .unavailable)
    }

    @Test func deleteDownloadIsIdempotent() throws {
        let cache = try tempDir()
        defer { try? FileManager.default.removeItem(at: cache) }
        let store = FileSystemMuezzinAudioStore(cacheDirectory: cache)
        try store.deleteDownload(of: voice())
        #expect(store.availability(of: voice()) == .unavailable)
    }

    @Test func downloadWithoutRemoteURLThrowsNotConfigured() async throws {
        let cache = try tempDir()
        defer { try? FileManager.default.removeItem(at: cache) }
        let store = FileSystemMuezzinAudioStore(cacheDirectory: cache)
        do {
            for try await _ in store.download(voice()) {
                Issue.record("aucune valeur attendue")
            }
            #expect(Bool(false), "aurait dû jeter")
        } catch let error as AdhanPlaybackError {
            #expect(error == .remoteSourceNotConfigured(muezzinID: "test"))
        } catch {
            #expect(Bool(false), "mauvais type d'erreur")
        }
    }

    @Test func downloadFailureMapsToDownloadFailed() async throws {
        let cache = try tempDir()
        defer { try? FileManager.default.removeItem(at: cache) }
        // Port fermé en local : échec immédiat, aucun réseau requis.
        guard let remote = URL(string: "http://127.0.0.1:1/test.mp3") else {
            #expect(Bool(false), "URL invalide")
            return
        }
        let store = FileSystemMuezzinAudioStore(cacheDirectory: cache)
        do {
            for try await _ in store.download(voice(remoteURL: remote)) {
                Issue.record("aucune valeur attendue")
            }
            #expect(Bool(false), "aurait dû jeter")
        } catch let error as AdhanPlaybackError {
            #expect(error == .downloadFailed(muezzinID: "test"))
        } catch {
            #expect(Bool(false), "mauvais type d'erreur")
        }
        #expect(store.localURL(for: voice(remoteURL: remote)) == nil)
        let partPath = cache.appendingPathComponent("test.mp3.part").path(percentEncoded: false)
        #expect(FileManager.default.fileExists(atPath: partPath) == false)
    }

    @Test func validateDownloadRemovesUnreadableFile() async throws {
        let cache = try tempDir()
        defer { try? FileManager.default.removeItem(at: cache) }
        try writeDummy("not audio", to: cache.appendingPathComponent("test.mp3"))
        let store = FileSystemMuezzinAudioStore(cacheDirectory: cache)
        do {
            try await store.validateDownload(of: voice())
            #expect(Bool(false), "aurait dû jeter")
        } catch let error as AdhanPlaybackError {
            #expect(error == .downloadFailed(muezzinID: "test"))
        } catch {
            #expect(Bool(false), "mauvais type d'erreur")
        }
        #expect(store.localURL(for: voice()) == nil)
    }
}
