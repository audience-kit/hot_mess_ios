//
//  VenueScreen.swift
//  HotMess
//

import MapKit
import SwiftUI

/// Venue detail, replacing `VenueViewController` — whose share button was wired
/// to `#selector(EventViewController.actionButton)` on a method that wasn't
/// even `@objc`, so tapping it crashed.
struct VenueScreen: View {
    let venueID: UUID

    @Environment(AppModel.self) private var model
    @Environment(\.openURL) private var openURL
    @State private var viewModel: VenueViewModel?
    @State private var heroTone = HeroTone.placeholder
    @State private var heroCollapsed = false

    var body: some View {
        LoadStateView(state: viewModel?.state ?? .loading, retry: reload) { overview in
            let venue = overview.venue

            GeometryReader { proxy in
                ScrollView {
                    VStack(spacing: 24) {
                        HeroHeader(url: venue.heroURL ?? venue.photoURL, topInset: proxy.safeAreaInsets.top, tone: $heroTone) {
                            heroText(venue)
                        }

                        aboutSection(venue)

                        DetailSection(String(localized: "Chat")) {
                            DetailLink(route: .venueChat(venue)) {
                                Label(String(localized: "Join the room"), systemImage: "bubble.left.and.bubble.right")
                            }
                        }

                        if !overview.friends.isEmpty {
                            DetailSection(String(localized: "Friends Here")) {
                                FriendStrip(friends: overview.friends)
                                    .padding(.horizontal, -20)
                            }
                        }

                        DetailSection(String(localized: "Events")) {
                            if overview.events.isEmpty {
                                Text("No upcoming events.")
                                    .foregroundStyle(.secondary)
                            } else {
                                ForEach(overview.events) { event in
                                    DetailLink(route: .event(event.id)) {
                                        EventRow(event: event)
                                    }
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
                if let shareURL = venue.shareURL {
                    ShareLink(item: shareURL) {
                        Label(String(localized: "Share"), systemImage: "square.and.arrow.up")
                    }
                }
            }
        }
        .heroNavigationBar(
            title: viewModel?.state.value?.venue.name ?? String(localized: "Venue"),
            tone: heroTone,
            collapsed: heroCollapsed || viewModel?.state.value == nil
        )
        .task {
            ensureViewModel()
            await viewModel?.load()
        }
    }

    private func heroText(_ venue: Venue) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(venue.name)
                .font(.hotMess(.title, semibold: true))
                .lineLimit(3)
                .accessibilityAddTraits(.isHeader)

            let details = [venue.address, venue.distance.map(DistanceFormat.string(fromMetres:))]
                .compactMap { $0 }
                .filter { !$0.isEmpty }
            if !details.isEmpty {
                Text(details.joined(separator: " · "))
                    .font(.hotMess(.subheadline, semibold: true))
                    .lineLimit(2)
            }
        }
    }

    @ViewBuilder
    private func aboutSection(_ venue: Venue) -> some View {
        DetailSection(String(localized: "About")) {
            if let subtitle = venue.subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(.subheadline)
            }

            if let address = venue.address, !address.isEmpty {
                Button {
                    openInMaps(venue)
                } label: {
                    InfoRow(title: String(localized: "Address"), value: address, systemImage: "mappin")
                }
                .buttonStyle(.plain)
            }

            if let phone = venue.phone, let url = URL(string: "tel://\(phone.filter(\.isNumber))") {
                Link(destination: url) {
                    InfoRow(title: String(localized: "Phone"), value: phone, systemImage: "phone")
                }
            }

            if let distance = venue.distance {
                InfoRow(
                    title: String(localized: "Distance"),
                    value: DistanceFormat.string(fromMetres: distance),
                    systemImage: "figure.walk"
                )
            }

            if let facebookURL = venue.facebookURL {
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

    private func openInMaps(_ venue: Venue) {
        guard let coordinate = venue.coordinate else { return }

        let item = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
        item.name = venue.name
        item.openInMaps()
    }

    private func ensureViewModel() {
        if viewModel == nil {
            viewModel = VenueViewModel(api: model.api, venueID: venueID)
        }
    }

    private func reload() {
        Task {
            ensureViewModel()
            await viewModel?.load()
        }
    }
}
