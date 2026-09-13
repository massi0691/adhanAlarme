import SwiftUI
import UniformTypeIdentifiers

/// Écran Réglages (feuille depuis l'accueil) : langue, calcul des
/// horaires (méthode, Asr, hautes latitudes, angles, ajustements),
/// alertes par prière et voix de l'Adhan (sélection, téléchargement).
struct SettingsView: View {
    @State private var viewModel: SettingsViewModel
    @State private var showingImporter = false
    @Environment(\.dismiss) private var dismiss

    init(viewModel: SettingsViewModel) {
        _viewModel = State(wrappedValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("settings.language.language", selection: languageBinding()) {
                        ForEach(AppLanguage.allCases, id: \.self) { language in
                            Text(LocalizedStringKey(language.titleKey)).tag(language)
                        }
                    }
                } header: {
                    sectionHeader("settings.language.section", icon: "globe")
                }
                Section {
                    Picker("settings.appearance.appearance", selection: appearanceBinding()) {
                        ForEach(AppAppearance.allCases, id: \.self) { appearance in
                            Text(LocalizedStringKey(appearance.titleKey)).tag(appearance)
                        }
                    }
                } header: {
                    sectionHeader("settings.appearance.section", icon: "circle.lefthalf.filled")
                }
                Section {
                    Picker("settings.calculation.method", selection: methodBinding()) {
                        ForEach(CalculationMethod.allCases, id: \.self) { method in
                            Text(LocalizedStringKey(method.titleKey)).tag(method)
                        }
                    }
                    Picker("settings.calculation.asr", selection: asrBinding()) {
                        ForEach(AsrMethod.allCases, id: \.self) { method in
                            Text(LocalizedStringKey(method.titleKey)).tag(method)
                        }
                    }
                    Picker("settings.calculation.highLatitude", selection: ruleBinding()) {
                        ForEach(HighLatitudeRule.allCases, id: \.self) { rule in
                            Text(LocalizedStringKey(rule.titleKey)).tag(rule)
                        }
                    }
                    Toggle("settings.calculation.customAngles", isOn: customAnglesBinding())
                    if viewModel.usesCustomAngles {
                        Stepper(value: fajrAngleBinding(), in: 5...25, step: 0.5) {
                            HStack {
                                Text("settings.calculation.fajrAngle")
                                Spacer()
                                Text(formattedAngle(viewModel.fajrAngle))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Stepper(value: ishaAngleBinding(), in: 5...25, step: 0.5) {
                            HStack {
                                Text("settings.calculation.ishaAngle")
                                Spacer()
                                Text(formattedAngle(viewModel.ishaAngle))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Button("settings.calculation.defaultAngles") {
                            viewModel.setUsesCustomAngles(false)
                        }
                    }
                    NavigationLink("settings.calculation.adjustments") {
                        CalculationAdjustmentsView(viewModel: viewModel)
                    }
                } header: {
                    sectionHeader("settings.calculation.section", icon: "function")
                }
                Section {
                    Toggle("settings.alerts.enabled", isOn: Binding(
                        get: { viewModel.alertsEnabled },
                        set: { enabled in
                            if enabled {
                                Task { await viewModel.enableAlerts() }
                            } else {
                                viewModel.disableAlerts()
                            }
                        }
                    ))
                    if viewModel.alertAuthorization == .denied {
                        Text("settings.alerts.denied")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                            Link("settings.alerts.openSettings", destination: settingsURL)
                        }
                    } else if viewModel.alertsEnabled {
                        ForEach(Prayer.allCases) { prayer in
                            Picker(selection: modeBinding(for: prayer)) {
                                ForEach(PrayerAlertMode.allCases, id: \.self) { mode in
                                    Text(LocalizedStringKey(mode.labelKey)).tag(mode)
                                }
                            } label: {
                                Label {
                                    Text(LocalizedStringKey(prayer.titleKey))
                                } icon: {
                                    Image(systemName: prayer.iconName)
                                        .foregroundStyle(DSColors.brand)
                                }
                            }
                        }
                        Toggle("settings.alerts.longAdhan", isOn: Binding(
                            get: { viewModel.longAdhanEnabled },
                            set: { enabled in
                                Task { await viewModel.setLongAdhanEnabled(enabled) }
                            }
                        ))
                        .disabled(viewModel.isPreparingLongAdhan)
                        if viewModel.isPreparingLongAdhan {
                            ProgressView {
                                Text("settings.alerts.preparingLongAdhan")
                            }
                        } else {
                            Text("settings.alerts.longAdhanHint")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    sectionHeader("settings.alerts.section", icon: "bell")
                }
                Section {
                    ForEach(viewModel.voices) { muezzin in
                        voiceRow(muezzin)
                    }
                } header: {
                    sectionHeader("settings.voice.section", icon: "speaker.wave.2")
                }
                if let errorKey = viewModel.errorKey {
                    Section {
                        Text(LocalizedStringKey(errorKey))
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("settings.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("common.close") { dismiss() }
                }
            }
            .onAppear { viewModel.refresh() }
            .task { await viewModel.loadAlertAuthorization() }
        }
    }

    private func voiceRow(_ muezzin: Muezzin) -> some View {
        VStack(alignment: .leading, spacing: DSSpacing.sm) {
            HStack {
                Button {
                    viewModel.select(muezzin)
                } label: {
                    HStack {
                        if muezzin.id == Muezzin.customID {
                            Text("settings.voice.custom")
                                .foregroundStyle(.primary)
                        } else {
                            Text(muezzin.name)
                                .foregroundStyle(.primary)
                        }
                        Spacer()
                        if viewModel.selectedMuezzinID == muezzin.id {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.tint)
                        }
                    }
                }
            }
            Text(LocalizedStringKey(statusKey(for: viewModel.availability[muezzin.id])))
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(spacing: DSSpacing.md) {
                playButton(muezzin)
                if viewModel.playbackState.activeMuezzinID == muezzin.id {
                    Button("settings.voice.stop") { viewModel.stop() }
                }
                Spacer()
                downloadOrDeleteButton(muezzin)
            }
            .buttonStyle(.borderless)
            if let progress = viewModel.downloadProgress[muezzin.id] {
                ProgressView(value: progress) {
                    Text("settings.voice.downloading")
                }
            }
        }
        .fileImporter(isPresented: $showingImporter, allowedContentTypes: [.audio]) { result in
            if case .success(let url) = result {
                Task { await viewModel.importCustomAudio(from: url) }
            }
        }
    }

    private func playButton(_ muezzin: Muezzin) -> some View {
        let isPlaying = viewModel.playbackState == .playing(muezzinID: muezzin.id)
        let isActive = viewModel.playbackState.activeMuezzinID == muezzin.id
        return Button(isPlaying ? "settings.voice.pause" : (isActive ? "settings.voice.resume" : "settings.voice.listen")) {
            Task { await viewModel.togglePlay(muezzin) }
        }
        .disabled(viewModel.downloadProgress[muezzin.id] != nil)
    }

    @ViewBuilder
    private func downloadOrDeleteButton(_ muezzin: Muezzin) -> some View {
        switch viewModel.availability[muezzin.id] {
        case .downloaded:
            Button("settings.voice.delete", role: .destructive) {
                viewModel.deleteDownload(muezzin)
            }
        case .remoteAvailable:
            Button("settings.voice.download") {
                Task { await viewModel.download(muezzin) }
            }
            .disabled(viewModel.downloadProgress[muezzin.id] != nil)
        case .bundled:
            EmptyView()
        case .unavailable, nil:
            if muezzin.id == Muezzin.customID {
                Button("settings.voice.import") { showingImporter = true }
            } else {
                EmptyView()
            }
        }
    }

    /// En-tête de section : titre secondaire + icône au vert de marque.
    private func sectionHeader(_ key: String, icon: String) -> some View {
        Label {
            Text(LocalizedStringKey(key))
        } icon: {
            Image(systemName: icon)
                .foregroundStyle(DSColors.brand)
        }
    }

    private func appearanceBinding() -> Binding<AppAppearance> {
        Binding(
            get: { viewModel.appearance },
            set: { viewModel.setAppearance($0) }
        )
    }

    private func languageBinding() -> Binding<AppLanguage> {
        Binding(
            get: { viewModel.appLanguage },
            set: { viewModel.setAppLanguage($0) }
        )
    }

    private func methodBinding() -> Binding<CalculationMethod> {
        Binding(
            get: { viewModel.calculationMethod },
            set: { viewModel.setCalculationMethod($0) }
        )
    }

    private func asrBinding() -> Binding<AsrMethod> {
        Binding(
            get: { viewModel.asrMethod },
            set: { viewModel.setAsrMethod($0) }
        )
    }

    private func ruleBinding() -> Binding<HighLatitudeRule> {
        Binding(
            get: { viewModel.highLatitudeRule },
            set: { viewModel.setHighLatitudeRule($0) }
        )
    }

    private func customAnglesBinding() -> Binding<Bool> {
        Binding(
            get: { viewModel.usesCustomAngles },
            set: { viewModel.setUsesCustomAngles($0) }
        )
    }

    private func fajrAngleBinding() -> Binding<Double> {
        Binding(
            get: { viewModel.fajrAngle },
            set: { viewModel.setFajrAngle($0) }
        )
    }

    private func ishaAngleBinding() -> Binding<Double> {
        Binding(
            get: { viewModel.ishaAngle },
            set: { viewModel.setIshaAngle($0) }
        )
    }

    private func formattedAngle(_ angle: Double) -> String {
        String(format: "%.1f°", angle)
    }

    private func modeBinding(for prayer: Prayer) -> Binding<PrayerAlertMode> {
        Binding(
            get: { viewModel.alertModes[prayer] ?? .adhan },
            set: { viewModel.setAlertMode($0, for: prayer) }
        )
    }

    private func statusKey(for availability: MuezzinAudioAvailability?) -> String {
        switch availability {
        case .bundled: return "settings.voice.status.bundled"
        case .downloaded: return "settings.voice.status.downloaded"
        case .remoteAvailable: return "settings.voice.status.remote"
        case .unavailable, nil: return "settings.voice.status.unavailable"
        }
    }
}

#Preview {
    SettingsView(viewModel: AppContainer.preview.makeSettingsViewModel())
}
