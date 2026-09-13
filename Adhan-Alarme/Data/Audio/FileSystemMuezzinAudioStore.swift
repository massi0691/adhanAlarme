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
        if muezzin.id == Muezzin.customID {
            return customURL() == nil ? .unavailable : .downloaded
        }
        if bundleURL(for: muezzin) != nil { return .bundled }
        if fileManager.fileExists(atPath: cachedURL(for: muezzin).path(percentEncoded: false)) {
            return .downloaded
        }
        if muezzin.remoteURL != nil { return .remoteAvailable }
        return .unavailable
    }

    func localURL(for muezzin: Muezzin) -> URL? {
        if muezzin.id == Muezzin.customID { return customURL() }
        return bundleURL(for: muezzin) ?? cachedURLIfExists(for: muezzin)
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
        if muezzin.id == Muezzin.customID {
            if let url = customURL() {
                try fileManager.removeItem(at: url)
            }
            return
        }
        let url = cachedURL(for: muezzin)
        guard fileManager.fileExists(atPath: url.path(percentEncoded: false)) else { return }
        try fileManager.removeItem(at: url)
    }

    /// Importe un fichier audio personnel (sélecteur Files) : nettoie
    /// l'ancien, copie le nouveau (`custom-adhan.<ext>`), vérifie qu'il
    /// est jouable. Formats : mp3, m4a/aac, wav, caf.
    func importCustomAudio(from sourceURL: URL) async throws {
        let ext = sourceURL.pathExtension.lowercased()
        guard ["mp3", "m4a", "aac", "wav", "caf"].contains(ext) else {
            throw AdhanPlaybackError.downloadFailed(muezzinID: Muezzin.customID)
        }
        let accessing = sourceURL.startAccessingSecurityScopedResource()
        defer { if accessing { sourceURL.stopAccessingSecurityScopedResource() } }
        try Self.prepareDirectory(cacheDirectory)
        if let old = customURL() {
            try? fileManager.removeItem(at: old)
        }
        let destination = cacheDirectory.appendingPathComponent("custom-adhan.\(ext)")
        try fileManager.copyItem(at: sourceURL, to: destination)
        Self.relaxProtection(destination)
        guard await Self.isPlayable(url: destination) else {
            try? fileManager.removeItem(at: destination)
            throw AdhanPlaybackError.downloadFailed(muezzinID: Muezzin.customID)
        }
    }

    /// Fichier personnel importé (`custom-adhan.*`), `nil` si aucun.
    private func customURL() -> URL? {
        let files = (try? fileManager.contentsOfDirectory(atPath: cacheDirectory.path(percentEncoded: false))) ?? []
        guard let name = files.first(where: { $0.hasPrefix("custom-adhan.") }) else { return nil }
        let url = cacheDirectory.appendingPathComponent(name)
        Self.ensureMediaProtection(url)
        return url
    }

    /// Crée le dossier + exclusion sauvegarde (partagé import/téléchargement).
    nonisolated static func prepareDirectory(_ directory: URL) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var excluded = directory
        var backupValues = URLResourceValues()
        backupValues.isExcludedFromBackup = true
        try? excluded.setResourceValues(backupValues)
        // Lisible après le premier déverrouillage : la lecture survit
        // à l'extinction de l'écran (cause connue de coupure audio).
        relaxProtection(directory)
    }

    /// Protection « lisible après 1er déverrouillage » sur un fichier
    /// ou dossier (`fileProtection` est en lecture seule sur
    /// `URLResourceValues` : on passe par `FileManager.setAttributes`).
    nonisolated static func relaxProtection(_ url: URL) {
        try? FileManager.default.setAttributes(
            [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
            ofItemAtPath: url.path(percentEncoded: false)
        )
    }

    /// Aligne un fichier existant sur la protection média (migration
    /// paresseuse : les voix déjà téléchargées sont corrigées au fil
    /// des lectures, sans re-téléchargement).
    nonisolated static func ensureMediaProtection(_ url: URL) {
        let current = (try? url.resourceValues(forKeys: [.fileProtectionKey]))?.fileProtection
        guard current != .completeUntilFirstUserAuthentication, current != nil else { return }
        relaxProtection(url)
    }

    /// Sonde de lisibilité partagée (import + validation).
    private static func isPlayable(url: URL) async -> Bool {
        (try? await AVURLAsset(url: url).load(.isPlayable)) ?? false
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
        guard fileManager.fileExists(atPath: url.path(percentEncoded: false)) else { return nil }
        Self.ensureMediaProtection(url)
        return url
    }

    // MARK: - Téléchargement (URLSessionDownloadTask + délégué)

    /// Valide un fichier téléchargé (lisible et jouable), sinon le
    /// supprime et jette `downloadFailed` (l'utilisateur peut réessayer).
    func validateDownload(of muezzin: Muezzin) async throws {
        guard let url = cachedURLIfExists(for: muezzin) else {
            throw AdhanPlaybackError.downloadFailed(muezzinID: muezzin.id)
        }
        guard await Self.isPlayable(url: url) else {
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
    // Écrits dans `init`, jamais mutés ensuite : partage sûr avec les
    // callbacks non isolés (même contrat que `CompletionBox`).
    private let destination: URL
    private let muezzinID: String
    private nonisolated(unsafe) let continuation: AsyncThrowingStream<Double, Error>.Continuation

    nonisolated init(destination: URL, muezzinID: String, continuation: AsyncThrowingStream<Double, Error>.Continuation) {
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
            try FileSystemMuezzinAudioStore.prepareDirectory(directory)
            if manager.fileExists(atPath: destination.path(percentEncoded: false)) {
                try manager.removeItem(at: destination)
            }
            try manager.moveItem(at: location, to: destination)
            FileSystemMuezzinAudioStore.relaxProtection(destination)
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
    // Écrit dans `init`, jamais muté ensuite : partage sûr.
    private let task: URLSessionTask

    nonisolated init(task: URLSessionTask) {
        self.task = task
    }

    nonisolated func cancel() {
        task.cancel()
    }
}
