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
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        title = try container.decodeIfPresent(String.self, forKey: .title) ?? String(localized: "Now")
        venue = try container.decodeIfPresent(Venue.self, forKey: .venue)
        venues = try container.decodeIfPresent([Venue].self, forKey: .venues)
        envelope = try container.decodeIfPresent(GeoPolygon.self, forKey: .envelope)
        friends = try container.decodeIfPresent([Friend].self, forKey: .friends) ?? []
        events = try container.decodeIfPresent([Event].self, forKey: .events) ?? []
        imageURL = try container.decodeURLIfPresent(forKey: .imageURL)
    }

    init(
        title: String,
        venue: Venue? = nil,
        venues: [Venue]? = nil,
        envelope: GeoPolygon? = nil,
        friends: [Friend] = [],
        events: [Event] = [],
        imageURL: URL? = nil
    ) {
        self.title = title
        self.venue = venue
        self.venues = venues
        self.envelope = envelope
        self.friends = friends
        self.events = events
        self.imageURL = imageURL
    }
}
