//
//  NowViewModel.swift
//  HotMess
//

import Foundation
import Observation

@MainActor
@Observable
final class NowViewModel {
    private(set) var state: LoadState<Now> = .idle

    private let api: HotMessAPI

    init(api: HotMessAPI) {
        self.api = api
    }

    func load(near coordinates: Coordinates?) async {
        if state.value == nil { state = .loading }

        do {
            state = .loaded(try await api.now(near: coordinates))
        } catch is CancellationError {
            // The view went away; leave whatever was on screen alone.
        } catch {
            state = LoadState(catching: error)
        }
    }

    // MARK: - Pings

    /// The Pings with a join, leave or end in flight.
    private(set) var busyPingIDs: Set<String> = []
    var pingError: String?

    /// "I'm in" on `target`, or on the whole Ping when it's `nil`.
    func join(_ ping: Ping, target: PingTarget?) async {
        await update(ping) { try await $0.joinPing(ping.id, targetID: target?.id) }
    }

    func leave(_ ping: Ping) async {
        await update(ping) { try await $0.leavePing(ping.id) }
    }

    func endMyPing() async {
        guard let ping = state.value?.myPing else { return }
        busyPingIDs.insert(ping.id)
        defer { busyPingIDs.remove(ping.id) }

        do {
            try await api.endPing()
            if let now = state.value { state = .loaded(now.removingMyPing()) }
        } catch {
            pingError = Self.message(for: error)
        }
    }

    /// Shows a Ping the send sheet just sent or edited.
    func show(_ ping: Ping) {
        guard let now = state.value else { return }
        state = .loaded(now.replacing(ping))
    }

    private func update(_ ping: Ping, _ action: (HotMessAPI) async throws -> Ping) async {
        guard !busyPingIDs.contains(ping.id) else { return }
        busyPingIDs.insert(ping.id)
        defer { busyPingIDs.remove(ping.id) }

        do {
            let updated = try await action(api)
            if let now = state.value { state = .loaded(now.replacing(updated)) }
        } catch {
            pingError = Self.message(for: error)
        }
    }

    static func message(for error: any Error) -> String {
        (error as? APIError)?.errorDescription ?? error.localizedDescription
    }
}
