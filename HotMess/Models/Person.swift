//
//  Person.swift
//  HotMess
//

import Foundation

struct Person: Codable, Hashable, Sendable, Identifiable {
    let id: UUID
    let name: String
    let facebookID: FacebookID?
    let role: String?
    let isLiked: Bool
    let pictureURL: URL?
    let coverURL: URL?

    var facebookURL: URL? { facebookID?.profileURL }

    enum CodingKeys: String, CodingKey {
        case id, name, role
        case facebookID = "facebook_id"
        case isLiked = "is_liked"
        case pictureURL = "photo_url"
        case coverURL = "cover_url"
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        facebookID = try container.decodeIfPresent(FacebookID.self, forKey: .facebookID)
        role = try container.decodeIfPresent(String.self, forKey: .role)
        isLiked = try container.decodeIfPresent(Bool.self, forKey: .isLiked) ?? false
        pictureURL = try container.decodeURLIfPresent(forKey: .pictureURL)
        coverURL = try container.decodeURLIfPresent(forKey: .coverURL)
    }

    init(
        id: UUID,
        name: String,
        facebookID: FacebookID? = nil,
        role: String? = nil,
        isLiked: Bool = false,
        pictureURL: URL? = nil,
        coverURL: URL? = nil
    ) {
        self.id = id
        self.name = name
        self.facebookID = facebookID
        self.role = role
        self.isLiked = isLiked
        self.pictureURL = pictureURL
        self.coverURL = coverURL
    }
}

/// `/v1/people/{id}` — a person plus everything hanging off them.
struct PersonDetail: Codable, Hashable, Sendable, Identifiable {
    let person: Person
    let events: [Event]
    let socialLinks: [SocialLink]
    let tracks: [Track]
    /// The people this person is made of, such as a troupe's performers.
    let members: [Person]
    /// The people this person is part of, such as their troupes.
    let groups: [Person]

    var id: UUID { person.id }
    var name: String { person.name }

    /// Where fans can tip them (Cash App, Venmo), each opening that app.
    var tipLinks: [SocialLink] { socialLinks.filter { $0.tipApp != nil && $0.url != nil } }
    /// Their social profiles, without the tip links.
    var profileLinks: [SocialLink] { socialLinks.filter { $0.tipApp == nil } }

    enum CodingKeys: String, CodingKey {
        case events, tracks, members, groups
        case socialLinks = "social_links"
    }

    init(from decoder: any Decoder) throws {
        person = try Person(from: decoder)

        let container = try decoder.container(keyedBy: CodingKeys.self)
        events = try container.decodeIfPresent([Event].self, forKey: .events) ?? []
        socialLinks = try container.decodeIfPresent([SocialLink].self, forKey: .socialLinks) ?? []
        tracks = try container.decodeIfPresent([Track].self, forKey: .tracks) ?? []
        members = try container.decodeIfPresent([Person].self, forKey: .members) ?? []
        groups = try container.decodeIfPresent([Person].self, forKey: .groups) ?? []
    }

    func encode(to encoder: any Encoder) throws {
        try person.encode(to: encoder)

        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(events, forKey: .events)
        try container.encode(socialLinks, forKey: .socialLinks)
        try container.encode(tracks, forKey: .tracks)
        try container.encode(members, forKey: .members)
        try container.encode(groups, forKey: .groups)
    }

    init(
        person: Person,
        events: [Event] = [],
        socialLinks: [SocialLink] = [],
        tracks: [Track] = [],
        members: [Person] = [],
        groups: [Person] = []
    ) {
        self.person = person
        self.events = events
        self.socialLinks = socialLinks
        self.tracks = tracks
        self.members = members
        self.groups = groups
    }
}
