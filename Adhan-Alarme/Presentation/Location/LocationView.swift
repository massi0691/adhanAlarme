import SwiftUI
import UIKit

/// Écran Position : mode automatique (GPS) ou manuel (recherche de ville
/// + villes enregistrées). Recherche anti-rebond (300 ms) dans la vue.
struct LocationView: View {
    @State private var viewModel: LocationViewModel
    @State private var query = ""
    @State private var searchTask: Task<Void, Never>?
    @Environment(\.openURL) private var openURL

    init(viewModel: LocationViewModel) {
        _viewModel = State(wrappedValue: viewModel)
    }

    var body: some View {
        List {
            modeSection
            if !query.trimmingCharacters(in: .whitespaces).isEmpty {
                resultsSection
            }
            citiesSection
        }
        .searchable(text: $query, prompt: Text("location.search.placeholder"))
        .onChange(of: query) { _, newValue in
            searchTask?.cancel()
            let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.count >= 2 else {
                viewModel.clearSearch()
                return
            }
            searchTask = Task {
                try? await Task.sleep(for: .milliseconds(300))
                guard !Task.isCancelled else { return }
                await viewModel.search(query: trimmed)
            }
        }
        .onDisappear {
            searchTask?.cancel()
        }
        .navigationTitle("location.title")
        .task {
            viewModel.refresh()
        }
    }

    private var modeSection: some View {
        Section("location.mode") {
            Toggle("location.automatic", isOn: Binding(
                get: { viewModel.useAutomatic },
                set: { enabled in Task { await viewModel.setAutomatic(enabled) } }
            ))
            if viewModel.useAutomatic {
                statusRow
            }
        }
    }

    @ViewBuilder
    private var statusRow: some View {
        switch viewModel.authorization {
        case .authorized:
            Label("location.automaticStatus.authorized", systemImage: "checkmark.circle.fill")
                .foregroundStyle(DSColors.brand)
        case .denied, .restricted:
            VStack(alignment: .leading, spacing: DSSpacing.xs) {
                Label("location.automaticStatus.denied", systemImage: "location.slash.fill")
                    .foregroundStyle(.red)
                Button("location.openSettings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        openURL(url)
                    }
                }
                .buttonStyle(.bordered)
            }
        case .notDetermined:
            Text("location.automaticStatus.notDetermined")
                .foregroundStyle(.secondary)
        }
    }

    private var resultsSection: some View {
        Section("location.results") {
            if viewModel.isSearching && viewModel.searchResults.isEmpty {
                ProgressView()
            } else if viewModel.searchResults.isEmpty {
                Text("location.noResults")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(viewModel.searchResults) { result in
                    Button {
                        Task {
                            await viewModel.select(result)
                            query = ""
                        }
                    } label: {
                        VStack(alignment: .leading) {
                            Text(result.title)
                            if !result.subtitle.isEmpty {
                                Text(result.subtitle)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .foregroundStyle(.primary)
                }
            }
        }
    }

    private var citiesSection: some View {
        Section("location.cities") {
            if let errorKey = viewModel.errorKey {
                Text(LocalizedStringKey(errorKey))
                    .foregroundStyle(.red)
            }
            if viewModel.cities.isEmpty {
                Text("location.noCities")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(viewModel.cities) { city in
                    Button {
                        viewModel.activate(city)
                    } label: {
                        HStack {
                            Image(systemName: "mappin.circle.fill")
                                .foregroundStyle(DSColors.brand)
                            VStack(alignment: .leading) {
                                Text(city.name)
                                if let country = city.country {
                                    Text(country)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            if city.id == viewModel.activeCityID {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Color.accentColor)
                            }
                        }
                    }
                    .foregroundStyle(.primary)
                }
                .onDelete(perform: viewModel.remove(at:))
            }
        }
    }
}

#Preview {
    NavigationStack {
        LocationView(viewModel: AppContainer.preview.makeLocationViewModel())
    }
}
