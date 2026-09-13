import Foundation

/// Prochaine échéance (prière ou lever du soleil).
struct NextPrayer: Sendable, Codable, Hashable {
    let prayer: Prayer
    let date: Date
    /// `true` si l'échéance est le Fajr du lendemain.
    let isTomorrow: Bool
}
