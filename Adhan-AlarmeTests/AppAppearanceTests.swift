import Testing

@testable import Adhan_Alarme

/// Mapping `AppAppearance` → préférence sombre (pur, sans UI).
@Suite struct AppAppearanceTests {
    @Test func prefersDarkMapping() {
        #expect(AppAppearance.system.prefersDark == nil)
        #expect(AppAppearance.light.prefersDark == false)
        #expect(AppAppearance.dark.prefersDark == true)
    }
}
