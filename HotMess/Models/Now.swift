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
    /// Tonight's cover at the venue the user is in, or nil when there's none.
    let coverCharge: CoverCharge?
    /// The user's cover tonight at the venue they're in, paid or being paid.
    let viewerAdmission: Admission?
    /// The locale the user is in, or nearest.
    let locale: AppLocale?
    /// Whether the user can join the locale's chat room: they're out in the
    /// locale and not at a venue, or they're an admin.
    let localeChatOpen: Bool
    /// The last few lines of the locale's chat room, oldest first. The API
    /// only sends them to someone in the locale.
    let localeMessages: [VenueMessage]
    /// Where your friends have been lately, most friends first, when you
    /// aren't in a venue yourself.
    let friendVenues: [FriendVenue]
    let events: [Event]
    let imageURL: URL?
    /// The user's own Ping, while it runs.
    var myPing: Ping?
    /// Friends' active Pings, newest first.
    var friendPings: [Ping]

    var isNearVenues: Bool { venues != nil }

    var region: MKCoordinateRegion? {
        if let envelope, let region = envelope.region { return region }
        return MKCoordinateRegion.containing((venues ?? []).compactMap(\.coordinate))
    }

    enum CodingKeys: String, CodingKey {
        case title, venue, venues, envelope, friends, events, locale
        case imageURL = "image_url"
        case friendVenues = "friend_venues"
        case myPing = "my_ping"
        case friendPings = "friend_pings"
    }

    private enum VenueKeys: String, CodingKey {
        case recentMessages = "recent_messages"
        case coverCharge = "cover_charge"
        case viewerAdmission = "viewer_admission"
    }

    private enum LocaleKeys: String, CodingKey {
        case id, name
        case chatOpen = "chat_open"
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
            coverCharge = try venueContainer.decodeIfPresent(CoverCharge.self, forKey: .coverCharge)
            viewerAdmission = try venueContainer.decodeIfPresent(Admission.self, forKey: .viewerAdmission)
        } else {
            recentMessages = []
            coverCharge = nil
            viewerAdmission = nil
        }
        if (try? container.decodeNil(forKey: .locale)) == false,
           let localeContainer = try? container.nestedContainer(keyedBy: LocaleKeys.self, forKey: .locale),
           let id = try localeContainer.decodeIfPresent(UUID.self, forKey: .id) {
            locale = AppLocale(id: id, name: try localeContainer.decodeIfPresent(String.self, forKey: .name) ?? "")
            localeChatOpen = try localeContainer.decodeIfPresent(Bool.self, forKey: .chatOpen) ?? false
            localeMessages = (try localeContainer.decodeIfPresent([VenueMessage.Payload].self, forKey: .recentMessages) ?? [])
                .map(VenueMessage.init(payload:))
        } else {
            locale = nil
            localeChatOpen = false
            localeMessages = []
        }
        events = try container.decodeIfPresent([Event].self, forKey: .events) ?? []
        friendVenues = try container.decodeIfPresent([FriendVenue].self, forKey: .friendVenues) ?? []
        imageURL = try container.decodeURLIfPresent(forKey: .imageURL)
        myPing = try container.decodeIfPresent(Ping.self, forKey: .myPing)
        friendPings = try container.decodeIfPresent([Ping].self, forKey: .friendPings) ?? []
    }

    init(
        title: String,
        venue: Venue? = nil,
        venues: [Venue]? = nil,
        envelope: GeoPolygon? = nil,
        friends: [Friend] = [],
        recentMessages: [VenueMessage] = [],
        coverCharge: CoverCharge? = nil,
        viewerAdmission: Admission? = nil,
        locale: AppLocale? = nil,
        localeChatOpen: Bool = false,
        localeMessages: [VenueMessage] = [],
        friendVenues: [FriendVenue] = [],
        events: [Event] = [],
        imageURL: URL? = nil,
        myPing: Ping? = nil,
        friendPings: [Ping] = []
    ) {
        self.title = title
        self.venue = venue
        self.venues = venues
        self.envelope = envelope
        self.friends = friends
        self.recentMessages = recentMessages
        self.coverCharge = coverCharge
        self.viewerAdmission = viewerAdmission
        self.locale = locale
        self.localeChatOpen = localeChatOpen
        self.localeMessages = localeMessages
        self.friendVenues = friendVenues
        self.events = events
        self.imageURL = imageURL
        self.myPing = myPing
        self.friendPings = friendPings
    }
}
