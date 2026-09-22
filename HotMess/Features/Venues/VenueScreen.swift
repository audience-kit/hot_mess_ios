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

    var body: some View {
        LoadStateView(state: viewModel?.state ?? .loading, retry: reload) { overview in
            let venue = overview.venue

            List {
                Section {
                    RemoteImage(url: venue.heroURL ?? venue.photoURL)
                        .frame(height: 200)
                        .listRowInsets(EdgeInsets())
                }

                aboutSection(venue)

                Section(String(localized: "Chat")) {
                    NavigationLink(value: AppRoute.venueChat(venue)) {
                        Label(String(localized: "Join the room"), systemImage: "bubble.left.and.bubble.right")
                    }
                }

                if !overview.friends.isEmpty {
                    Section(String(localized: "Friends Here")) {
                        FriendStrip(friends: overview.friends)
                            .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                    }
                }

                Section(String(localized: "Events")) {
                    if overview.events.isEmpty {
                        Text("No upcoming events.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(overview.events) { event in
                            NavigationLink(value: AppRoute.event(event.id)) {
                                EventRow(event: event)
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .toolbar {
                if let shareURL = venue.shareURL {
                    ShareLink(item: shareURL) {
                        Label(String(localized: "Share"), systemImage: "square.and.arrow.up")
                    }
                }
            }
        }
        .navigationTitle(viewModel?.state.value?.venue.name ?? String(localized: "Venue"))
        .navigationBarTitleDisplayMode(.inline)
        .task {
            ensureViewModel()
            await viewModel?.load()
        }
    }

    @ViewBuilder
    private func aboutSection(_ venue: Venue) -> some View {
        Section(String(localized: "About")) {
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
