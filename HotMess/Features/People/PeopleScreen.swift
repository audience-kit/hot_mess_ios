//
//  PeopleScreen.swift
//  HotMess
//

import SwiftUI

/// The people tab, replacing `PeopleViewController` — which registered its
/// refresh observer with `object: self`, so the notification it was waiting for
/// never matched and the list only ever loaded once.
///
/// Once the device's city is known it opens on who's local there: people
/// playing it this week, then people based there. Everyone is a tap away.
struct PeopleScreen: View {
    @Environment(AppModel.self) private var model
    @State private var viewModel: PeopleViewModel?
    @State private var scope = Scope.local

    private enum Scope: Hashable {
        case local
        case everyone
    }

    var body: some View {
        LoadStateView(state: viewModel?.state ?? .loading, retry: reload) { listing in
            if listing.isEmpty {
                ContentUnavailableView(
                    String(localized: "No One Yet"),
                    systemImage: "person.2",
                    description: Text("Nobody is listed yet.")
                )
            } else {
                ScrollView {
                    VStack(spacing: 24) {
                        if let locale = model.location.locale {
                            Picker(String(localized: "Show"), selection: $scope) {
                                Text(locale.name).tag(Scope.local)
                                Text("Everyone").tag(Scope.everyone)
                            }
                            .pickerStyle(.segmented)
                            .padding(.horizontal, 16)

                            if scope == .local {
                                localSections(listing.local(to: locale.id), in: locale)
                            } else {
                                everyoneSection(listing)
                            }
                        } else {
                            everyoneSection(listing)
                        }
                    }
                    .padding(.vertical, 16)
                }
                .background(Color(.systemGroupedBackground))
            }
        }
        .navigationTitle(String(localized: "People"))
        .task {
            ensureViewModel()
            await viewModel?.load()
        }
        .refreshable {
            await model.location.refreshPosition()
            await viewModel?.load()
        }
    }

    @ViewBuilder
    private func localSections(_ local: PeopleListing.Local, in locale: AppLocale) -> some View {
        if local.isEmpty {
            DetailSection {
                VStack(alignment: .leading, spacing: 8) {
                    Text("No one based in \(locale.name) yet.")
                        .foregroundStyle(.secondary)

                    Button(String(localized: "Show everyone")) {
                        scope = .everyone
                    }
                }
            }
        } else {
            CardSection(String(localized: "Playing this week")) {
                ForEach(local.playing) { playing in
                    PersonCardLink(
                        person: playing.entry.person,
                        detail: gigLine(playing.gig),
                        friends: playing.entry.friends
                    )
                }
            }

            CardSection(String(localized: "Based here")) {
                ForEach(local.based) { entry in
                    PersonCardLink(person: entry.person, friends: entry.friends)
                }
            }
        }
    }

    private func everyoneSection(_ listing: PeopleListing) -> some View {
        CardSection {
            ForEach(listing.everyone) { entry in
                PersonCardLink(person: entry.person, friends: entry.friends)
            }
        }
    }

    /// "Tonight · Neighbours", or "Fri · Neighbours" later in the week.
    private func gigLine(_ gig: PersonEntry.Gig) -> String {
        let day = Calendar.current.isDateInToday(gig.date)
            ? String(localized: "Tonight")
            : gig.date.formatted(.dateTime.weekday(.abbreviated))
        guard let venue = gig.venueName, !venue.isEmpty else { return day }
        return "\(day) · \(venue)"
    }

    private func ensureViewModel() {
        if viewModel == nil {
            viewModel = PeopleViewModel(audienceKit: model.audienceKit)
        }
    }

    private func reload() {
        Task {
            ensureViewModel()
            await viewModel?.load()
        }
    }
}
