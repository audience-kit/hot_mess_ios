//
//  Now.swift
//  HotMess
//

import Foundation
import MapKit

/// `/v1/now` — the home screen payload.
///
/// `venues` stays optional on purpose: a missing key means "we don't know where
/// you are, show your friends", while an empty array means "we do know, and
/// there is nothing nearby". The two cases render differently.
struct Now: Decodable, Hashable, Sendable {
    let title: String
    let venue: Venue?
    let venues: [Venue]?
    let envelope: GeoPolygon?
    let friends: [Friend]
    /// The last few lines of the venue's chat room, oldest first. The API
    /// only sends them to someone who is at the venue.
    let recentMessages: [VenueMessage]
    /// Where your friends have been lately, most friends first, when you
    /// aren't in a venue yourself.
    let friendVenues: [FriendVenue]
    let events: [Event]
    let imageURL: URL?

    var isNearVenues: Bool { venues != nil }

    var region: MKCoordinateRegion? {
        if let envelope, let region = envelope.region { return region }
        return MKCoordinateRegion.containing((venues ?? []).compactMap(\.coordinate))
    }

    enum CodingKeys: String, CodingKey {
        case title, venue, venues, envelope, friends, events
        case imageURL = "image_url"
        case friendVenues = "friend_venues"
    }

    private enum VenueKeys: String, CodingKey {
        case recentMessages = "recent_messages"
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        title = try container.decodeIfPresent(String.self, forKey: .title) ?? String(localized: "Now")
        venue = try container.decodeIfPresent(Venue.self, forKey: .venue)
        venues = try container.decodeIfPresent([Venue].self, forKey: .venues)
        envelope = try container.decodeIfPresent(GeoPolygon.self, forKey: .envelope)
        friends = try container.decodeIfPresent([Friend].self, forKey: .friends) ?? []
        if (try? container.decodeNil(forKey: .venue)) == false,
           let venueContainer = try? container.nestedContainer(keyedBy: VenueKeys.self, forKey: .venue) {
            recentMessages = (try venueContainer.decodeIfPresent([VenueMessage.Payload].self, forKey: .recentMessages) ?? [])
                .map(VenueMessage.init(payload:))
        } else {
            recentMessages = []
        }
        events = try container.decodeIfPresent([Event].self, forKey: .events) ?? []
        friendVenues = try container.decodeIfPresent([FriendVenue].self, forKey: .friendVenues) ?? []
        imageURL = try container.decodeURLIfPresent(forKey: .imageURL)
    }

    init(
        title: String,
        venue: Venue? = nil,
        venues: [Venue]? = nil,
        envelope: GeoPolygon? = nil,
        friends: [Friend] = [],
        recentMessages: [VenueMessage] = [],
        friendVenues: [FriendVenue] = [],
        events: [Event] = [],
        imageURL: URL? = nil
    ) {
        self.title = title
        self.venue = venue
        self.venues = venues
        self.envelope = envelope
        self.friends = friends
        self.recentMessages = recentMessages
        self.friendVenues = friendVenues
        self.events = events
        self.imageURL = imageURL
    }
}
