import Foundation
import UserNotifications

/// Boîte `Sendable` pour les completion handlers système (contrat Apple :
/// appelables depuis n'importe quel thread, exactement une fois).
private struct CompletionBox<Value>: @unchecked Sendable {
    // Écrit une fois à l'init, jamais muté ensuite : partage sûr
    // (même contrat Apple que la boîte : handler appelable partout).
    private nonisolated(unsafe) let handler: (Value) -> Void

    nonisolated init(_ handler: @escaping (Value) -> Void) {
        self.handler = handler
    }

    func call(_ value: Value) {
        handler(value)
    }
}

private extension CompletionBox where Value == Void {
    func call() {
        handler(())
    }
}

/// Réponses aux notifications : lecture auto quand l'app est ouverte à
/// l'heure (la bannière est alors supprimée — l'Adhan EST l'alerte),
/// action « Écouter » sinon. Tap du corps : ouvre l'app, sans lecture.
/// Valeurs `userInfo` extraites AVANT le saut MainActor (`Sendable`).
@MainActor
final class PrayerAlertActionHandler: NSObject, UNUserNotificationCenterDelegate {
    private let playback: any AdhanPlaybackService
    private let alerts: any PrayerAlertService

    init(playback: any AdhanPlaybackService, alerts: any PrayerAlertService) {
        self.playback = playback
        self.alerts = alerts
        super.init()
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let info = notification.request.content.userInfo
        let mode = info[PrayerAlertUserInfo.mode] as? String
        let muezzinID = info[PrayerAlertUserInfo.muezzinID] as? String
        let prayer = info[PrayerAlertUserInfo.prayer] as? String
        let fireInterval = info[PrayerAlertUserInfo.fireDate] as? Double
        let completion = CompletionBox(completionHandler)
        Task { @MainActor in
            let playsAdhan = mode == PrayerAlertMode.adhan.rawValue
            let muezzin = muezzinID.flatMap(Muezzin.withID) ?? Muezzin.withID(Muezzin.defaultID)
            if playsAdhan, let muezzin {
                // App ouverte : lecture complète, pas de bannière. Les segments
                // ne sont annulés qu'APRÈS un démarrage réussi (sinon la
                // chaîne de secours continue et l'Adhan reste audible).
                do {
                    try await self.playback.playAdhan(muezzin)
                    await self.cancelRemainingSegments(prayer: prayer, fireInterval: fireInterval)
                    completion.call([])
                    return
                } catch {
                    // Repli bannière ci-dessous (chaîne intacte).
                }
            } else if !playsAdhan {
                // Notification simple : rien à chaîner (annulation de sûreté).
                await self.cancelRemainingSegments(prayer: prayer, fireInterval: fireInterval)
            }
            completion.call([.banner, .sound])
        }
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let action = response.actionIdentifier
        let info = response.notification.request.content.userInfo
        let muezzinID = info[PrayerAlertUserInfo.muezzinID] as? String
        let prayer = info[PrayerAlertUserInfo.prayer] as? String
        let fireInterval = info[PrayerAlertUserInfo.fireDate] as? Double
        let completion = CompletionBox<Void>(completionHandler)
        Task { @MainActor in
            // Toute interaction annule les segments restants.
            await self.cancelRemainingSegments(prayer: prayer, fireInterval: fireInterval)
            if action == PrayerAlertCategories.listenAction,
               let muezzin = muezzinID.flatMap(Muezzin.withID) ?? Muezzin.withID(Muezzin.defaultID) {
                do {
                    try await self.playback.playAdhan(muezzin)
                } catch {
                    await self.alerts.notifyVoiceMissing()
                }
            }
            completion.call()
        }
    }

    /// Annule les segments chaînés restants d'une occurrence (Adhan long).
    private func cancelRemainingSegments(prayer: String?, fireInterval: Double?) async {
        guard let prayer, let prayerValue = Prayer(rawValue: prayer), let fireInterval else { return }
        let dayID = PrayerAlertRequest.dayIdentifier(
            prayer: prayerValue,
            fireDate: Date(timeIntervalSince1970: fireInterval)
        )
        await alerts.cancelChainedSegments(dayIdentifier: dayID)
    }
}
