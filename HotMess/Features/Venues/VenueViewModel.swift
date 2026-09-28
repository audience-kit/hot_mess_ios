//
//  VenueViewModel.swift
//  HotMess
//

import Foundation
import Observation

/// A venue plus the events and friends shown alongside it on its screen.
struct VenueOverview: Sendable, Equatable {
    var venue: Venue
    var events: [Event] = []
    var friends: [Friend] = []
}

@MainActor
@Observable
final class VenueViewModel {
    private(set) var state: LoadState<VenueOverview> = .idle

    private let api: HotMessAPI
    private let venueID: UUID

    init(api: HotMessAPI, venueID: UUID) {
        self.api = api
        self.venueID = venueID
    }

    /// Fetches the venue, its events and who is there concurrently. The
    /// original chained three callbacks and reloaded the table three times.
    func load() async {
        if state.value == nil { state = .loading }

        do {
            async let venue = api.venue(venueID)
            async let events = api.events(atVenue: venueID)
            async let friends = api.friends(atVenue: venueID)

            state = .loaded(
                VenueOverview(
                    venue: try await venue,
                    events: try await events,
                    friends: (try? await friends) ?? []
                )
            )
        } catch is CancellationError {
        } catch {
            state = LoadState(catching: error)
        }
    }
}
