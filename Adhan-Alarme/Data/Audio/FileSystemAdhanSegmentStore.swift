import AVFoundation
import Foundation

/// Segments de 30 s pour l'Adhan long (hack expérimental, opt-in).
/// Découpe le fichier complet en `.caf` IMA4 dans `Library/Sounds`
/// (format garanti lisible par le système de sons iOS).
/// Découpage idempotent, exécuté hors MainActor.
@MainActor
final class FileSystemAdhanSegmentStore: AdhanSegmentStore {
    /// Durée max d'un son de notification iOS.
    nonisolated static let segmentLength: TimeInterval = 30

    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func segmentSoundNames(for muezzinID: String) -> [String]? {
        guard let directory = soundsDirectory() else { return nil }
        let prefix = Self.prefix(for: muezzinID)
        let files = (try? fileManager.contentsOfDirectory(atPath: directory.path(percentEncoded: false))) ?? []
        let matches = files
            .filter { $0.hasPrefix(prefix) && $0.hasSuffix(".caf") }
            .sorted { Self.segmentIndex(of: $0) < Self.segmentIndex(of: $1) }
        return matches.isEmpty ? nil : matches
    }

    func prepareSegments(for muezzin: Muezzin, sourceURL: URL) async throws -> [String] {
        if let existing = segmentSoundNames(for: muezzin.id) { return existing }
        guard let directory = soundsDirectory(createIfNeeded: true) else {
            throw AdhanPlaybackError.fileUnreadable(muezzinID: muezzin.id)
        }
        return try await Task.detached(priority: .utility) {
            try Self.slice(sourceURL: sourceURL, muezzinID: muezzin.id, soundsDirectory: directory)
        }.value
    }

    // MARK: - Privé

    nonisolated private static func prefix(for muezzinID: String) -> String {
        "adhan-\(muezzinID)-s"
    }

    /// Index du segment (`adhan-<id>-s<k>.caf`, `<id>` pouvant contenir
    /// des tirets : parsé depuis la fin).
    nonisolated private static func segmentIndex(of fileName: String) -> Int {
        let base = fileName.hasSuffix(".caf") ? String(fileName.dropLast(4)) : fileName
        guard let range = base.range(of: "-s", options: .backwards) else { return 0 }
        return Int(base[range.upperBound...]) ?? 0
    }

    private func soundsDirectory(createIfNeeded: Bool = false) -> URL? {
        guard let library = fileManager.urls(for: .libraryDirectory, in: .userDomainMask).first else { return nil }
        let directory = library.appendingPathComponent("Sounds", isDirectory: true)
        if createIfNeeded {
            try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        return directory
    }

    private nonisolated static func slice(
        sourceURL: URL,
        muezzinID: String,
        soundsDirectory: URL
    ) throws -> [String] {
        let source: AVAudioFile
        do {
            source = try AVAudioFile(forReading: sourceURL)
        } catch {
            throw AdhanPlaybackError.fileUnreadable(muezzinID: muezzinID)
        }
        let format = source.processingFormat
        let framesPerSegment = AVAudioFrameCount(segmentLength * format.sampleRate)
        let totalFrames = source.length
        var names: [String] = []
        var index = 0
        var position: AVAudioFramePosition = 0
        source.framePosition = 0
        while position < totalFrames {
            let count = min(framesPerSegment, AVAudioFrameCount(totalFrames - position))
            guard count > 0,
                  let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: count) else {
                throw AdhanPlaybackError.fileUnreadable(muezzinID: muezzinID)
            }
            do {
                try source.read(into: buffer, frameCount: count)
            } catch {
                throw AdhanPlaybackError.fileUnreadable(muezzinID: muezzinID)
            }
            let name = "\(prefix(for: muezzinID))\(index).caf"
            let settings: [String: Any] = [
                AVFormatIDKey: kAudioFormatAppleIMA4,
                AVSampleRateKey: format.sampleRate,
                AVNumberOfChannelsKey: format.channelCount,
            ]
            do {
                let file = try AVAudioFile(
                    forWriting: soundsDirectory.appendingPathComponent(name),
                    settings: settings
                )
                try file.write(from: buffer)
            } catch {
                throw AdhanPlaybackError.fileUnreadable(muezzinID: muezzinID)
            }
            names.append(name)
            index += 1
            position += AVAudioFramePosition(count)
        }
        return names
    }
}
