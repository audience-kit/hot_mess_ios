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
        venue = try container.decodeIfPresent(Venue.self, forKey: .venue)
        person = try container.decodeIfPresent(Person.self, forKey: .person)
        coverURL = try container.decodeURLIfPresent(forKey: .coverURL)
        isFeatured = try container.decodeIfPresent(Bool.self, forKey: .isFeatured) ?? false
        rsvp = try container.decodeIfPresent(RSVP.self, forKey: .rsvp) ?? .unsure
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
        case people
        case friendPings = "friend_pings"
        case coverCharge = "cover_charge"
        case venueCover = "venue_cover"
    }

    private enum VenueCoverKeys: String, CodingKey {
        case coverCharge = "cover_charge"
        case viewerAdmission = "viewer_admission"
    }

    init(from decoder: any Decoder) throws {
        event = try Event(from: decoder)

        let container = try decoder.container(keyedBy: CodingKeys.self)
        people = try container.decodeIfPresent([Person].self, forKey: .people) ?? []
        coverCharge = try container.decodeIfPresent(CoverCharge.self, forKey: .coverCharge)

        if (try? container.decodeNil(forKey: .venueCover)) == false,
           let venue = try? container.nestedContainer(keyedBy: VenueCoverKeys.self, forKey: .venueCover) {
            venueCoverTonight = try venue.decodeIfPresent(CoverCharge.self, forKey: .coverCharge)
            viewerAdmission = try venue.decodeIfPresent(Admission.self, forKey: .viewerAdmission)
        } else {
            venueCoverTonight = nil
            viewerAdmission = nil
        }
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
