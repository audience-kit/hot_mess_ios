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

    var body: some View {
        LoadStateView(state: viewModel?.state ?? .loading, retry: reload) { detail in
            let event = detail.event

            List {
                Section {
                    RemoteImage(url: event.coverURL)
                        .frame(height: 200)
                        .listRowInsets(EdgeInsets())
                }

                Section(String(localized: "Your RSVP")) {
                    RSVPPicker(selection: event.rsvp) { rsvp in
                        Task { await viewModel?.setRSVP(rsvp) }
                    }
                }

                detailsSection(event)

                if let person = event.person {
                    Section(String(localized: "Host")) {
                        NavigationLink(value: AppRoute.person(person.id)) {
                            PersonRow(person: person)
                        }
                    }
                }

                if let venue = event.venue {
                    Section(String(localized: "Venue")) {
                        NavigationLink(value: AppRoute.venue(venue.id)) {
                            VenueRow(venue: venue)
                        }
                    }
                }

                if !detail.people.isEmpty {
                    Section(String(localized: "Going")) {
                        ForEach(detail.people) { person in
                            NavigationLink(value: AppRoute.person(person.id)) {
                                PersonRow(person: person)
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .toolbar {
                if let shareURL = event.shareURL {
                    ShareLink(item: shareURL) {
                        Label(String(localized: "Share"), systemImage: "square.and.arrow.up")
                    }
                }
            }
        }
        .navigationTitle(viewModel?.state.value?.event.name ?? String(localized: "Event"))
        .navigationBarTitleDisplayMode(.inline)
        .task {
            ensureViewModel()
            await viewModel?.load()
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

    @ViewBuilder
    private func detailsSection(_ event: Event) -> some View {
        Section {
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
