//
//  EventsScreen.swift
//  HotMess
//

import SwiftUI

/// The events tab, replacing `EventsViewController`.
struct EventsScreen: View {
    @Environment(AppModel.self) private var model
    @State private var viewModel: EventsViewModel?

    var body: some View {
        LoadStateView(state: viewModel?.state ?? .loading, retry: reload) { listing in
            if listing.isEmpty {
                ContentUnavailableView(
                    String(localized: "No Events"),
                    systemImage: "calendar",
                    description: Text("Nothing is scheduled near you just yet.")
                )
            } else {
                List {
                    ForEach(listing.sections) { section in
                        Section(section.title) {
                            if section.events.isEmpty {
                                Text("No events.")
                                    .foregroundStyle(.secondary)
                            } else {
                                ForEach(section.events) { event in
                                    NavigationLink(value: AppRoute.event(event.id)) {
                                        if event.isFeatured {
                                            FeaturedEventRow(event: event)
                                        } else {
                                            EventRow(event: event)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle(model.location.locale?.name ?? String(localized: "Events"))
        .task(id: model.location.locale?.id) {
            ensureViewModel()
            await viewModel?.load(localeID: model.location.locale?.id)
        }
        .refreshable {
            await viewModel?.load(localeID: model.location.locale?.id)
        }
    }

    private func ensureViewModel() {
        if viewModel == nil {
            viewModel = EventsViewModel(api: model.api)
        }
    }

    private func reload() {
        Task {
            ensureViewModel()
            await viewModel?.load(localeID: model.location.locale?.id)
        }
    }
}
