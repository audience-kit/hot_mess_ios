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
    var socialLinks: [SocialLink] = []
    /// Whether the user can join the venue's chat room: they're at the venue,
    /// or they're an admin. The way in is hidden otherwise.
    var chatOpen = false
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

    /// Fetches the venue and its events in one GraphQL request.
    func load() async {
        if state.value == nil { state = .loading }

        do {
            state = .loaded(try await api.venue(venueID))
        } catch is CancellationError {
        } catch {
            state = LoadState(catching: error)
        }
    }
}
