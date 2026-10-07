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

    // MARK: - Pings

    private(set) var isUpdatingPings = false
    var pingError: String?

    /// Friends' running Pings that pick this event.
    var activePings: [Ping] {
        Ping.friendFeed(state.value?.friendPings ?? [], at: .now)
    }

    /// Pings can only be for tonight.
    var isTonight: Bool {
        guard let event = state.value?.event else { return false }
        return PingChoices.isTonight(event)
    }

    func isJoinedHere(userID: UUID?) -> Bool {
        PingPlaceJoin.isJoined(activePings, userID: userID) { self.targets(of: $0) }
    }

    func joinHere(userID: UUID?) async {
        await updatePings { pings, api in
            try await PingPlaceJoin.join(pings, userID: userID, api: api) { self.targets(of: $0) }
        }
    }

    func leaveHere(userID: UUID?) async {
        await updatePings { pings, api in
            try await PingPlaceJoin.leave(pings, userID: userID, api: api) { self.targets(of: $0) }
        }
    }

    private func targets(of ping: Ping) -> [PingTarget] {
        ping.target(forEvent: eventID).map { [$0] } ?? []
    }

    private func updatePings(_ action: ([Ping], HotMessAPI) async throws -> [Ping]) async {
        guard !isUpdatingPings, var detail = state.value else { return }
        isUpdatingPings = true
        defer { isUpdatingPings = false }

        do {
            for ping in try await action(activePings, api) {
                detail.friendPings = detail.friendPings.replacing(ping)
            }
            state = .loaded(detail)
        } catch {
            pingError = NowViewModel.message(for: error)
            await load()
        }
    }
}
