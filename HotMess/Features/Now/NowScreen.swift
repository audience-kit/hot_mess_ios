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
    @State private var heroTone = HeroTone.placeholder
    @State private var heroCollapsed = false

    var body: some View {
        LoadStateView(state: viewModel?.state ?? .loading, retry: reload) { now in
            GeometryReader { proxy in
                ScrollView {
                    VStack(spacing: 24) {
                        HeroHeader(url: now.imageURL, topInset: proxy.safeAreaInsets.top, tone: $heroTone) {
                            heroText(now)
                        }

                        if let simulated = model.location.simulatedVenueName {
                            DetailSection(String(localized: "Pretending to be at \(simulated)")) {
                                Button(String(localized: "Stop pretending"), systemImage: "location.slash") {
                                    Task { await model.location.stopSimulating() }
                                }
                            }
                        }

                        nearbySection(now)
                        localeChatSection(now)
                        friendVenuesSection(now)
                        eventsSection(now)
                    }
                    .padding(.bottom, 24)
                }
                .ignoresSafeArea(edges: .top)
                .trackingHeroCollapse($heroCollapsed)
                .refreshable {
                    await viewModel?.load(near: model.location.coordinates)
                }
            }
            // Ignoring the top here too is what makes the proxy report the bars' height.
            .ignoresSafeArea(edges: .top)
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
        }
        .heroNavigationBar(
            title: navigationTitle,
            tone: heroTone,
            collapsed: heroCollapsed || viewModel?.state.value == nil
        )
        .task(id: model.location.coordinates) {
            ensureViewModel()
            await viewModel?.load(near: model.location.coordinates)
        }
    }

    private var navigationTitle: String {
        viewModel?.state.value?.title ?? String(localized: "Now")
    }

    private func heroText(_ now: Now) -> some View {
        Text(now.title)
            .font(.hotMess(.largeTitle, semibold: true))
            .lineLimit(2)
            .accessibilityAddTraits(.isHeader)
    }

    // MARK: - Sections

    @ViewBuilder
    private func nearbySection(_ now: Now) -> some View {
        if let venues = now.venues {
            if venues.isEmpty {
                DetailSection(String(localized: "Venues")) {
                    Text("You aren't near any venues right now.")
                        .foregroundStyle(.secondary)
                }
            } else {
                CardSection(String(localized: "Venues")) {
                    ForEach(venues.prefix(3)) { venue in
                        VenueCardLink(venue: venue)
                    }
                }
            }
        } else if let venue = now.venue {
            CardSection(String(localized: "You're at")) {
                VenueCardLink(venue: venue)
            }

            ChatPeek(
                title: String(localized: "Small talk"),
                roomName: venue.name,
                messages: now.recentMessages.map { $0.threadMessage(currentUserID: model.session.userID) },
                route: .venueChat(venue)
            )
            .padding(.horizontal, 16)

            friendsSection(now, title: String(localized: "Friends here"))
        } else {
            friendsSection(now, title: String(localized: "People"))
        }
    }

    private func friendsSection(_ now: Now, title: String) -> some View {
        DetailSection(title) {
            if now.friends.isEmpty {
                Text(now.venue == nil ? "None of your friends are out yet." : "None of your friends are here yet.")
                    .foregroundStyle(.secondary)
            } else {
                FriendStrip(friends: now.friends)
                    .padding(.horizontal, -20)
            }
        }
    }

    /// Away from venues: the locale's chat room, for everyone out in it who
    /// isn't at a venue. Shown only when the API says the user can join.
    @ViewBuilder
    private func localeChatSection(_ now: Now) -> some View {
        if now.venue == nil, now.localeChatOpen, let locale = now.locale {
            ChatPeek(
                title: String(localized: "Small talk in \(locale.name)"),
                roomName: locale.name,
                messages: now.localeMessages.map { $0.threadMessage(currentUserID: model.session.userID) },
                route: .localeChat(locale)
            )
            .padding(.horizontal, 16)
        }
    }

    /// Away from venues: where your friends are, as a count per venue.
    @ViewBuilder
    private func friendVenuesSection(_ now: Now) -> some View {
        if now.venue == nil, !now.friendVenues.isEmpty {
            CardSection(String(localized: "Where your friends are")) {
                ForEach(now.friendVenues) { entry in
                    VenueCardLink(venue: entry.venue) {
                        VenueCard(
                            venue: entry.venue,
                            detail: entry.friends.map(\.firstName).formatted(.list(type: .and)),
                            pill: entry.friendCount == 1
                                ? String(localized: "1 friend")
                                : String(localized: "\(entry.friendCount) friends")
                        ) {
                            FriendFaces(friends: entry.friends)
                        }
                    }
                }
            }
        }
    }

    private func eventsSection(_ now: Now) -> some View {
        Group {
            if now.events.isEmpty {
                DetailSection(String(localized: "Events")) {
                    Text("There are no upcoming events.")
                        .foregroundStyle(.secondary)
                }
            } else {
                CardSection(String(localized: "Events")) {
                    ForEach(now.events) { event in
                        EventCardLink(event: event)
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
