//
//  ChatRoom.swift
//  HotMess
//

import Foundation

/// A chat room: a venue's, for people at the venue, or a locale's, for
/// people out in the locale who aren't at a venue. Both deliver the same events,
/// so one connection and one screen serve either.
struct ChatRoom: Hashable, Sendable {
    enum Kind: Hashable, Sendable {
        case venue
        case locale
    }

    let kind: Kind
    let id: UUID
    let name: String
    /// The venue's photo, for the first face in the room's Here now strip.
    var photoURL: URL? = nil

    static func venue(_ venue: Venue) -> ChatRoom {
        ChatRoom(kind: .venue, id: venue.id, name: venue.name, photoURL: venue.photoURL)
    }

    static func locale(_ locale: AppLocale) -> ChatRoom {
        ChatRoom(kind: .locale, id: locale.id, name: locale.name)
    }

    /// The GraphQL subscription field that follows the room.
    var channelName: String {
        switch kind {
        case .venue: "venueChat"
        case .locale: "localeChat"
        }
    }

    /// The argument naming the room, to the subscription and to
    /// `sendMyChatMessage`'s input.
    var subscriptionKey: String {
        switch kind {
        case .venue: "venueId"
        case .locale: "localeId"
        }
    }
}
