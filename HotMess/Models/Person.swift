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
    let bannerURL: URL?

    var facebookURL: URL? { facebookID?.profileURL }

    enum CodingKeys: String, CodingKey {
        case id, name, role
        case facebookID = "facebook_id"
        case isLiked = "is_liked"
        case pictureURL = "photo_url"
        case bannerURL = "banner_url"
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        facebookID = try container.decodeIfPresent(FacebookID.self, forKey: .facebookID)
        role = try container.decodeIfPresent(String.self, forKey: .role)
        isLiked = try container.decodeIfPresent(Bool.self, forKey: .isLiked) ?? false
        pictureURL = try container.decodeURLIfPresent(forKey: .pictureURL)
        bannerURL = try container.decodeURLIfPresent(forKey: .bannerURL)
    }

    init(
        id: UUID,
        name: String,
        facebookID: FacebookID? = nil,
        role: String? = nil,
        isLiked: Bool = false,
        pictureURL: URL? = nil,
        bannerURL: URL? = nil
    ) {
        self.id = id
        self.name = name
        self.facebookID = facebookID
        self.role = role
        self.isLiked = isLiked
        self.pictureURL = pictureURL
        self.bannerURL = bannerURL
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
        case events, music, members, groups
        case socialLinks = "social_links"
    }

    init(from decoder: any Decoder) throws {
        person = try Person(from: decoder)

        let container = try decoder.container(keyedBy: CodingKeys.self)
        // The person's events facet; tolerated when missing, which reads as none.
        events = try container.decodeIfPresent(UpcomingEventsFacet.self, forKey: .events)?.upcoming ?? []
        socialLinks = try container.decodeIfPresent([SocialLink].self, forKey: .socialLinks) ?? []
        // Their tracks come through the music facet; a missing one reads as none.
        tracks = try container.decodeIfPresent(MusicFacet.self, forKey: .music)?.tracks ?? []
        members = try container.decodeIfPresent([Person].self, forKey: .members) ?? []
        groups = try container.decodeIfPresent([Person].self, forKey: .groups) ?? []
    }

    func encode(to encoder: any Encoder) throws {
        try person.encode(to: encoder)

        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(UpcomingEventsFacet(upcoming: events), forKey: .events)
        try container.encode(socialLinks, forKey: .socialLinks)
        try container.encode(MusicFacet(tracks: tracks), forKey: .music)
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

/// The `music` facet on a person, read as `music { tracks { nodes { … } } }`:
/// their newest tracks, a connection. A missing or null connection reads as
/// no tracks, and null nodes are dropped.
private struct MusicFacet: Codable {
    let tracks: [Track]

    init(tracks: [Track]) {
        self.tracks = tracks
    }

    enum CodingKeys: String, CodingKey { case tracks }
    private enum ConnectionKeys: String, CodingKey { case nodes }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if (try? container.decodeNil(forKey: .tracks)) == false {
            let connection = try container.nestedContainer(keyedBy: ConnectionKeys.self, forKey: .tracks)
            tracks = try connection.decodeIfPresent([Track?].self, forKey: .nodes)?.compactMap { $0 } ?? []
        } else {
            tracks = []
        }
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        var connection = container.nestedContainer(keyedBy: ConnectionKeys.self, forKey: .tracks)
        try connection.encode(tracks, forKey: .nodes)
    }
}
