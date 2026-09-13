import SwiftUI

@main
struct Adhan_AlarmeApp: App {
    @State private var container = AppContainer.production

    var body: some Scene {
        WindowGroup {
            HomeView(
                viewModel: container.makeHomeViewModel(),
                locationViewModel: container.makeLocationViewModel(),
                settingsViewModel: container.makeSettingsViewModel()
            )
            .environment(\.locale, container.languageSettings.locale ?? Locale.current)
            .environment(\.layoutDirection, container.languageSettings.appLanguage.isRightToLeft ? .rightToLeft : .leftToRight)
        }
    }
}
