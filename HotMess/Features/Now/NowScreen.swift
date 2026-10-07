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
                if let simulated = model.location.simulatedVenueName {
                    Section {
                        Button(String(localized: "Stop pretending"), systemImage: "location.slash") {
                            model.location.stopSimulating()
                        }
                    } header: {
                        Text("Pretending to be at \(simulated)")
                    }
                }

                if let imageURL = now.imageURL {
                    Section {
                        RemoteImage(url: imageURL)
                            .frame(height: 160)
                            .listRowInsets(EdgeInsets())
                    }
                }

                nearbySection(now)
                friendVenuesSection(now)
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
        } else if let venue = now.venue {
            Section {
                NavigationLink(value: AppRoute.venue(venue.id)) {
                    VenueRow(venue: venue)
                }
            } header: {
                Text("You're at")
            }

            Section(String(localized: "Small Talk")) {
                if now.recentMessages.isEmpty {
                    Text("No one's said anything yet.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(now.recentMessages) { message in
                        ChatLine(message: message)
                    }
                }

                NavigationLink(value: AppRoute.venueChat(venue)) {
                    Label(String(localized: "Join the chat"), systemImage: "bubble.left.and.bubble.right")
                }
            }

            friendsSection(now, title: String(localized: "Friends here"))
        } else {
            friendsSection(now, title: String(localized: "People"))
        }
    }

    @ViewBuilder
    private func friendsSection(_ now: Now, title: String) -> some View {
        Section(title) {
            if now.friends.isEmpty {
                Text(now.venue == nil ? "None of your friends are out yet." : "None of your friends are here yet.")
                    .foregroundStyle(.secondary)
            } else {
                FriendStrip(friends: now.friends)
                    .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
            }
        }
    }

    /// Away from venues: where your friends are, as a count per venue.
    @ViewBuilder
    private func friendVenuesSection(_ now: Now) -> some View {
        if now.venue == nil, !now.friendVenues.isEmpty {
            Section(String(localized: "Where your friends are")) {
                ForEach(now.friendVenues) { entry in
                    NavigationLink(value: AppRoute.venue(entry.venue.id)) {
                        FriendVenueRow(entry: entry)
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

/// A venue and how many of your friends are there, with their first names.
struct FriendVenueRow: View {
    let entry: FriendVenue

    var body: some View {
        HStack(spacing: 12) {
            RemoteImage(url: entry.venue.photoURL)
                .frame(width: 44, height: 44)
                .clipShape(.rect(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.venue.name)
                    .font(.hotMess(.headline, semibold: true))
                    .lineLimit(1)

                Text(entry.friends.map(\.firstName).formatted(.list(type: .and)))
                    .font(.hotMess(.subheadline))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Text(entry.friendCount == 1 ? "1 friend" : "\(entry.friendCount) friends")
                .font(.hotMess(.caption, semibold: true))
                .foregroundStyle(Color.hotMessAccent)
                .monospacedDigit()
        }
        .padding(.vertical, 4)
    }
}

/// One line of a venue's chat, as the Now screen previews it: the sender's
/// photo and name, then what they said.
struct ChatLine: View {
    let message: VenueMessage

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Avatar(url: message.avatarURL, initials: message.name?.initialsForDisplay, size: 28)

            VStack(alignment: .leading, spacing: 2) {
                if let name = message.name {
                    Text(name)
                        .font(.hotMess(.caption, semibold: true))
                        .foregroundStyle(.secondary)
                }

                Text(message.body)
                    .font(.hotMess(.subheadline))
                    .lineLimit(2)
            }

            Spacer(minLength: 8)

            Text(message.sentAt, style: .relative)
                .font(.hotMess(.caption))
                .foregroundStyle(.tertiary)
                .monospacedDigit()
        }
        .padding(.vertical, 2)
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
