import Foundation
import Testing
@testable import Adhan_Alarme

/// Table des paramètres par méthode (vérifiée via l'API Aladhan).
struct CalculationParametersTests {
    private func parameters(
        method: CalculationMethod = .muslimWorldLeague,
        asrMethod: AsrMethod = .standard,
        highLatitudeRule: HighLatitudeRule = .middleOfNight,
        fajrAngleOverride: Double? = nil,
        ishaAngleOverride: Double? = nil
    ) -> CalculationParameters {
        var configuration = PrayerCalculationConfiguration()
        configuration.method = method
        configuration.asrMethod = asrMethod
        configuration.highLatitudeRule = highLatitudeRule
        configuration.fajrAngleOverride = fajrAngleOverride
        configuration.ishaAngleOverride = ishaAngleOverride
        return CalculationParameters(configuration: configuration)
    }

    @Test func methodDefaults_matchVerifiedTable() async throws {
        let mwl = parameters()
        #expect(mwl.fajrAngle == 18)
        #expect(mwl.isha == .angle(17))
        #expect(mwl.maghrib == .sunset)

        #expect(parameters(method: .egyptian).fajrAngle == 19.5)
        #expect(parameters(method: .egyptian).isha == .angle(17.5))

        #expect(parameters(method: .karachi).isha == .angle(18))

        let ummAlQura = parameters(method: .ummAlQura)
        #expect(ummAlQura.fajrAngle == 18.5)
        #expect(ummAlQura.isha == .minutesAfterMaghrib(90))

        #expect(parameters(method: .isna).fajrAngle == 15)

        let tehran = parameters(method: .tehran)
        #expect(tehran.fajrAngle == 17.7)
        #expect(tehran.maghrib == .angle(4.5))
        #expect(tehran.isha == .angle(14))

        let jafari = parameters(method: .jafari)
        #expect(jafari.fajrAngle == 16)
        #expect(jafari.maghrib == .angle(4))

        #expect(parameters(method: .qatar).isha == .minutesAfterMaghrib(90))
        #expect(parameters(method: .kuwait).isha == .angle(17.5))
        #expect(parameters(method: .singapore).fajrAngle == 20)

        let uoif = parameters(method: .uoif)
        #expect(uoif.fajrAngle == 12)
        #expect(uoif.isha == .angle(12))
    }

    @Test func diyanet_hasOfficialAdjustments() async throws {
        #expect(parameters(method: .diyanet).methodAdjustments == [
            .sunrise: -7, .dhuhr: 5, .asr: 4, .maghrib: 7,
        ])
    }

    @Test func overrides_replaceDefaults() async throws {
        let custom = parameters(method: .ummAlQura, fajrAngleOverride: 19, ishaAngleOverride: 16)
        #expect(custom.fajrAngle == 19)
        #expect(custom.isha == .angle(16))
    }

    @Test func hanafi_doublesShadowFactor() async throws {
        #expect(parameters(asrMethod: .standard).asrShadowFactor == 1)
        #expect(parameters(asrMethod: .hanafi).asrShadowFactor == 2)
    }
}
