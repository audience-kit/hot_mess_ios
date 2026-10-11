//
//  Now.swift
//  HotMess
//

import Foundation
import MapKit

/// What `reportLocation` says about where the user is, shaped for the Now screen.
///
/// The API returns only where the user is: the `venue` they're in, else their
/// `locale` and its `nearby_venues`. Everything else comes from those objects'
/// facets (`friends`, `events`, chat) and the audience's `ping` feed, and the
/// title and hero are built here from the venue or locale.
///
/// `venues` stays optional on purpose: a missing key means "we don't know where
/// you are, show your friends", while an empty array means "we do know, and
/// there is nothing nearby". The two cases render differently.
struct Now: Decodable, Hashable, Sendable {
    /// How many of the locale's upcoming events the screen lists.
    static let localeEventLimit = 5

    let title: String
    let venue: Venue?
    let venues: [Venue]?
    let friends: [Friend]
    /// The last few lines of the venue's chat room, oldest first. The API
    /// only sends them to someone who is at the venue.
    let recentMessages: [VenueMessage]
    /// Tonight's cover at the venue the user is in, or nil when there's none.
    let coverCharge: CoverCharge?
    /// The user's cover tonight at the venue the user is in, paid or being paid.
    let viewerAdmission: Admission?
    /// Who is on at the venue the user is in right now.
    let onNow: [Appearance]
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
        MKCoordinateRegion.containing((venues ?? []).compactMap(\.coordinate))
    }

    enum CodingKeys: String, CodingKey {
        case venue, locale, audience
        case nearbyVenues = "nearby_venues"
    }

    private enum VenueKeys: String, CodingKey {
        case events, friends
        case recentMessages = "recent_messages"
        case coverCharge = "cover_charge"
        case viewerAdmission = "viewer_admission"
        case onNow = "on_now"
    }

    private enum LocaleKeys: String, CodingKey {
        case id, name, events, friends
        case heroURL = "hero_url"
        case chatOpen = "chat_open"
        case recentMessages = "recent_messages"
    }

    private enum AudienceKeys: String, CodingKey { case ping }

    private enum PingKeys: String, CodingKey {
        case myPing = "my_ping"
        case friendPings = "friend_pings"
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let venue = try container.decodeIfPresent(Venue.self, forKey: .venue)
        self.venue = venue
        venues = try container.decodeIfPresent([Venue].self, forKey: .nearbyVenues)
        var venueEvents: [Event] = []
        var venueFriends: [Friend] = []
        if (try? container.decodeNil(forKey: .venue)) == false,
           let venueContainer = try? container.nestedContainer(keyedBy: VenueKeys.self, forKey: .venue) {
            recentMessages = (try venueContainer.decodeIfPresent([VenueMessage.Payload].self, forKey: .recentMessages) ?? [])
                .map(VenueMessage.init(payload:))
            coverCharge = try venueContainer.decodeIfPresent(CoverCharge.self, forKey: .coverCharge)
            viewerAdmission = try venueContainer.decodeIfPresent(Admission.self, forKey: .viewerAdmission)
            onNow = venueContainer.decodeAppearances(forKey: .onNow)
            venueEvents = try venueContainer.decodeIfPresent([Event].self, forKey: .events) ?? []
            venueFriends = try venueContainer.decodeIfPresent(FriendsFacet.self, forKey: .friends)?.list ?? []
        } else {
            recentMessages = []
            coverCharge = nil
            viewerAdmission = nil
            onNow = []
        }

        var localeName: String?
        var localeHero: URL?
        var localeEvents: [Event] = []
        var localeFriends: FriendsFacet?
        if (try? container.decodeNil(forKey: .locale)) == false,
           let localeContainer = try? container.nestedContainer(keyedBy: LocaleKeys.self, forKey: .locale),
           let id = try localeContainer.decodeIfPresent(UUID.self, forKey: .id) {
            let name = try localeContainer.decodeIfPresent(String.self, forKey: .name) ?? ""
            locale = AppLocale(id: id, name: name)
            localeName = name
            localeChatOpen = try localeContainer.decodeIfPresent(Bool.self, forKey: .chatOpen) ?? false
            localeMessages = (try localeContainer.decodeIfPresent([VenueMessage.Payload].self, forKey: .recentMessages) ?? [])
                .map(VenueMessage.init(payload:))
            localeHero = try localeContainer.decodeURLIfPresent(forKey: .heroURL)
            localeEvents = try localeContainer.decodeIfPresent([Event].self, forKey: .events) ?? []
            localeFriends = try localeContainer.decodeIfPresent(FriendsFacet.self, forKey: .friends)
        } else {
            locale = nil
            localeChatOpen = false
            localeMessages = []
        }

        if let venue {
            title = venue.name
            imageURL = venue.heroURL
            events = venueEvents
            friends = venueFriends
            friendVenues = []
        } else {
            title = localeName.map { String(localized: "Happening Now in \($0)") } ?? String(localized: "Happening Now")
            imageURL = localeHero
            events = Array(localeEvents.prefix(Self.localeEventLimit))
            friends = localeFriends?.list ?? []
            friendVenues = localeFriends?.venues ?? []
        }

        if (try? container.decodeNil(forKey: .audience)) == false,
           let audience = try? container.nestedContainer(keyedBy: AudienceKeys.self, forKey: .audience),
           (try? audience.decodeNil(forKey: .ping)) == false,
           let ping = try? audience.nestedContainer(keyedBy: PingKeys.self, forKey: .ping) {
            myPing = try ping.decodeIfPresent(Ping.self, forKey: .myPing)
            friendPings = try ping.decodeIfPresent([Ping].self, forKey: .friendPings) ?? []
        } else {
            myPing = nil
            friendPings = []
        }
    }

    init(
        title: String,
        venue: Venue? = nil,
        venues: [Venue]? = nil,
        friends: [Friend] = [],
        recentMessages: [VenueMessage] = [],
        coverCharge: CoverCharge? = nil,
        viewerAdmission: Admission? = nil,
        onNow: [Appearance] = [],
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
        self.friends = friends
        self.recentMessages = recentMessages
        self.coverCharge = coverCharge
        self.viewerAdmission = viewerAdmission
        self.onNow = onNow
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
