import SwiftUI

/// Écran principal : salutation, ville (lien vers Position), prochaine
/// prière, compte à rebours, interrupteur Adhan et horaires du jour.
struct HomeView: View {
    @State private var viewModel: HomeViewModel
    private let locationViewModel: LocationViewModel
    private let settingsViewModel: SettingsViewModel
    @State private var showingSettings = false
    @State private var hasLoadedOnce = false
    @Environment(\.layoutDirection) private var layoutDirection

    init(viewModel: HomeViewModel, locationViewModel: LocationViewModel, settingsViewModel: SettingsViewModel) {
        _viewModel = State(wrappedValue: viewModel)
        self.locationViewModel = locationViewModel
        self.settingsViewModel = settingsViewModel
    }

    var body: some View {
        NavigationStack {
            TimelineView(.everyMinute) { context in
                content(now: context.date)
                    .onChange(of: context.date) { _, newDate in
                        viewModel.refreshIfNeeded(now: newDate)
                    }
            }
            .task {
                await viewModel.load()
            }
            .onReceive(NotificationCenter.default.publisher(for: .NSSystemTimeZoneDidChange)) { _ in
                Task { await viewModel.load() }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView(viewModel: settingsViewModel)
            }
            .onChange(of: showingSettings) { _, shown in
                if !shown {
                    viewModel.syncAdhanFlag()
                    Task { await viewModel.load() }
                }
            }
        }
    }

    @ViewBuilder
    private func content(now: Date) -> some View {
        ZStack {
            ScrollView {
                VStack(spacing: DSSpacing.md) {
                    header(now: now)
                    switch viewModel.state {
                    case .loading:
                        // Premier lancement : le splash plein écran couvre.
                        // Rafraîchissements suivants : indicateur inline.
                        if hasLoadedOnce {
                            ProgressView {
                                Text("common.loading")
                            }
                            .padding(.top, DSSpacing.xl)
                        }
                    case .loaded(let day):
                        loadedContent(day: day, now: now)
                    case .failed:
                        failureContent
                    }
                }
                .padding(DSSpacing.md)
            }
            .background {
                DSColors.homeBackground.ignoresSafeArea()
            }
            .refreshable {
                await viewModel.load()
            }
            if case .loading = viewModel.state, !hasLoadedOnce {
                splashView
                    .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.35), value: viewModel.state)
        .onChange(of: viewModel.state) { _, newState in
            if newState != .loading {
                hasLoadedOnce = true
            }
        }
    }

    /// Écran de démarrage : mosquée plein écran (relais du storyboard
    /// de lancement iOS), avec indicateur de chargement.
    private var splashView: some View {
        ZStack {
            Image("SplashMosque")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
                .accessibilityHidden(true)
            VStack {
                Spacer()
                ProgressView {
                    Text("common.loading")
                }
                .tint(.white)
                .foregroundStyle(.white)
                .padding(.bottom, DSSpacing.xl * 2)
            }
            .ignoresSafeArea()
        }
    }

    private func header(now: Date) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: DSSpacing.xs) {
                Text(LocalizedStringKey(greetingKey(for: now)))
                    .font(DSTypography.greeting)
                NavigationLink {
                    LocationView(viewModel: locationViewModel)
                } label: {
                    HStack(spacing: DSSpacing.xs) {
                        Label {
                            Text(viewModel.cityName)
                        } icon: {
                            Image(systemName: "mappin.circle.fill")
                        }
                        Image(systemName: layoutDirection == .rightToLeft ? "chevron.left" : "chevron.right")
                            .font(.caption)
                            .fontWeight(.semibold)
                    }
                    .font(DSTypography.city)
                    .foregroundStyle(DSColors.secondaryText)
                }
            }
            Spacer()
            Button {
                showingSettings = true
            } label: {
                Image(systemName: "gearshape")
                    .font(.title2)
                    .foregroundStyle(DSColors.brand)
                    .padding(DSSpacing.sm)
                    .background(DSColors.brand.opacity(0.12))
                    .clipShape(Circle())
            }
            .accessibilityLabel(Text("settings.title"))
        }
        .foregroundStyle(DSColors.primaryText)
    }

    private func loadedContent(day: PrayerDay, now: Date) -> some View {
        VStack(spacing: DSSpacing.md) {
            if let next = day.next {
                NextPrayerCardView(nextPrayer: next)
            }
            AdhanToggleButton(isEnabled: viewModel.adhanEnabled) {
                viewModel.toggleAdhan()
            }
            VStack(spacing: DSSpacing.sm) {
                ForEach(Prayer.allCases) { prayer in
                    let time = day.times.time(for: prayer)
                    let isNext = day.next?.prayer == prayer && day.next?.isTomorrow == false
                    PrayerRowView(
                        prayer: prayer,
                        time: time,
                        isNext: isNext,
                        isPast: time < now && !isNext
                    )
                }
            }
        }
    }

    private var failureContent: some View {
        VStack(spacing: DSSpacing.md) {
            Text("error.generic")
                .foregroundStyle(DSColors.secondaryText)
            Button("common.retry") {
                Task { await viewModel.load() }
            }
            .buttonStyle(.bordered)
            NavigationLink("home.chooseCity") {
                LocationView(viewModel: locationViewModel)
            }
        }
        .padding(.top, DSSpacing.xl)
    }

    private func greetingKey(for date: Date) -> String {
        let hour = Calendar.current.component(.hour, from: date)
        switch hour {
        case 0..<12: return "home.greeting.morning"
        case 12..<18: return "home.greeting.afternoon"
        default: return "home.greeting.evening"
        }
    }
}

#Preview {
    HomeView(
        viewModel: AppContainer.preview.makeHomeViewModel(),
        locationViewModel: AppContainer.preview.makeLocationViewModel(),
        settingsViewModel: AppContainer.preview.makeSettingsViewModel()
    )
}
