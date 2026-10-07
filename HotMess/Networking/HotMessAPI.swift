//
//  HotMessAPI.swift
//  HotMess
//

import AudienceKit
import Foundation

/// The typed surface of the Hot Mess API.
///
/// Everything goes through the audience's GraphQL endpoint on the AudienceKit
/// SDK except the version manifest, which is read before sign-in and isn't
/// part of any audience. The GraphQL documents alias fields to the snake_case
/// keys the models already decode, so one set of models serves both.
struct HotMessAPI: Sendable {
    let client: APIClient

    init(client: APIClient) {
        self.client = client
    }

    var baseURL: URL { client.baseURL }

    private var audienceKit: AudienceKitClient { client.audienceKit }

    // MARK: - Home

    /// Records where the device is and returns what's happening there. With no
    /// position there is nothing to look up, so the screen gets an empty "Now".
    func now(near coordinates: Coordinates?) async throws -> Now {
        guard let coordinates else { return Now(title: String(localized: "Now")) }

        return try await query(
            Documents.reportLocation,
            variables: ["position": coordinates.audienceKit.graphQLValue],
            as: ReportLocationResponse.self
        ).reportLocation.now
    }

    // MARK: - Locales

    func closestLocale(to coordinates: Coordinates?) async throws -> AppLocale? {
        guard let coordinates else { return nil }

        do {
            guard let locale = try await audienceKit.closestLocale(near: coordinates.audienceKit),
                  let id = RecordID.uuid(locale.id) else { return nil }
            return AppLocale(id: id, name: locale.name ?? locale.label ?? "")
        } catch let error as AudienceKitError {
            throw APIError(error)
        }
    }

    // MARK: - People

    func person(_ id: UUID) async throws -> PersonDetail {
        let response = try await query(Documents.person, variables: ["id": .string(id.uuidString)], as: PersonResponse.self)
        guard let person = response.person else { throw APIError.notFound }
        return person
    }

    // MARK: - Venues

    /// The venue with its upcoming events, in one request.
    func venue(_ id: UUID) async throws -> VenueOverview {
        let response = try await query(Documents.venue, variables: ["id": .string(id.uuidString)], as: VenueResponse.self)
        guard let venue = response.venue else { throw APIError.notFound }
        return VenueOverview(
            venue: venue.venue,
            events: venue.events,
            friends: venue.friends,
            socialLinks: venue.socialLinks,
            chatOpen: venue.chatOpen
        )
    }

    // MARK: - Events

    func events(in localeID: UUID) async throws -> EventListing {
        let response = try await query(
            Documents.localeEvents,
            variables: ["id": .string(localeID.uuidString)],
            as: LocaleEventsResponse.self
        )
        guard let locale = response.locale else { throw APIError.notFound }
        return EventListing(upcoming: locale.events)
    }

    func event(_ id: UUID) async throws -> EventDetail {
        let response = try await query(Documents.event, variables: ["id": .string(id.uuidString)], as: EventResponse.self)
        guard let event = response.event else { throw APIError.notFound }
        return event
    }

    func setRSVP(_ rsvp: RSVP, forEvent id: UUID) async throws {
        do {
            try await audienceKit.setRSVP(rsvp.state, forEvent: id.uuidString)
        } catch let error as AudienceKitError {
            throw APIError(error)
        }
    }

    // MARK: - Session

    func serviceManifest(device: DeviceDescription) async throws -> VersionInfo {
        try await client.send(Endpoints.manifest(device: device)).apple
    }

    func registerForPush(deviceToken: Data) async throws {
        do {
            try await audienceKit.registerDevice(notificationToken: deviceToken.hexEncodedString)
        } catch let error as AudienceKitError {
            throw APIError(error)
        }
    }

    /// Records where the device is, so the API knows which venue the user is in.
    func reportLocation(_ coordinates: Coordinates) async throws {
        _ = try await now(near: coordinates)
    }

    private func query<Response: Decodable & Sendable>(
        _ document: String,
        variables: [String: GraphQLValue],
        as type: Response.Type
    ) async throws -> Response {
        do {
            return try await audienceKit.graphQL(document, variables: variables, as: type, decoder: .hotMess)
        } catch let error as AudienceKitError {
            throw APIError(error)
        }
    }
}

// MARK: - REST

extension HotMessAPI {
    enum Endpoints {
        /// The minimum supported build. It's read before sign-in and isn't
        /// part of any audience, so it stays on REST.
        static func manifest(device: DeviceDescription) -> Endpoint<ServiceManifest> {
            Endpoint(
                "/",
                method: .post,
                body: JSONBody(ManifestRequest(device: device)),
                requiresAuthentication: false
            )
        }
    }
}

struct ManifestRequest: Encodable, Sendable {
    let device: DeviceDescription
}

// MARK: - GraphQL

extension HotMessAPI {
    /// The GraphQL documents, with fields aliased to the keys the models decode.
    enum Documents {
        static let venueFields = """
        id name address phone distance point \
        facebook_id: facebookId photo_url: photoUrl hero_url: heroUrl is_liked: isLiked
        """

        static let personFields = """
        id name facebook_id: facebookId is_liked: isLiked photo_url: pictureUrl cover_url: coverUrl
        """

        static let friendFields = "id name facebook_id: facebookId"

        /// Enough of a person for a card that links to them.
        static let personSummaryFields = "id name photo_url: pictureUrl"

        static let socialLinkFields = "id handle provider url"

        static let eventFields = """
        id name start_at: startAt end_at: endAt facebook_id: facebookId \
        cover_photo_url: coverPhotoUrl is_featured: isFeatured rsvp: viewerRsvp \
        venue { \(venueFields) }
        """

        static let reportLocation = """
        mutation ReportLocation($position: CoordinatesInput!) {
          reportLocation(input: { position: $position }) {
            now {
              title image_url: imageUrl
              venue {
                \(venueFields)
                recent_messages: recentMessages(limit: 3) {
                  id message name user_id: userId avatar_url: avatarUrl sent_at: sentAt
                }
              }
              venues { \(venueFields) }
              locale {
                id name chat_open: chatOpen
                recent_messages: recentMessages(limit: 3) {
                  id message name user_id: userId avatar_url: avatarUrl sent_at: sentAt
                }
              }
              events { \(eventFields) }
              friends { \(friendFields) }
              friend_venues: friendVenues {
                venue { \(venueFields) }
                friend_count: friendCount
                friends { \(friendFields) }
              }
            }
          }
        }
        """

        static let venue = """
        query Venue($id: ID!) {
          venue(id: $id) {
            \(venueFields) chat_open: chatOpen
            events { \(eventFields) }
            friends { \(friendFields) }
            social_links: socialLinks { \(socialLinkFields) }
          }
        }
        """

        static let localeEvents = """
        query LocaleEvents($id: ID!) {
          locale(id: $id) { events { \(eventFields) } }
        }
        """

        static let event = """
        query Event($id: ID!) {
          event(id: $id) { \(eventFields) people { \(personFields) } }
        }
        """

        static let person = """
        query Person($id: ID!) {
          person(id: $id) {
            \(personFields)
            events { \(eventFields) }
            social_links: socialLinks { \(socialLinkFields) }
            members { \(personSummaryFields) }
            groups { \(personSummaryFields) }
            tracks { id title provider provider_url: providerUrl waveform_url: waveformUrl artwork_url: artworkUrl }
          }
        }
        """
    }
}

struct ReportLocationResponse: Decodable, Sendable {
    struct Payload: Decodable, Sendable { let now: Now }
    let reportLocation: Payload
}

struct PersonResponse: Decodable, Sendable {
    let person: PersonDetail?
}

/// A venue and its events, which GraphQL returns as one object.
struct VenueWithEvents: Decodable, Sendable {
    let venue: Venue
    let events: [Event]
    let friends: [Friend]
    let socialLinks: [SocialLink]
    let chatOpen: Bool

    private enum CodingKeys: String, CodingKey {
        case events, friends
        case socialLinks = "social_links"
        case chatOpen = "chat_open"
    }

    init(from decoder: any Decoder) throws {
        venue = try Venue(from: decoder)
        let container = try decoder.container(keyedBy: CodingKeys.self)
        events = try container.decodeIfPresent([Event].self, forKey: .events) ?? []
        friends = try container.decodeIfPresent([Friend].self, forKey: .friends) ?? []
        socialLinks = try container.decodeIfPresent([SocialLink].self, forKey: .socialLinks) ?? []
        chatOpen = try container.decodeIfPresent(Bool.self, forKey: .chatOpen) ?? false
    }
}

struct VenueResponse: Decodable, Sendable {
    let venue: VenueWithEvents?
}

struct LocaleEventsResponse: Decodable, Sendable {
    struct Locale: Decodable, Sendable { let events: [Event] }
    let locale: Locale?
}

struct EventResponse: Decodable, Sendable {
    let event: EventDetail?
}

extension Coordinates {
    /// The position as the SDK's GraphQL `CoordinatesInput`.
    var audienceKit: AudienceKit.Coordinates {
        AudienceKit.Coordinates(
            latitude: latitude,
            longitude: longitude,
            beaconMajor: beaconMajor,
            beaconMinor: beaconMinor
        )
    }
}

extension RSVP {
    var state: RSVPState {
        switch self {
        case .attending: .attending
        case .maybe: .maybe
        case .declined: .declined
        case .unsure: .unsure
        }
    }
}

extension Data {
    /// APNs device tokens are conventionally sent as lowercase hex.
    var hexEncodedString: String {
        map { String(format: "%02x", $0) }.joined()
    }
}
