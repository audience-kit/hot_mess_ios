//
//  EventsScreen.swift
//  HotMess
//

import SwiftUI

/// The events tab, replacing `EventsViewController`.
struct EventsScreen: View {
    @Environment(AppModel.self) private var model
    @State private var viewModel: EventsViewModel?
    /// The night picked on the calendar; nil lists every upcoming event.
    @State private var selectedNight: Date?

    var body: some View {
        LoadStateView(state: viewModel?.state ?? .loading, retry: reload) { listing in
            if listing.isEmpty {
                ContentUnavailableView(
                    String(localized: "No Events"),
                    systemImage: "calendar",
                    description: Text("Nothing is scheduled near you just yet.")
                )
            } else {
                let nights = NightCalendar(events: listing.allEvents)

                List {
                    Section {
                        NightCalendarView(calendar: nights, selection: $selectedNight)
                    }

                    if let night = nights.nights.first(where: { $0.date == selectedNight }) {
                        Section(night.date.formatted(.dateTime.weekday(.wide).month(.wide).day())) {
                            if night.events.isEmpty {
                                Text("Nothing on this night yet.")
                                    .foregroundStyle(.secondary)
                            } else {
                                ForEach(night.events) { event in
                                    eventLink(event)
                                }
                            }
                        }
                    } else {
                        ForEach(listing.sections) { section in
                            Section(section.title) {
                                if section.events.isEmpty {
                                    Text("No events.")
                                        .foregroundStyle(.secondary)
                                } else {
                                    ForEach(section.events) { event in
                                        eventLink(event)
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
            selectedNight = nil
            ensureViewModel()
            await viewModel?.load(localeID: model.location.locale?.id)
        }
        .refreshable {
            await viewModel?.load(localeID: model.location.locale?.id)
        }
    }

    private func eventLink(_ event: Event) -> some View {
        NavigationLink(value: AppRoute.event(event.id)) {
            if event.isFeatured {
                FeaturedEventRow(event: event)
            } else {
                EventRow(event: event)
            }
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
