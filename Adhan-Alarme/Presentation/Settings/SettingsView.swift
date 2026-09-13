import SwiftUI

/// Écran Réglages (feuille depuis l'accueil) : voix de l'Adhan —
/// sélection, téléchargement/suppression, aperçu de lecture.
/// Autres sections (alertes par prière…) : phases 4/5.
struct SettingsView: View {
    @State private var viewModel: SettingsViewModel
    @Environment(\.dismiss) private var dismiss

    init(viewModel: SettingsViewModel) {
        _viewModel = State(wrappedValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            Form {
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
