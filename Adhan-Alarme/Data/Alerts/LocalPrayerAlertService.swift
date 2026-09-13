import Foundation
import UserNotifications

extension PrayerAlertAuthorization {
    init(_ status: UNAuthorizationStatus) {
        switch status {
        case .authorized: self = .authorized
        case .denied: self = .denied
        case .notDetermined: self = .notDetermined
        case .provisional: self = .authorized
        case .ephemeral: self = .authorized
        @unknown default: self = .notDetermined
        }
    }
}

/// Alertes système via `UNUserNotificationCenter` (local uniquement).
/// Catégorie « Écouter » enregistrée à l'init (locale appareil au
/// lancement ; aucun sélecteur in-app avant la phase 6).
@MainActor
final class LocalPrayerAlertService: PrayerAlertService {
    private let center: UNUserNotificationCenter

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
        registerCategories()
    }

    func authorizationStatus() async -> PrayerAlertAuthorization {
        PrayerAlertAuthorization(await center.notificationSettings().authorizationStatus)
    }

    func requestAuthorization() async -> PrayerAlertAuthorization {
        do {
            _ = try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            // Rare : relit le statut réel ci-dessous.
        }
        return await authorizationStatus()
    }

    func schedule(_ requests: [PrayerAlertRequest]) async throws {
        guard await authorizationStatus().canSchedule else {
            throw PrayerAlertError.permissionDenied
        }
        await cancelAllAlerts()
        // Garde-fou limite iOS (le use case produit ≤ 42).
        let capped = Array(requests.prefix(64))
        let soundName = customSoundName()
        for request in capped {
            let content = PrayerAlertContentFactory.content(
                for: request,
                localize: { Bundle.main.localizedString(forKey: $0, value: nil, table: nil) },
                customSoundName: soundName
            )
            let unRequest = PrayerAlertRequestMapper.unRequest(for: request, content: content)
            do {
                try await center.add(unRequest)
            } catch {
                throw PrayerAlertError.schedulingFailed
            }
        }
    }

    func cancelAllAlerts() async {
        center.removeAllPendingNotificationRequests()
    }

    func cancelChainedSegments(dayIdentifier: String) async {
        let pending = await center.pendingNotificationRequests()
        let identifiers = pending.map(\.identifier).filter { $0.hasPrefix(dayIdentifier) }
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    // MARK: - Privé

    private func registerCategories() {
        let title = Bundle.main.localizedString(forKey: "alert.action.listen", value: nil, table: nil)
        let listen = UNNotificationAction(
            identifier: PrayerAlertCategories.listenAction,
            title: title,
            options: [.foreground]
        )
        let category = UNNotificationCategory(
            identifier: PrayerAlertCategories.adhan,
            actions: [listen],
            intentIdentifiers: [],
            options: []
        )
        center.setNotificationCategories([category])
    }

    /// Extrait custom `adhan-short.caf` (< 30 s, bundle ou `Library/Sounds`),
    /// `nil` sinon → son système. Voir `Resources/Adhan/README.md`.
    private func customSoundName() -> String? {
        if Bundle.main.url(forResource: "adhan-short", withExtension: "caf") != nil {
            return "adhan-short.caf"
        }
        if let library = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first {
            let url = library.appendingPathComponent("Sounds/adhan-short.caf")
            if FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) {
                return "adhan-short.caf"
            }
        }
        return nil
    }
}
