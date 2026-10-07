//
//  PingPlaceJoin.swift
//  HotMess
//

import Foundation

/// "I'm in" from a venue or event page, where one button covers every
/// friend's Ping that picks the place. `targets` picks out each Ping's picks
/// for the place.
enum PingPlaceJoin {
    /// Whether the user is in on a pick here on every one of `pings`.
    static func isJoined(_ pings: [Ping], userID: UUID?, targets: (Ping) -> [PingTarget]) -> Bool {
        !pings.isEmpty && pings.allSatisfy { ping in
            targets(ping).contains { ping.isJoined($0, by: userID) }
        }
    }

    /// The Pings to join, each with its first pick here, leaving out the
    /// ones the user is already in on here.
    static func pendingJoins(_ pings: [Ping], userID: UUID?, targets: (Ping) -> [PingTarget]) -> [(ping: Ping, target: PingTarget)] {
        pings.compactMap { ping in
            let here = targets(ping)
            guard let first = here.first, !here.contains(where: { ping.isJoined($0, by: userID) }) else { return nil }
            return (ping, first)
        }
    }

    /// Joins each Ping on its pick here and returns the updated Pings.
    @MainActor
    static func join(
        _ pings: [Ping],
        userID: UUID?,
        api: HotMessAPI,
        targets: (Ping) -> [PingTarget]
    ) async throws -> [Ping] {
        var updated: [Ping] = []
        for (ping, target) in pendingJoins(pings, userID: userID, targets: targets) {
            updated.append(try await api.joinPing(ping.id, targetID: target.id))
        }
        return updated
    }

    /// Leaves each Ping the user is in on here and returns the updated Pings.
    @MainActor
    static func leave(
        _ pings: [Ping],
        userID: UUID?,
        api: HotMessAPI,
        targets: (Ping) -> [PingTarget]
    ) async throws -> [Ping] {
        var updated: [Ping] = []
        for ping in pings where targets(ping).contains(where: { ping.isJoined($0, by: userID) }) {
            updated.append(try await api.leavePing(ping.id))
        }
        return updated
    }
}
