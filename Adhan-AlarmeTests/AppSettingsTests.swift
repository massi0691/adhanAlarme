import Foundation
import Testing
@testable import Adhan_Alarme

struct AppSettingsTests {
    @Test func defaults_enableAdhanGlobally() async throws {
        #expect(AppSettings.default.globalAdhanEnabled)
    }

    @Test func defaults_useMuslimWorldLeagueAndStandardAsr() async throws {
        let calculation = AppSettings.default.calculation

        #expect(calculation.method == .muslimWorldLeague)
        #expect(calculation.asrMethod == .standard)
        #expect(calculation.highLatitudeRule == .middleOfNight)
        #expect(calculation.manualAdjustments.isEmpty)
    }

    @Test func allPrayers_havePreferences() async throws {
        let preferences = AppSettings.default.prayerPreferences

        #expect(Prayer.allCases.allSatisfy { preferences[$0] != nil })
    }

    @Test func defaults_useAdhanForObligatoryPrayers() async throws {
        let preferences = AppSettings.default.prayerPreferences

        for prayer in Prayer.allCases where prayer.isObligatory {
            #expect(preferences[prayer]?.mode == .adhan)
            #expect(preferences[prayer]?.enabled == true)
        }
    }

    @Test func defaults_useNotificationOnlyForSunrise() async throws {
        let sunrise = AppSettings.default.prayerPreferences[.sunrise]

        #expect(sunrise?.mode == .notificationOnly)
        #expect(sunrise?.enabled == true)
    }

    @Test func defaultMuezzin_existsInCatalog() async throws {
        #expect(Muezzin.withID(AppSettings.default.selectedMuezzinID) != nil)
        #expect(Muezzin.withID(Muezzin.defaultID) != nil)
    }
}
