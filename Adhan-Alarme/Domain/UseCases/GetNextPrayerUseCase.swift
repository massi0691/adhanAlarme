import Foundation

/// Détermine la prochaine échéance (prière ou lever du soleil).
struct GetNextPrayerUseCase: Sendable {
    /// Première échéance strictement après `now`.
    ///
    /// - Si une échéance du jour est encore à venir, elle est retournée
    ///   avec `isTomorrow = false`.
    /// - Sinon, le Fajr du lendemain est retourné si fourni.
    /// - Une échéance exactement égale à `now` est considérée comme atteinte
    ///   (comparaison stricte), on passe donc à la suivante.
    func resolve(now: Date, today: PrayerTimes, tomorrowFajr: Date?) -> NextPrayer? {
        for prayer in Prayer.allCases {
            let time = today.time(for: prayer)
            if time > now {
                return NextPrayer(prayer: prayer, date: time, isTomorrow: false)
            }
        }
        guard let tomorrowFajr, tomorrowFajr > now else { return nil }
        return NextPrayer(prayer: .fajr, date: tomorrowFajr, isTomorrow: true)
    }
}
