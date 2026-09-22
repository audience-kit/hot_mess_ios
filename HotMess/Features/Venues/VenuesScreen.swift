//
//  VenuesScreen.swift
//  HotMess
//

import MapKit
import SwiftUI

/// The venues tab, replacing `VenuesViewController` — a table view controller
/// with a map view wired in through an outlet, which force-unwrapped that
/// outlet on every refresh.
struct VenuesScreen: View {
    @Environment(AppModel.self) private var model
    @State private var viewModel: VenuesViewModel?
    @State private var camera: MapCameraPosition = .automatic

    var body: some View {
        LoadStateView(state: viewModel?.state ?? .loading, retry: reload) { collection in
            List {
                Section {
                    Map(position: $camera) {
                        ForEach(collection.pins) { pin in
                            Marker(pin.name, coordinate: pin.coordinate)
                                .tint(.hotMessAccent)
                        }
                    }
                    .frame(height: 220)
                    .listRowInsets(EdgeInsets())
                    .onChange(of: collection) { _, updated in
                        updateCamera(for: updated)
                    }
                    .onAppear { updateCamera(for: collection) }
                }

                Section(String(localized: "Nearby")) {
                    if collection.venues.isEmpty {
                        Text("No venues found near you.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(collection.venues) { venue in
                            NavigationLink(value: AppRoute.venue(venue.id)) {
                                VenueRow(venue: venue)
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
        }
        .navigationTitle(model.location.locale?.name ?? String(localized: "Venues"))
        .task(id: model.location.locale?.id) {
            ensureViewModel()
            await viewModel?.load(
                localeID: model.location.locale?.id,
                coordinates: model.location.coordinates
            )
        }
        .refreshable {
            await viewModel?.load(
                localeID: model.location.locale?.id,
                coordinates: model.location.coordinates
            )
        }
    }

    private func updateCamera(for collection: VenueCollection) {
        guard let region = collection.region else { return }
        camera = .region(region)
    }

    private func ensureViewModel() {
        if viewModel == nil {
            viewModel = VenuesViewModel(api: model.api)
        }
    }

    private func reload() {
        Task {
            ensureViewModel()
            await viewModel?.load(
                localeID: model.location.locale?.id,
                coordinates: model.location.coordinates
            )
        }
    }
}
