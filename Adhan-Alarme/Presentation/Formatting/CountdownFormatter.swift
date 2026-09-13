import Foundation

/// Formate un compte à rebours en "HH:MM:SS" (heures non bornées).
/// Fonction pure, sans état : testable et sans coût.
enum CountdownFormatter {
    /// Retourne "00:00:00" si l'échéance est atteinte ou passée.
    static func string(until target: Date, from now: Date) -> String {
        let totalSeconds = max(0, Int(target.timeIntervalSince(now)))
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
}
