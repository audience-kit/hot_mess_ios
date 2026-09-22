//
//  EventViewModel.swift
//  HotMess
//

import Foundation
import Observation

@MainActor
@Observable
final class EventViewModel {
    private(set) var state: LoadState<EventDetail> = .idle
    private(set) var rsvpError: String?

    private let api: HotMessAPI
    private let eventID: UUID

    init(api: HotMessAPI, eventID: UUID) {
        self.api = api
        self.eventID = eventID
    }

    func load() async {
        if state.value == nil { state = .loading }

        do {
            state = .loaded(try await api.event(eventID))
        } catch is CancellationError {
        } catch {
            state = LoadState(catching: error)
        }
    }

    /// Updates the RSVP optimistically and rolls back if the API refuses, so
    /// the button always reflects what the server actually has.
    func setRSVP(_ rsvp: RSVP) async {
        guard var detail = state.value else { return }

        let previous = detail.event.rsvp
        guard previous != rsvp else { return }

        detail.event.rsvp = rsvp
        state = .loaded(detail)
        rsvpError = nil

        do {
            try await api.setRSVP(rsvp, forEvent: eventID)
        } catch {
            detail.event.rsvp = previous
            state = .loaded(detail)
            rsvpError = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
    }

    func dismissRSVPError() {
        rsvpError = nil
    }
}
