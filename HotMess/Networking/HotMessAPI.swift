//
//  HotMessAPI.swift
//  HotMess
//

import Foundation

/// The typed surface of the Hot Mess API.
///
/// Replaces `DataService`: every call is `async throws` and returns a concrete
/// model, so a failure is something the caller has to deal with instead of a
/// callback that silently never fires.
struct HotMessAPI: Sendable {
    let client: APIClient

    init(client: APIClient) {
        self.client = client
    }

    var baseURL: URL { client.baseURL }

    // MARK: - Home

    func now(near coordinates: Coordinates?) async throws -> Now {
        try await client.send(Endpoints.now(near: coordinates))
    }

    // MARK: - Locales

    func closestLocale(to coordinates: Coordinates?) async throws -> AppLocale {
        try await client.send(Endpoints.closestLocale(to: coordinates))
    }

    // MARK: - People

    func people(in localeID: UUID) async throws -> [Person] {
        try await client.send(Endpoints.people(in: localeID)).people
    }

    func person(_ id: UUID) async throws -> PersonDetail {
        try await client.send(Endpoints.person(id)).person
    }

    // MARK: - Venues

    func venues(in localeID: UUID?, near coordinates: Coordinates?) async throws -> VenueCollection {
        try await client.send(Endpoints.venues(in: localeID, near: coordinates))
    }

    func venue(_ id: UUID) async throws -> Venue {
        try await client.send(Endpoints.venue(id)).venue
    }

    func friends(atVenue id: UUID) async throws -> [Friend] {
        try await client.send(Endpoints.friends(atVenue: id)).friends
    }

    // MARK: - Events

    func events(in localeID: UUID) async throws -> EventListing {
        try await client.send(Endpoints.events(in: localeID))
    }

    func events(atVenue id: UUID) async throws -> [Event] {
        try await client.send(Endpoints.events(atVenue: id)).events
    }

    func event(_ id: UUID) async throws -> EventDetail {
        try await client.send(Endpoints.event(id)).event
    }

    func setRSVP(_ rsvp: RSVP, forEvent id: UUID) async throws {
        try await client.send(Endpoints.rsvp(rsvp, forEvent: id))
    }

    // MARK: - Session

    func signIn(facebookToken: String, device: DeviceDescription) async throws -> AuthenticatedSession {
        try await client.send(Endpoints.token(facebookToken: facebookToken, device: device))
    }

    func me() async throws -> User {
        try await client.send(Endpoints.me)
    }

    func serviceManifest(device: DeviceDescription) async throws -> VersionInfo {
        try await client.send(Endpoints.manifest(device: device)).apple
    }

    func registerForPush(deviceToken: Data, vendorIdentifier: String) async throws {
        try await client.send(
            Endpoints.registerDevice(token: deviceToken, vendorIdentifier: vendorIdentifier)
        )
    }

    func reportLocation(_ coordinates: Coordinates) async throws {
        try await client.send(Endpoints.reportLocation(coordinates))
    }
}

// MARK: - Endpoint definitions

extension HotMessAPI {
    enum Endpoints {
        static func now(near coordinates: Coordinates?) -> Endpoint<Now> {
            Endpoint("/v1/now", query: coordinates?.queryItems ?? [])
        }

        static func closestLocale(to coordinates: Coordinates?) -> Endpoint<AppLocale> {
            Endpoint("/v1/locales/closest", query: coordinates?.queryItems ?? [])
        }

        static func people(in localeID: UUID) -> Endpoint<PeopleEnvelope> {
            Endpoint("/v1/locales/\(localeID.uuidString)/people")
        }

        static func person(_ id: UUID) -> Endpoint<PersonEnvelope> {
            Endpoint("/v1/people/\(id.uuidString)")
        }

        static func venues(in localeID: UUID?, near coordinates: Coordinates?) -> Endpoint<VenueCollection> {
            guard let localeID else {
                return Endpoint("/v1/venues", query: coordinates?.queryItems ?? [])
            }

            return Endpoint(
                "/v1/locales/\(localeID.uuidString)/venues",
                query: coordinates?.queryItems ?? []
            )
        }

        static func venue(_ id: UUID) -> Endpoint<VenueEnvelope> {
            Endpoint("/v1/venues/\(id.uuidString)")
        }

        static func friends(atVenue id: UUID) -> Endpoint<FriendsEnvelope> {
            Endpoint("/v1/venues/\(id.uuidString)/friends")
        }

        static func events(in localeID: UUID) -> Endpoint<EventListing> {
            Endpoint("/v1/locales/\(localeID.uuidString)/events")
        }

        static func events(atVenue id: UUID) -> Endpoint<EventsEnvelope> {
            Endpoint("/v1/venues/\(id.uuidString)/events")
        }

        static func event(_ id: UUID) -> Endpoint<EventEnvelope> {
            Endpoint("/v1/events/\(id.uuidString)")
        }

        static func rsvp(_ rsvp: RSVP, forEvent id: UUID) -> Endpoint<EmptyResponse> {
            Endpoint(
                "/v1/events/\(id.uuidString)/rsvp",
                method: .post,
                body: JSONBody(RSVPRequest(state: rsvp))
            )
        }

        static func token(facebookToken: String, device: DeviceDescription) -> Endpoint<AuthenticatedSession> {
            Endpoint(
                "/v1/token",
                method: .post,
                body: JSONBody(TokenRequest(facebookToken: facebookToken, device: device)),
                requiresAuthentication: false
            )
        }

        static var me: Endpoint<User> {
            Endpoint("/v1/me")
        }

        static func manifest(device: DeviceDescription) -> Endpoint<ServiceManifest> {
            Endpoint(
                "/",
                method: .post,
                body: JSONBody(ManifestRequest(device: device)),
                requiresAuthentication: false
            )
        }

        static func registerDevice(token: Data, vendorIdentifier: String) -> Endpoint<EmptyResponse> {
            Endpoint(
                "/v1/devices/",
                method: .post,
                body: JSONBody(
                    PushRegistrationRequest(
                        deviceType: "apple",
                        vendorIdentifier: vendorIdentifier,
                        notificationToken: token.base64EncodedString()
                    )
                )
            )
        }

        static func reportLocation(_ coordinates: Coordinates) -> Endpoint<EmptyResponse> {
            Endpoint(
                "/v1/me/location",
                method: .post,
                body: JSONBody(LocationReport(coordinates: coordinates))
            )
        }
    }
}

// MARK: - Response envelopes

struct PeopleEnvelope: Decodable, Sendable {
    let people: [Person]
}

struct PersonEnvelope: Decodable, Sendable {
    let person: PersonDetail
}

struct VenueEnvelope: Decodable, Sendable {
    let venue: Venue
}

struct FriendsEnvelope: Decodable, Sendable {
    let friends: [Friend]
}

struct EventsEnvelope: Decodable, Sendable {
    let events: [Event]
}

struct EventEnvelope: Decodable, Sendable {
    let event: EventDetail
}

// MARK: - Request bodies

struct DeviceDescription: Encodable, Sendable, Hashable {
    var type = "apple"
    var identifier: String
    var version: String
    var build: String
    var model: String
}

struct TokenRequest: Encodable, Sendable {
    let facebookToken: String
    let device: DeviceDescription

    enum CodingKeys: String, CodingKey {
        case facebookToken = "facebook_token"
        case device
    }
}

struct ManifestRequest: Encodable, Sendable {
    let device: DeviceDescription
}

struct RSVPRequest: Encodable, Sendable {
    let state: RSVP
}

struct PushRegistrationRequest: Encodable, Sendable {
    let deviceType: String
    let vendorIdentifier: String
    let notificationToken: String

    enum CodingKeys: String, CodingKey {
        case deviceType = "device_type"
        case vendorIdentifier = "vendor_identifier"
        case notificationToken = "notification_token"
    }
}

struct LocationReport: Encodable, Sendable {
    let coordinates: Coordinates

    private enum CodingKeys: String, CodingKey {
        case coordinates, beacon
    }

    private enum PointKeys: String, CodingKey {
        case latitude, longitude
    }

    private enum BeaconKeys: String, CodingKey {
        case major, minor
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        var point = container.nestedContainer(keyedBy: PointKeys.self, forKey: .coordinates)
        try point.encode(coordinates.latitude, forKey: .latitude)
        try point.encode(coordinates.longitude, forKey: .longitude)

        var beacon = container.nestedContainer(keyedBy: BeaconKeys.self, forKey: .beacon)
        try beacon.encode(coordinates.beaconMajor ?? 0, forKey: .major)
        try beacon.encode(coordinates.beaconMinor ?? 0, forKey: .minor)
    }
}
