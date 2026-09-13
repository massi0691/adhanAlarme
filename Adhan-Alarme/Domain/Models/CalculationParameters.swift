import Foundation

/// Paramètre de Maghrib : coucher du soleil ou angle sous l'horizon.
enum MaghribParameter: Sendable, Hashable {
    case sunset
    case angle(Double)
}

/// Paramètre d'Isha : angle ou intervalle fixe après Maghrib.
enum IshaParameter: Sendable, Hashable {
    case angle(Double)
    case minutesAfterMaghrib(Double)
}

/// Paramètres par défaut d'une méthode de calcul.
/// Angles vérifiés le 2026-09-13 via l'API Aladhan (`meta.method.params`),
/// y compris les ajustements officiels Diyanet (`meta.offset`).
struct MethodPrayerParameters: Sendable, Hashable {
    let fajrAngle: Double
    let maghrib: MaghribParameter
    let isha: IshaParameter
    /// Ajustements officiels de la méthode, en minutes (ex. Diyanet).
    let adjustments: [Prayer: Int]

    init(
        fajrAngle: Double,
        maghrib: MaghribParameter = .sunset,
        isha: IshaParameter,
        adjustments: [Prayer: Int] = [:]
    ) {
        self.fajrAngle = fajrAngle
        self.maghrib = maghrib
        self.isha = isha
        self.adjustments = adjustments
    }
}

extension CalculationMethod {
    var defaultPrayerParameters: MethodPrayerParameters {
        switch self {
        case .muslimWorldLeague:
            MethodPrayerParameters(fajrAngle: 18, isha: .angle(17))
        case .egyptian:
            MethodPrayerParameters(fajrAngle: 19.5, isha: .angle(17.5))
        case .karachi:
            MethodPrayerParameters(fajrAngle: 18, isha: .angle(18))
        case .ummAlQura:
            MethodPrayerParameters(fajrAngle: 18.5, isha: .minutesAfterMaghrib(90))
        case .isna:
            MethodPrayerParameters(fajrAngle: 15, isha: .angle(15))
        case .diyanet:
            MethodPrayerParameters(
                fajrAngle: 18,
                isha: .angle(17),
                adjustments: [.sunrise: -7, .dhuhr: 5, .asr: 4, .maghrib: 7]
            )
        case .kuwait:
            MethodPrayerParameters(fajrAngle: 18, isha: .angle(17.5))
        case .qatar:
            MethodPrayerParameters(fajrAngle: 18, isha: .minutesAfterMaghrib(90))
        case .singapore:
            MethodPrayerParameters(fajrAngle: 20, isha: .angle(18))
        case .tehran:
            MethodPrayerParameters(fajrAngle: 17.7, maghrib: .angle(4.5), isha: .angle(14))
        case .jafari:
            MethodPrayerParameters(fajrAngle: 16, maghrib: .angle(4), isha: .angle(14))
        case .uoif:
            MethodPrayerParameters(fajrAngle: 12, isha: .angle(12))
        }
    }
}

/// Paramètres effectifs du calcul : défauts de la méthode + remplacements
/// utilisateur (angles) + méthode Asr + règle de haute latitude.
/// Les ajustements en minutes sont appliqués par le dépôt, après calcul.
struct CalculationParameters: Sendable, Hashable {
    let fajrAngle: Double
    let maghrib: MaghribParameter
    let isha: IshaParameter
    /// Facteur d'ombre : 1 (standard) ou 2 (Hanafi).
    let asrShadowFactor: Double
    let highLatitudeRule: HighLatitudeRule
    /// Ajustements de la méthode (ex. Diyanet), en minutes.
    /// Les ajustements manuels de l'utilisateur s'y ajoutent.
    let methodAdjustments: [Prayer: Int]

    init(configuration: PrayerCalculationConfiguration) {
        let defaults = configuration.method.defaultPrayerParameters
        self.fajrAngle = configuration.fajrAngleOverride ?? defaults.fajrAngle
        self.maghrib = defaults.maghrib
        if let ishaOverride = configuration.ishaAngleOverride {
            self.isha = .angle(ishaOverride)
        } else {
            self.isha = defaults.isha
        }
        self.asrShadowFactor = configuration.asrMethod == .hanafi ? 2 : 1
        self.highLatitudeRule = configuration.highLatitudeRule
        self.methodAdjustments = defaults.adjustments
    }
}
