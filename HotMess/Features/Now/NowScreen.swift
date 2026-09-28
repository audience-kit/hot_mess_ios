//
//  NowScreen.swift
//  HotMess
//

import SwiftUI

/// The home tab, replacing `NowViewController` — a table view whose row
/// heights, section titles and cell identifiers were all decided by a chain of
/// `indexPath.section == 0` checks.
struct NowScreen: View {
    @Environment(AppModel.self) private var model
    @State private var viewModel: NowViewModel?

    var body: some View {
        LoadStateView(state: viewModel?.state ?? .loading, retry: reload) { now in
            List {
                if let imageURL = now.imageURL {
                    Section {
                        RemoteImage(url: imageURL)
                            .frame(height: 160)
                            .listRowInsets(EdgeInsets())
                    }
                }

                nearbySection(now)
                eventsSection(now)
            }
            .listStyle(.insetGrouped)
        }
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.large)
        .task(id: model.location.coordinates) {
            ensureViewModel()
            await viewModel?.load(near: model.location.coordinates)
        }
        .refreshable {
            await viewModel?.load(near: model.location.coordinates)
        }
    }

    private var navigationTitle: String {
        viewModel?.state.value?.title ?? String(localized: "Now")
    }

    // MARK: - Sections

    @ViewBuilder
    private func nearbySection(_ now: Now) -> some View {
        if let venues = now.venues {
            Section(String(localized: "Venues")) {
                if venues.isEmpty {
                    Text("You aren't near any venues right now.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(venues.prefix(3)) { venue in
                        NavigationLink(value: AppRoute.venue(venue.id)) {
                            VenueRow(venue: venue)
                        }
                    }
                }
            }
        } else {
            Section(String(localized: "People")) {
                if now.friends.isEmpty {
                    Text("None of your friends are out yet.")
                        .foregroundStyle(.secondary)
                } else {
                    FriendStrip(friends: now.friends)
                        .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                }

                if let venue = now.venue {
                    NavigationLink(value: AppRoute.venueChat(venue)) {
                        Label(String(localized: "Small Talk"), systemImage: "bubble.left.and.bubble.right")
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func eventsSection(_ now: Now) -> some View {
        Section(String(localized: "Events")) {
            if now.events.isEmpty {
                Text("There are no upcoming events.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(now.events) { event in
                    NavigationLink(value: AppRoute.event(event.id)) {
                        EventRow(event: event)
                    }
                }
            }
        }
    }

    // MARK: - Loading

    private func ensureViewModel() {
        if viewModel == nil {
            viewModel = NowViewModel(api: model.api)
        }
    }

    private func reload() {
        Task {
            ensureViewModel()
            await viewModel?.load(near: model.location.coordinates)
        }
    }
}

/// The horizontal row of friends who are out, replacing
/// `FriendListTableViewCell` — a table cell that hosted its own collection view
/// and data source.
struct FriendStrip: View {
    let friends: [Friend]

    @Environment(AppModel.self) private var model
    @Environment(\.openURL) private var openURL

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 16) {
                ForEach(friends) { friend in
                    Button {
                        if let url = friend.messengerURL { openURL(url) }
                    } label: {
                        VStack(spacing: 6) {
                            Avatar(
                                url: model.configuration.avatarURL(forUserID: friend.id),
                                initials: friend.name.initialsForDisplay,
                                size: 56
                            )

                            Text(friend.firstName)
                                .font(.caption)
                                .lineLimit(1)
                        }
                        .frame(width: 68)
                    }
                    .buttonStyle(.plain)
                    .disabled(friend.messengerURL == nil)
                }
            }
            .padding(.horizontal, 20)
        }
        .scrollIndicators(.hidden)
    }
}
