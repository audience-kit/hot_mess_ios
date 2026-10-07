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
    @State private var showingPingSheet = false

    /// Reloads when the position changes or Pings change elsewhere.
    private struct LoadKey: Hashable {
        var coordinates: Coordinates?
        var pingRevision: Int
    }

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

                        pingsSection(now)
                        nearbySection(now)
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
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingPingSheet = true
                } label: {
                    Text("Ping")
                        .font(.hotMess(.headline, semibold: true))
                }
                .accessibilityHint(String(localized: "Tell your friends you want to go out tonight"))
            }
        }
        .sheet(isPresented: $showingPingSheet) {
            PingSheet { ping in
                viewModel?.show(ping)
            }
            .environment(model)
        }
        .alert(
            String(localized: "Couldn't update ping"),
            isPresented: Binding(
                get: { viewModel?.pingError != nil },
                set: { if !$0 { viewModel?.pingError = nil } }
            )
        ) {
            Button(String(localized: "OK"), role: .cancel) {}
        } message: {
            Text(viewModel?.pingError ?? "")
        }
        .task(id: LoadKey(coordinates: model.location.coordinates, pingRevision: model.pingRevision)) {
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

    /// Your own Ping on top, then friends' Pings, newest first.
    @ViewBuilder
    private func pingsSection(_ now: Now) -> some View {
        if let ping = now.myPing, ping.isActive(at: .now) {
            MyPingCard(ping: ping) {
                showingPingSheet = true
            } end: {
                Task { await viewModel?.endMyPing() }
            }
            .disabled(viewModel?.busyPingIDs.contains(ping.id) == true)
            .padding(.horizontal, 16)
        }

        CardSection(String(localized: "Friends going out tonight")) {
            ForEach(Ping.friendFeed(now.friendPings, at: .now)) { ping in
                FriendPingCard(
                    ping: ping,
                    userID: model.session.userID,
                    isBusy: viewModel?.busyPingIDs.contains(ping.id) == true
                ) { target in
                    Task { await viewModel?.join(ping, target: target) }
                } leave: {
                    Task { await viewModel?.leave(ping) }
                }
            }
        }
    }

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

            DetailSection(String(localized: "Small Talk")) {
                if now.recentMessages.isEmpty {
                    Text("No one's said anything yet.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(now.recentMessages) { message in
                        ChatLine(message: message)
                    }
                }

                DetailLink(route: .venueChat(venue)) {
                    Label(String(localized: "Join the chat"), systemImage: "bubble.left.and.bubble.right")
                }
            }

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
