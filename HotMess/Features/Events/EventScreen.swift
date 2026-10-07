//
//  EventScreen.swift
//  HotMess
//

import SwiftUI

/// Event detail, replacing `EventViewController`.
///
/// The original decided its section count from two `if` statements and then
/// indexed sections with different numbers in `cellForRowAt`, so the host row
/// was unreachable and the venue row could read a `nil` venue.
struct EventScreen: View {
    let eventID: UUID

    @Environment(AppModel.self) private var model
    @State private var viewModel: EventViewModel?
    @State private var heroTone = HeroTone.placeholder
    @State private var heroCollapsed = false
    @State private var pingSeed: PingSeed?

    var body: some View {
        LoadStateView(state: viewModel?.state ?? .loading, retry: reload) { detail in
            let event = detail.event

            GeometryReader { proxy in
                ScrollView {
                    VStack(spacing: 24) {
                        HeroHeader(url: event.coverURL, topInset: proxy.safeAreaInsets.top, tone: $heroTone) {
                            heroText(event)
                        }

                        if viewModel?.isTonight == true || viewModel?.activePings.isEmpty == false {
                            PingPlaceStrip(
                                pings: viewModel?.activePings ?? [],
                                isJoined: viewModel?.isJoinedHere(userID: model.session.userID) == true,
                                isBusy: viewModel?.isUpdatingPings == true,
                                pingForHere: pingForHere(event),
                                join: { Task { await viewModel?.joinHere(userID: model.session.userID) } },
                                leave: { Task { await viewModel?.leaveHere(userID: model.session.userID) } }
                            )
                        }

                        DetailSection(String(localized: "Your RSVP")) {
                            RSVPPicker(selection: event.rsvp) { rsvp in
                                Task { await viewModel?.setRSVP(rsvp) }
                            }
                        }

                        detailsSection(event)

                        if let person = event.person {
                            CardSection(String(localized: "Host")) {
                                PersonCardLink(person: person)
                            }
                        }

                        if let venue = event.venue {
                            CardSection(String(localized: "Venue")) {
                                VenueCardLink(venue: venue)
                            }
                        } else {
                            DetailSection(String(localized: "Venue")) {
                                Text(Event.toBeAnnounced)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        if !detail.people.isEmpty {
                            CardSection(String(localized: "Going")) {
                                ForEach(detail.people) { person in
                                    PersonCardLink(person: person)
                                }
                            }
                        }
                    }
                    .padding(.bottom, 24)
                }
                .ignoresSafeArea(edges: .top)
                .trackingHeroCollapse($heroCollapsed)
            }
            // Ignoring the top here too is what makes the proxy report the bars' height.
            .ignoresSafeArea(edges: .top)
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .toolbar {
                if let shareURL = event.shareURL {
                    ShareLink(item: shareURL) {
                        Label(String(localized: "Share"), systemImage: "square.and.arrow.up")
                    }
                }
            }
        }
        .heroNavigationBar(
            title: viewModel?.state.value?.event.name ?? String(localized: "Event"),
            tone: heroTone,
            collapsed: heroCollapsed || viewModel?.state.value == nil
        )
        .task {
            ensureViewModel()
            await viewModel?.load()
        }
        .sheet(item: $pingSeed) { seed in
            PingSheet(seed: seed)
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
        .alert(
            String(localized: "Couldn't Save RSVP"),
            isPresented: Binding(
                get: { viewModel?.rsvpError != nil },
                set: { if !$0 { viewModel?.dismissRSVPError() } }
            )
        ) {
            Button(String(localized: "OK"), role: .cancel) {}
        } message: {
            Text(viewModel?.rsvpError ?? "")
        }
    }

    /// "Ping for here", only for an event tonight.
    private func pingForHere(_ event: Event) -> (() -> Void)? {
        guard viewModel?.isTonight == true else { return nil }
        return { pingSeed = .event(event) }
    }

    private func heroText(_ event: Event) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(event.startDate.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day().hour().minute()).uppercased())
                .font(.hotMess(.footnote, semibold: true))
                .tracking(0.8)

            Text(event.name)
                .font(.hotMess(.title, semibold: true))
                .lineLimit(3)
                .accessibilityAddTraits(.isHeader)

            if let place = event.venue?.name ?? event.person?.name {
                Text(place)
                    .font(.hotMess(.subheadline, semibold: true))
                    .lineLimit(1)
            }
        }
    }

    private func detailsSection(_ event: Event) -> some View {
        DetailSection {
            InfoRow(
                title: String(localized: "Starts"),
                value: event.startDate.formatted(date: .abbreviated, time: .shortened)
            )

            if let endDate = event.endDate {
                InfoRow(
                    title: String(localized: "Ends"),
                    value: endDate.formatted(date: .abbreviated, time: .shortened)
                )
            }

            if let facebookURL = event.facebookURL {
                Link(destination: facebookURL) {
                    InfoRow(
                        title: String(localized: "Open in Facebook"),
                        value: nil,
                        systemImage: "arrow.up.right.square"
                    )
                }
            }
        }
    }

    private func ensureViewModel() {
        if viewModel == nil {
            viewModel = EventViewModel(api: model.api, eventID: eventID)
        }
    }

    private func reload() {
        Task {
            ensureViewModel()
            await viewModel?.load()
        }
    }
}

/// The three RSVP buttons, replacing `RSVPTableViewCell` — which reached
/// straight into `DataService`, mutated the event in place and mis-spelled one
/// of its own states.
struct RSVPPicker: View {
    let selection: RSVP
    let onSelect: (RSVP) -> Void

    var body: some View {
        HStack(spacing: 12) {
            ForEach(RSVP.selectable, id: \.self) { rsvp in
                Button {
                    onSelect(rsvp)
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: rsvp.systemImage)
                            .font(.title2)
                        Text(rsvp.title)
                            .font(.caption)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
                .foregroundStyle(rsvp == selection ? Color.hotMessAccent : .secondary)
                .background(
                    rsvp == selection ? Color.hotMessAccent.opacity(0.12) : .clear,
                    in: .rect(cornerRadius: 10)
                )
                .accessibilityAddTraits(rsvp == selection ? [.isSelected, .isButton] : .isButton)
            }
        }
        .padding(.vertical, 4)
    }
}
