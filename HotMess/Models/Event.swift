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

    /// "9:00 PM at The Stud", or just the time when the venue is unknown —
    /// the original force-unwrapped the venue here and crashed on venue-less
    /// events.
    var subtitle: String {
        let time = startDate.formatted(date: .omitted, time: .shortened)

        if let venue {
            return String(localized: "\(time) at \(venue.name)")
        }
        if let person {
            return String(localized: "\(time) with \(person.name)")
        }
        return time
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

    var id: UUID { event.id }

    enum CodingKeys: String, CodingKey {
        case people
    }

    init(from decoder: any Decoder) throws {
        event = try Event(from: decoder)

        let container = try decoder.container(keyedBy: CodingKeys.self)
        people = try container.decodeIfPresent([Person].self, forKey: .people) ?? []
    }

    func encode(to encoder: any Encoder) throws {
        try event.encode(to: encoder)

        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(people, forKey: .people)
    }

    init(event: Event, people: [Person] = []) {
        self.event = event
        self.people = people
    }
}
