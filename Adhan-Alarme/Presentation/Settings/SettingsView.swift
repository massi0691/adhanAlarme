import SwiftUI

/// Écran Réglages (feuille depuis l'accueil) : alertes par prière
/// (interrupteur global + mode par prière) et voix de l'Adhan
/// (sélection, téléchargement/suppression, aperçu de lecture).
struct SettingsView: View {
    @State private var viewModel: SettingsViewModel
    @Environment(\.dismiss) private var dismiss

    init(viewModel: SettingsViewModel) {
        _viewModel = State(wrappedValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("settings.alerts.section") {
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
                            Picker(LocalizedStringKey(prayer.titleKey), selection: modeBinding(for: prayer)) {
                                ForEach(PrayerAlertMode.allCases, id: \.self) { mode in
                                    Text(LocalizedStringKey(mode.labelKey)).tag(mode)
                                }
                            }
                        }
                    }
                }
                Section("settings.voice.section") {
                    ForEach(viewModel.voices) { muezzin in
                        voiceRow(muezzin)
                    }
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
                        Text(muezzin.name)
                            .foregroundStyle(.primary)
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
        case .bundled, .unavailable, nil:
            EmptyView()
        }
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
