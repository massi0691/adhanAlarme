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
        }
    }
}
