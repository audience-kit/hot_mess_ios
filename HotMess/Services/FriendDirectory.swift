//
//  FriendDirectory.swift
//  HotMess
//

import Foundation
import Observation

/// The user's friends the app has seen so far, by user ID.
///
/// Chat rooms only ever send a sender's short name ("Aurora B."), so a full
/// name never reaches a stranger's phone. The design shows friends by their
/// full name, so chat swaps it in for anyone in here. The API has no list of
/// all of a user's friends; this collects the ones Now and venue screens
/// already load (friends out now, friends here, where friends are).
@MainActor
@Observable
final class FriendDirectory {
    private(set) var byID: [UUID: Friend] = [:]

    func remember(_ friends: some Sequence<Friend>) {
        for friend in friends where !friend.name.isEmpty {
            byID[friend.id] = friend
        }
    }

    func remember(_ now: Now) {
        remember(now.friends)
        remember(now.friendVenues.flatMap(\.friends))
    }

    func forget() {
        byID = [:]
    }
}
