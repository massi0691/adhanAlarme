import AVFoundation
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
    private let cacheDirectory: URL

    init(
        bundle: Bundle = .main,
        fileManager: FileManager = .default,
        cacheDirectory: URL? = nil
    ) {
        self.bundle = bundle
        self.fileManager = fileManager
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
        return AsyncThrowingStream { continuation in
            guard let remoteURL else {
                continuation.finish(throwing: AdhanPlaybackError.remoteSourceNotConfigured(muezzinID: muezzinID))
                return
            }
            // Session éphémère par transfert : progression native et
            // écriture système directe (aucune boucle octet par octet).
            let delegate = DownloadDelegate(destination: destination, muezzinID: muezzinID, continuation: continuation)
            let session = URLSession(configuration: .ephemeral, delegate: delegate, delegateQueue: nil)
            let task = session.downloadTask(with: remoteURL)
            let canceller = DownloadCanceller(task: task)
            continuation.onTermination = { _ in canceller.cancel() }
            task.resume()
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

    // MARK: - Téléchargement (URLSessionDownloadTask + délégué)

    /// Valide un fichier téléchargé (lisible et jouable), sinon le
    /// supprime et jette `downloadFailed` (l'utilisateur peut réessayer).
    func validateDownload(of muezzin: Muezzin) async throws {
        guard let url = cachedURLIfExists(for: muezzin) else {
            throw AdhanPlaybackError.downloadFailed(muezzinID: muezzin.id)
        }
        let asset = AVURLAsset(url: url)
        let playable = (try? await asset.load(.isPlayable)) ?? false
        guard playable else {
            try? fileManager.removeItem(at: url)
            throw AdhanPlaybackError.downloadFailed(muezzinID: muezzin.id)
        }
    }
}

/// Délégué de téléchargement : progression native + déplacement atomique.
/// `URLSession` retient son délégué ; `finishTasksAndInvalidate` rompt le
/// cycle en fin de transfert (succès, échec ou annulation). Seul état
/// partagé : la continuation (thread-safe par contrat Apple).
private final class DownloadDelegate: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    private let destination: URL
    private let muezzinID: String
    private let continuation: AsyncThrowingStream<Double, Error>.Continuation

    init(destination: URL, muezzinID: String, continuation: AsyncThrowingStream<Double, Error>.Continuation) {
        self.destination = destination
        self.muezzinID = muezzinID
        self.continuation = continuation
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        guard totalBytesExpectedToWrite > 0 else { return }
        continuation.yield(Double(totalBytesWritten) / Double(totalBytesExpectedToWrite))
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        defer { session.finishTasksAndInvalidate() }
        do {
            // Les erreurs HTTP arrivent ici avec un corps : vérifier d'abord.
            if let http = downloadTask.response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                throw URLError(.badServerResponse)
            }
            let manager = FileManager()
            let directory = destination.deletingLastPathComponent()
            try manager.createDirectory(at: directory, withIntermediateDirectories: true)
            // Contenu re-téléchargeable : exclu de la sauvegarde iCloud.
            var excludedDirectory = directory
            var backupValues = URLResourceValues()
            backupValues.isExcludedFromBackup = true
            try? excludedDirectory.setResourceValues(backupValues)
            if manager.fileExists(atPath: destination.path(percentEncoded: false)) {
                try manager.removeItem(at: destination)
            }
            try manager.moveItem(at: location, to: destination)
            continuation.yield(1.0)
            continuation.finish()
        } catch {
            continuation.finish(throwing: AdhanPlaybackError.downloadFailed(muezzinID: muezzinID))
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        defer { session.finishTasksAndInvalidate() }
        guard let error else { return }  // Succès : déjà terminé ci-dessus.
        if (error as? URLError)?.code == .cancelled {
            continuation.finish(throwing: CancellationError())
        } else {
            continuation.finish(throwing: AdhanPlaybackError.downloadFailed(muezzinID: muezzinID))
        }
    }
}

/// Annulation `Sendable` d'une tâche (`URLSessionTask` ne l'est pas).
private final class DownloadCanceller: @unchecked Sendable {
    private let task: URLSessionTask

    init(task: URLSessionTask) {
        self.task = task
    }

    func cancel() {
        task.cancel()
    }
}
