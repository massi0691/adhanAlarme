import Foundation

/// Stockage audio : bundle embarqué + `Application Support/Adhan`
/// (exclu de la sauvegarde : contenu re-téléchargeable).
/// Téléchargement au premier plan avec progression (pas de session
/// d'arrière-plan en v1 : fichiers de quelques Mo, app ouverte pendant
/// le transfert). Le producteur du téléchargement ne capture que des
/// valeurs `Sendable` (aucune référence à `self`).
@MainActor
final class FileSystemMuezzinAudioStore: MuezzinAudioStore {
    private let bundle: Bundle
    private let fileManager: FileManager
    private let session: URLSession
    private let cacheDirectory: URL

    init(
        bundle: Bundle = .main,
        fileManager: FileManager = .default,
        session: URLSession = .shared,
        cacheDirectory: URL? = nil
    ) {
        self.bundle = bundle
        self.fileManager = fileManager
        self.session = session
        if let cacheDirectory {
            self.cacheDirectory = cacheDirectory
        } else {
            let support = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? fileManager.temporaryDirectory
            self.cacheDirectory = support.appendingPathComponent("Adhan", isDirectory: true)
        }
    }

    func availability(of muezzin: Muezzin) -> MuezzinAudioAvailability {
        if bundleURL(for: muezzin) != nil { return .bundled }
        if fileManager.fileExists(atPath: cachedURL(for: muezzin).path(percentEncoded: false)) {
            return .downloaded
        }
        if muezzin.remoteURL != nil { return .remoteAvailable }
        return .unavailable
    }

    func localURL(for muezzin: Muezzin) -> URL? {
        bundleURL(for: muezzin) ?? cachedURLIfExists(for: muezzin)
    }

    func download(_ muezzin: Muezzin) -> AsyncThrowingStream<Double, Error> {
        let muezzinID = muezzin.id
        let remoteURL = muezzin.remoteURL
        let destination = cachedURL(for: muezzin)
        let session = session
        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    guard let remoteURL else {
                        throw AdhanPlaybackError.remoteSourceNotConfigured(muezzinID: muezzinID)
                    }
                    try await Self.performDownload(from: remoteURL, to: destination, session: session) { progress in
                        continuation.yield(progress)
                    }
                    continuation.yield(1.0)
                    continuation.finish()
                } catch is CancellationError {
                    try? FileManager.default.removeItem(at: destination.appendingPathExtension("part"))
                    continuation.finish(throwing: CancellationError())
                } catch {
                    try? FileManager.default.removeItem(at: destination.appendingPathExtension("part"))
                    continuation.finish(throwing: AdhanPlaybackError.downloadFailed(muezzinID: muezzinID))
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    func deleteDownload(of muezzin: Muezzin) throws {
        let url = cachedURL(for: muezzin)
        guard fileManager.fileExists(atPath: url.path(percentEncoded: false)) else { return }
        try fileManager.removeItem(at: url)
    }

    // MARK: - Résolution

    private func bundleURL(for muezzin: Muezzin) -> URL? {
        let name = (muezzin.audioFile as NSString).deletingPathExtension
        let ext = (muezzin.audioFile as NSString).pathExtension
        return bundle.url(forResource: name, withExtension: ext.isEmpty ? nil : ext)
    }

    private func cachedURL(for muezzin: Muezzin) -> URL {
        cacheDirectory.appendingPathComponent(muezzin.audioFile)
    }

    private func cachedURLIfExists(for muezzin: Muezzin) -> URL? {
        let url = cachedURL(for: muezzin)
        return fileManager.fileExists(atPath: url.path(percentEncoded: false)) ? url : nil
    }

    // MARK: - Téléchargement (statique : aucune capture de `self`)

    private static func performDownload(
        from remoteURL: URL,
        to destination: URL,
        session: URLSession,
        onProgress: @Sendable (Double) -> Void
    ) async throws {
        let manager = FileManager()
        let directory = destination.deletingLastPathComponent()
        try manager.createDirectory(at: directory, withIntermediateDirectories: true)
        // Contenu re-téléchargeable : exclu de la sauvegarde iCloud.
        var excludedDirectory = directory
        var backupValues = URLResourceValues()
        backupValues.isExcludedFromBackup = true
        try? excludedDirectory.setResourceValues(backupValues)

        let (bytes, response) = try await session.bytes(from: remoteURL)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        let expected = http.expectedContentLength
        let tempURL = destination.appendingPathExtension("part")
        guard manager.createFile(atPath: tempURL.path(percentEncoded: false), contents: nil) else {
            throw URLError(.cannotCreateFile)
        }
        guard let handle = FileHandle(forWritingAtPath: tempURL.path(percentEncoded: false)) else {
            throw URLError(.cannotOpenFile)
        }
        defer { try? handle.close() }
        do {
            // Écriture par blocs de 64 Ko (jamais octet par octet).
            var buffer = Data()
            buffer.reserveCapacity(65536)
            var received: Int64 = 0
            for try await byte in bytes {
                try Task.checkCancellation()
                buffer.append(byte)
                received += 1
                if buffer.count >= 65536 {
                    try handle.write(contentsOf: buffer)
                    buffer.removeAll(keepingCapacity: true)
                    if expected > 0 {
                        onProgress(Double(received) / Double(expected))
                    }
                }
            }
            if !buffer.isEmpty {
                try handle.write(contentsOf: buffer)
            }
            try handle.close()
            if manager.fileExists(atPath: destination.path(percentEncoded: false)) {
                try manager.removeItem(at: destination)
            }
            try manager.moveItem(at: tempURL, to: destination)
        } catch {
            try? manager.removeItem(at: tempURL)
            throw error
        }
    }
}
