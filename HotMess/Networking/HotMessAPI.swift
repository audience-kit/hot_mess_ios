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
            chatOpen: venue.chatOpen,
            recentMessages: venue.recentMessages,
            coverCharge: venue.coverCharge,
            viewerAdmission: venue.viewerAdmission
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

    // MARK: - Cover

    /// Starts paying tonight's cover at a venue. Asking again the same night
    /// returns the same pass and payment.
    func buyCover(venueID: UUID) async throws -> CoverPurchase {
        try await query(
            Documents.buyCover,
            variables: ["venueId": .string(venueID.uuidString)],
            as: BuyCoverResponse.self
        ).buyCover
    }

    /// Checks the payment with Stripe after the payment sheet finishes, so the
    /// pass works before Stripe's webhook arrives.
    func confirmCover(admissionID: String) async throws -> Admission {
        try await query(
            Documents.confirmCover,
            variables: ["admissionId": .string(admissionID)],
            as: ConfirmCoverResponse.self
        ).confirmCover.admission
    }

    func refundAdmission(_ admissionID: String) async throws -> Admission {
        try await query(
            Documents.refundAdmission,
            variables: ["admissionId": .string(admissionID)],
            as: RefundAdmissionResponse.self
        ).refundAdmission.admission
    }

    /// The user's cover passes, newest first.
    func admissions() async throws -> [Admission] {
        try await query(Documents.admissions, variables: [:], as: AdmissionsResponse.self).admissions
    }

    /// Venues whose door the user can work. Empty for almost everyone.
    func doorVenues() async throws -> [DoorVenue] {
        try await query(Documents.doorVenues, variables: [:], as: DoorVenuesResponse.self).doorVenues
    }

    /// Tonight's paid and checked-in counts at a venue's door.
    func doorCounts(venueID: UUID) async throws -> DoorCounts? {
        try await query(
            Documents.venueDoor,
            variables: ["id": .string(venueID.uuidString)],
            as: VenueDoorResponse.self
        ).venue?.door
    }

    func scanAdmission(venueID: UUID, code: String) async throws -> ScanResult {
        try await query(
            Documents.scanAdmission,
            variables: ["venueId": .string(venueID.uuidString), "code": .string(code)],
            as: ScanAdmissionResponse.self
        ).scanAdmission.result
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

        static let messageFields = "id message name user_id: userId avatar_url: avatarUrl sent_at: sentAt"

        /// Enough of a person for a card that links to them.
        static let personSummaryFields = "id name photo_url: pictureUrl"

        static let socialLinkFields = "id handle provider url"

        static let eventFields = """
        id name start_at: startAt end_at: endAt facebook_id: facebookId \
        cover_photo_url: coverPhotoUrl is_featured: isFeatured rsvp: viewerRsvp \
        venue { \(venueFields) }
        """

        static let coverChargeFields = "amount_cents: amountCents total_cents: totalCents currency night from payable"

        static let admissionFields = """
        id status night total_cents: totalCents currency is_refundable: isRefundable \
        pass_secret: passSecret scan_count: scanCount checked_in_at: checkedInAt \
        user_name: userName user_photo_url: userPhotoUrl \
        venue { id name photo_url: photoUrl } event { id name }
        """

        /// Tonight's cover at a venue and the user's pass for it.
        static let venueCoverFields = """
        cover_charge: coverCharge { \(coverChargeFields) } \
        viewer_admission: viewerAdmission { \(admissionFields) }
        """

        static let doorFields = "door { paid_count: paidCount checked_in_count: checkedInCount }"

        static let reportLocation = """
        mutation ReportLocation($position: CoordinatesInput!) {
          reportLocation(input: { position: $position }) {
            now {
              title image_url: imageUrl
              venue {
                \(venueFields)
                recent_messages: recentMessages(limit: 3) { \(messageFields) }
                \(venueCoverFields)
              }
              venues { \(venueFields) }
              locale {
                id name chat_open: chatOpen
                recent_messages: recentMessages(limit: 3) { \(messageFields) }
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
            recent_messages: recentMessages(limit: 3) { \(messageFields) }
            \(venueCoverFields)
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
          event(id: $id) {
            \(eventFields) people { \(personFields) }
            cover_charge: coverCharge { \(coverChargeFields) }
            venue_cover: venue { \(venueCoverFields) }
          }
        }
        """

        static let buyCover = """
        mutation BuyCover($venueId: ID!) {
          buyCover(input: { venueId: $venueId }) {
            admission { \(admissionFields) }
            payment_intent_client_secret: paymentIntentClientSecret
            publishable_key: publishableKey
            stripe_account_id: stripeAccountId
          }
        }
        """

        static let confirmCover = """
        mutation ConfirmCover($admissionId: ID!) {
          confirmCover(input: { admissionId: $admissionId }) { admission { \(admissionFields) } }
        }
        """

        static let refundAdmission = """
        mutation RefundAdmission($admissionId: ID!) {
          refundAdmission(input: { admissionId: $admissionId }) { admission { \(admissionFields) } }
        }
        """

        static let admissions = """
        query Admissions {
          admissions { \(admissionFields) }
        }
        """

        static let doorVenues = """
        query DoorVenues {
          doorVenues { id name photo_url: photoUrl \(doorFields) }
        }
        """

        static let venueDoor = """
        query VenueDoor($id: ID!) {
          venue(id: $id) { id name \(doorFields) }
        }
        """

        static let scanAdmission = """
        mutation ScanAdmission($venueId: ID!, $code: String!) {
          scanAdmission(input: { venueId: $venueId, code: $code }) {
            result { outcome message admission { \(admissionFields) } }
          }
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
    /// The last few lines of the chat room, oldest first; empty unless the
    /// viewer is at the venue or an admin.
    let recentMessages: [VenueMessage]
    /// Tonight's cover, or nil when there's none.
    let coverCharge: CoverCharge?
    /// The user's cover tonight, paid or being paid.
    let viewerAdmission: Admission?

    private enum CodingKeys: String, CodingKey {
        case events, friends
        case socialLinks = "social_links"
        case chatOpen = "chat_open"
        case recentMessages = "recent_messages"
        case coverCharge = "cover_charge"
        case viewerAdmission = "viewer_admission"
    }

    init(from decoder: any Decoder) throws {
        venue = try Venue(from: decoder)
        let container = try decoder.container(keyedBy: CodingKeys.self)
        events = try container.decodeIfPresent([Event].self, forKey: .events) ?? []
        friends = try container.decodeIfPresent([Friend].self, forKey: .friends) ?? []
        socialLinks = try container.decodeIfPresent([SocialLink].self, forKey: .socialLinks) ?? []
        chatOpen = try container.decodeIfPresent(Bool.self, forKey: .chatOpen) ?? false
        recentMessages = (try container.decodeIfPresent([VenueMessage.Payload].self, forKey: .recentMessages) ?? [])
            .map(VenueMessage.init(payload:))
        coverCharge = try container.decodeIfPresent(CoverCharge.self, forKey: .coverCharge)
        viewerAdmission = try container.decodeIfPresent(Admission.self, forKey: .viewerAdmission)
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

struct BuyCoverResponse: Decodable, Sendable {
    let buyCover: CoverPurchase
}

struct AdmissionPayload: Decodable, Sendable {
    let admission: Admission
}

struct ConfirmCoverResponse: Decodable, Sendable {
    let confirmCover: AdmissionPayload
}

struct RefundAdmissionResponse: Decodable, Sendable {
    let refundAdmission: AdmissionPayload
}

struct AdmissionsResponse: Decodable, Sendable {
    let admissions: [Admission]
}

struct DoorVenuesResponse: Decodable, Sendable {
    let doorVenues: [DoorVenue]
}

struct VenueDoorResponse: Decodable, Sendable {
    struct Venue: Decodable, Sendable { let door: DoorCounts? }
    let venue: Venue?
}

struct ScanAdmissionResponse: Decodable, Sendable {
    struct Payload: Decodable, Sendable { let result: ScanResult }
    let scanAdmission: Payload
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
