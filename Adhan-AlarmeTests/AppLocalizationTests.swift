import Foundation
import Testing

@testable import Adhan_Alarme

/// Chargeur de langue : mapping `.lproj`/tables + replis déterministes.
/// Les chargements positifs (vrais bundles) sont couverts en recette
/// manuelle (l'hôte de tests n'embarque pas les ressources de l'app).
@MainActor
struct AppLocalizationTests {
    @Test func lprojNames() {
        #expect(AppLocalization.lprojName(for: .system) == nil)
        #expect(AppLocalization.lprojName(for: .french) == "fr")
        #expect(AppLocalization.lprojName(for: .english) == "en")
        #expect(AppLocalization.lprojName(for: .arabic) == "ar")
        #expect(AppLocalization.lprojName(for: .kabyle) == "kab")
    }

    @Test func tableNames() {
        #expect(AppLocalization.tableName(for: .kabyle) == "Kabyle")
        #expect(AppLocalization.tableName(for: .french) == nil)
        #expect(AppLocalization.tableName(for: .system) == nil)
    }

    @Test func missingBundleReturnsNil() {
        #expect(AppLocalization.languageBundle(named: "xx-absent", in: .main) == nil)
    }

    @Test func missingKeyFallsBackToKey() {
        #expect(AppLocalization.string(forKey: "key.absent.for.test", language: .kabyle) == "key.absent.for.test")
        #expect(AppLocalization.string(forKey: "key.absent.for.test", language: .system) == "key.absent.for.test")
    }
}
