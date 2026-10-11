//
//  Event.swift
//  HotMess
//

import Foundation

struct Event: Codable, Hashable, Sendable, Identifiable {
    let id: UUID
    let name: String
    let startDate: Date
    let endDate: Date?
    let facebookID: FacebookID?
    let venue: Venue?
    let person: Person?
    let coverURL: URL?
    let isFeatured: Bool
    var rsvp: RSVP

    var facebookURL: URL? { facebookID?.eventURL }

    var shareURL: URL? { URL(string: "https://hotmess.social/events/\(id.uuidString.lowercased())") }

    /// Where an event with no venue yet is.
    static let toBeAnnounced = String(localized: "To be announced")

    /// "9:00 PM at The Stud", or "9:00 PM · To be announced" when the venue
    /// isn't set yet — the original force-unwrapped the venue here and
    /// crashed on venue-less events.
    var subtitle: String {
        let time = startDate.formatted(date: .omitted, time: .shortened)

        if let venue {
            return String(localized: "\(time) at \(venue.name)")
        }
        if let person {
            return String(localized: "\(time) with \(person.name) · \(Self.toBeAnnounced)")
        }
        return "\(time) · \(Self.toBeAnnounced)"
    }

    enum CodingKeys: String, CodingKey {
        case id, name, venue, person, rsvp
        case startDate = "start_at"
        case endDate = "end_at"
        case facebookID = "facebook_id"
        case coverURL = "cover_photo_url"
        case isFeatured = "is_featured"
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        startDate = try container.decode(Date.self, forKey: .startDate)
        endDate = try container.decodeIfPresent(Date.self, forKey: .endDate)
        facebookID = try container.decodeIfPresent(FacebookID.self, forKey: .facebookID)
        venue = try container.decodeIfPresent(EventVenueFacet.self, forKey: .venue)?.venue
        person = try container.decodeIfPresent(Person.self, forKey: .person)
        coverURL = try container.decodeURLIfPresent(forKey: .coverURL)
        isFeatured = try container.decodeIfPresent(Bool.self, forKey: .isFeatured) ?? false
        rsvp = try container.decodeIfPresent(RSVP.self, forKey: .rsvp) ?? .unsure
    }

    /// Writes the shape `init(from:)` reads, with `venue` as the venue facet.
    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(startDate, forKey: .startDate)
        try container.encodeIfPresent(endDate, forKey: .endDate)
        try container.encodeIfPresent(facebookID, forKey: .facebookID)
        try container.encode(EventVenueFacet(venue: venue), forKey: .venue)
        try container.encodeIfPresent(person, forKey: .person)
        try container.encodeIfPresent(coverURL, forKey: .coverURL)
        try container.encode(isFeatured, forKey: .isFeatured)
        try container.encode(rsvp, forKey: .rsvp)
    }

    init(
        id: UUID,
        name: String,
        startDate: Date,
        endDate: Date? = nil,
        facebookID: FacebookID? = nil,
        venue: Venue? = nil,
        person: Person? = nil,
        coverURL: URL? = nil,
        isFeatured: Bool = false,
        rsvp: RSVP = .unsure
    ) {
        self.id = id
        self.name = name
        self.startDate = startDate
        self.endDate = endDate
        self.facebookID = facebookID
        self.venue = venue
        self.person = person
        self.coverURL = coverURL
        self.isFeatured = isFeatured
        self.rsvp = rsvp
    }
}

/// An event's `venue` facet: its venue, or nil while it is to be announced.
/// The API always sends the facet; a missing one reads as no venue.
struct EventVenueFacet: Codable, Hashable, Sendable {
    /// The venue's name, or "To be announced".
    let name: String?
    let venue: Venue?

    init(venue: Venue?) {
        self.name = venue?.name ?? Event.toBeAnnounced
        self.venue = venue
    }

    enum CodingKeys: String, CodingKey { case name, venue }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        venue = try container.decodeIfPresent(Venue.self, forKey: .venue)
    }
}

/// The `events` facet on a venue, locale or person: `upcoming`, soonest
/// first, a connection the documents read as `upcoming { nodes { … } }`.
/// Without `first` the connection holds every upcoming event. A missing or
/// null facet or connection reads as no events.
struct UpcomingEventsFacet: Codable, Hashable, Sendable {
    let upcoming: [Event]

    init(upcoming: [Event] = []) {
        self.upcoming = upcoming
    }

    enum CodingKeys: String, CodingKey { case upcoming }
    private enum ConnectionKeys: String, CodingKey { case nodes }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if (try? container.decodeNil(forKey: .upcoming)) == false {
            let connection = try container.nestedContainer(keyedBy: ConnectionKeys.self, forKey: .upcoming)
            upcoming = try connection.decodeIfPresent([Event].self, forKey: .nodes) ?? []
        } else {
            upcoming = []
        }
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        var connection = container.nestedContainer(keyedBy: ConnectionKeys.self, forKey: .upcoming)
        try connection.encode(upcoming, forKey: .nodes)
    }
}

/// `/v1/events/{id}` — an event plus the people going.
struct EventDetail: Codable, Hashable, Sendable, Identifiable {
    var event: Event
    let people: [Person]
    /// The cover at its venue that night, or nil when there's none (or it
    /// sells tickets).
    let coverCharge: CoverCharge?
    /// The cover at its venue tonight, whatever night the event is, so the
    /// screen can tell whether the event's cover is tonight's.
    let venueCoverTonight: CoverCharge?
    /// The user's cover tonight at its venue, paid or being paid.
    let viewerAdmission: Admission?
    /// Friends' Pings that pick this event. Read from GraphQL only, so it
    /// isn't encoded.
    var friendPings: [Ping]

    var id: UUID { event.id }

    /// Whether the event's cover is the venue's cover tonight, so it can be
    /// paid now.
    var isCoverTonight: Bool {
        guard let coverCharge, let venueCoverTonight else { return false }
        return coverCharge.night == venueCoverTonight.night
    }

    enum CodingKeys: String, CodingKey {
        case people, cover
        case friendPings = "friend_pings"
        case venueCover = "venue_cover"
    }

    /// `venue_cover` is the event's venue facet again, holding only the
    /// venue's cover facet.
    private enum VenueFacetKeys: String, CodingKey { case venue }
    private enum VenueKeys: String, CodingKey { case cover }

    init(from decoder: any Decoder) throws {
        event = try Event(from: decoder)

        let container = try decoder.container(keyedBy: CodingKeys.self)
        people = try container.decodeIfPresent([Person].self, forKey: .people) ?? []
        coverCharge = try container.decodeIfPresent(CoverFacet.self, forKey: .cover)?.coverCharge

        var venueCover: CoverFacet?
        if (try? container.decodeNil(forKey: .venueCover)) == false,
           let facet = try? container.nestedContainer(keyedBy: VenueFacetKeys.self, forKey: .venueCover),
           (try? facet.decodeNil(forKey: .venue)) == false,
           let venue = try? facet.nestedContainer(keyedBy: VenueKeys.self, forKey: .venue) {
            venueCover = try venue.decodeIfPresent(CoverFacet.self, forKey: .cover)
        }
        venueCoverTonight = venueCover?.coverCharge
        viewerAdmission = venueCover?.viewerAdmission
        friendPings = try container.decodeIfPresent([Ping].self, forKey: .friendPings) ?? []
    }

    func encode(to encoder: any Encoder) throws {
        try event.encode(to: encoder)

        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(people, forKey: .people)
    }

    init(
        event: Event,
        people: [Person] = [],
        coverCharge: CoverCharge? = nil,
        venueCoverTonight: CoverCharge? = nil,
        viewerAdmission: Admission? = nil,
        friendPings: [Ping] = []
    ) {
        self.event = event
        self.people = people
        self.coverCharge = coverCharge
        self.venueCoverTonight = venueCoverTonight
        self.viewerAdmission = viewerAdmission
        self.friendPings = friendPings
    }
}
