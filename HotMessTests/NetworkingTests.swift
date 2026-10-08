//
//  NetworkingTests.swift
//  HotMessTests
//

import Foundation
import AudienceKit
import Testing

@testable import HotMess

@Suite("Endpoint URLs")
struct EndpointTests {
    private let base = URL(string: "https://api.hotmess.social")!

    @Test("Joins a rooted path onto the base")
    func simplePath() throws {
        let url = try Endpoint<EmptyResponse>("/v1/me").url(relativeTo: base)

        #expect(url.absoluteString == "https://api.hotmess.social/v1/me")
    }

    @Test("Does not double up the separator when the base has a trailing slash")
    func trailingSlashBase() throws {
        let slashed = try #require(URL(string: "https://api.hotmess.social/"))
        let url = try Endpoint<EmptyResponse>("/v1/me").url(relativeTo: slashed)

        #expect(url.absoluteString == "https://api.hotmess.social/v1/me")
    }

    @Test("Reads the version manifest without a session")
    func manifestIsPublic() {
        let manifest = HotMessAPI.Endpoints.manifest(device: DeviceDescription(identifier: "d"))

        #expect(manifest.method == .post)
        #expect(manifest.requiresAuthentication == false)
    }

    @Test("Signs in with Apple without a session, and connects Facebook with one")
    func appleAndConnect() throws {
        let device = DeviceDescription(identifier: "d")
        let apple = HotMessAPI.Endpoints.appleSignIn(
            AppleSignInRequest(identityToken: "t", firstName: "Ada", lastName: nil, host: "hotmess.social", device: device)
        )
        #expect(apple.path == "/v1/token/apple")
        #expect(apple.requiresAuthentication == false)

        let connect = HotMessAPI.Endpoints.connectFacebook(
            ConnectFacebookRequest(code: "c", redirectURI: "fb1://authorize/", host: nil, facebookAppID: "1",
                                   device: device)
        )
        #expect(connect.path == "/v1/token")
        #expect(connect.requiresAuthentication)

        let encode = try #require(connect.body?.encode)
        let body = try encode(JSONEncoder())
        let json = try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])
        #expect(json["connect"] as? Bool == true)
        #expect(json["redirect_uri"] as? String == "fb1://authorize/")
    }
}

@Suite("GraphQL")
struct GraphQLTests {
    @Test("Sends coordinates as a CoordinatesInput, leaving out a zero beacon")
    func coordinatesInput() {
        let value = Coordinates(latitude: 1.5, longitude: -2.5, beaconMajor: 0, beaconMinor: 4).audienceKit.graphQLValue

        #expect(value == ["latitude": 1.5, "longitude": -2.5, "beaconMinor": 4])
    }

    @Test("Decodes reportLocation into Now through the aliased fields")
    func decodesNow() throws {
        let json = Data(#"""
        {"reportLocation":{"now":{
          "title":"Happening Now in Spokane","image_url":"https://cdn.example/spokane.jpg","venue":null,
          "venues":[{"id":"6f1c2c1e-4d2a-4f6b-9a37-0c1d2e3f4a5b","name":"Nyne","address":"232 W Sprague",
                     "phone":null,"distance":120.5,"point":"POINT (-117.414777 47.6575451)",
                     "facebook_id":"123","photo_url":null,"hero_url":null,"is_liked":false}],
          "events":[{"id":"9a8b7c6d-5e4f-4a3b-8c2d-1e0f9a8b7c6d","name":"Drag Bingo",
                     "start_at":"2026-10-13T20:00:00Z","end_at":null,"facebook_id":42,
                     "cover_photo_url":null,"is_featured":false,"rsvp":"ATTENDING","venue":null}]
        }}}
        """#.utf8)

        let now = try JSONDecoder.hotMess.decode(ReportLocationResponse.self, from: json).reportLocation.now

        #expect(now.title == "Happening Now in Spokane")
        #expect(now.isNearVenues)
        let venue = try #require(now.venues?.first)
        #expect(venue.name == "Nyne")
        #expect(venue.distance == 120.5)
        #expect(venue.coordinate?.latitude == 47.6575451)
        #expect(now.events.first?.rsvp == .attending)
    }

    @Test("Decodes the venue's recent chat lines into Now")
    func decodesNowAtVenue() throws {
        let json = Data(#"""
        {"reportLocation":{"now":{
          "title":"Nyne","image_url":null,"venues":null,"events":[],
          "venue":{"id":"6f1c2c1e-4d2a-4f6b-9a37-0c1d2e3f4a5b","name":"Nyne","address":"232 W Sprague",
                   "phone":null,"distance":null,"point":null,"facebook_id":null,"photo_url":null,"hero_url":null,
                   "is_liked":false,
                   "recent_messages":[{"id":"1b2c3d4e-5f60-4718-9a2b-3c4d5e6f7a8b","message":"who's here?",
                                       "name":"Sam","user_id":"2c3d4e5f-6071-4829-8b3c-4d5e6f7a8b9c",
                                       "avatar_url":null,"sent_at":"2026-10-07T08:00:00Z"}]},
          "friends":[{"id":"3d4e5f60-7182-4930-9c4d-5e6f7a8b9c0d","name":"Alex Friend","facebook_id":"4242"}]
        }}}
        """#.utf8)

        let now = try JSONDecoder.hotMess.decode(ReportLocationResponse.self, from: json).reportLocation.now

        #expect(now.venue?.name == "Nyne")
        #expect(!now.isNearVenues)
        let line = try #require(now.recentMessages.first)
        #expect(line.body == "who's here?")
        #expect(line.name == "Sam")
        #expect(line.id == UUID(uuidString: "1B2C3D4E-5F60-4718-9A2B-3C4D5E6F7A8B"))
        #expect(now.friends.map(\.name) == ["Alex Friend"])
    }

    @Test("Decodes the locale's chat room into Now when you aren't in a venue")
    func decodesNowLocaleChat() throws {
        let json = Data(#"""
        {"reportLocation":{"now":{
          "title":"Happening Now in Seattle","image_url":null,"venue":null,"venues":[],"events":[],
          "locale":{"id":"4e5f6071-8293-4a41-8d5e-6f7a8b9c0d1e","name":"Seattle","chat_open":true,
                    "recent_messages":[{"id":"1b2c3d4e-5f60-4718-9a2b-3c4d5e6f7a8b","message":"anyone out?",
                                        "name":"Ada","user_id":"2c3d4e5f-6071-4829-8b3c-4d5e6f7a8b9c",
                                        "avatar_url":null,"sent_at":"2026-10-07T08:00:00Z"}]}
        }}}
        """#.utf8)

        let now = try JSONDecoder.hotMess.decode(ReportLocationResponse.self, from: json).reportLocation.now

        #expect(now.locale == AppLocale(id: UUID(uuidString: "4E5F6071-8293-4A41-8D5E-6F7A8B9C0D1E")!, name: "Seattle"))
        #expect(now.localeChatOpen)
        #expect(now.localeMessages.map(\.body) == ["anyone out?"])
        #expect(now.recentMessages.isEmpty)
    }

    @Test("A locale's chat room subscribes to the locale channel")
    func localeChatRoom() {
        let locale = AppLocale(id: UUID(), name: "Seattle")
        let room = ChatRoom.locale(locale)

        #expect(room.channelName == "LocaleChannel")
        #expect(room.subscriptionKey == "locale_id")
        #expect(room.name == "Seattle")
        #expect(AppRoute.localeChat(locale).tab == .now)
    }

    @Test("Decodes where friends are when you aren't in a venue")
    func decodesFriendVenues() throws {
        let json = Data(#"""
        {"reportLocation":{"now":{
          "title":"Happening Now in Spokane","image_url":null,"venue":null,"venues":[],"events":[],"friends":[],
          "friend_venues":[{"venue":{"id":"6f1c2c1e-4d2a-4f6b-9a37-0c1d2e3f4a5b","name":"Nyne","address":null,
                                     "phone":null,"distance":null,"point":null,"facebook_id":null,"photo_url":null,
                                     "hero_url":null,"is_liked":false},
                            "friend_count":2,
                            "friends":[{"id":"3d4e5f60-7182-4930-9c4d-5e6f7a8b9c0d","name":"Alex Friend","facebook_id":null},
                                       {"id":"4e5f6071-8293-4a41-8d5e-6f7a8b9c0d1e","name":"Sam Chatter","facebook_id":null}]}]
        }}}
        """#.utf8)

        let now = try JSONDecoder.hotMess.decode(ReportLocationResponse.self, from: json).reportLocation.now

        let entry = try #require(now.friendVenues.first)
        #expect(entry.venue.name == "Nyne")
        #expect(entry.friendCount == 2)
        #expect(entry.friends.map(\.firstName) == ["Alex", "Sam"])
    }

    @Test("Features up to two events with a cover photo")
    func featuredEvents() {
        let cover = URL(string: "https://cdn.example/cover.jpg")
        let events = (0 ..< 4).map { index in
            Event(id: UUID(), name: "Event \(index)", startDate: Date(timeIntervalSince1970: Double(index)),
                  coverURL: index == 3 ? nil : cover)
        }

        let listing = EventListing(upcoming: events.reversed())

        #expect(listing.sections.map(\.id) == ["recommended", "upcoming"])
        #expect(listing.sections[0].events.map(\.name) == ["Event 0", "Event 1"])
        #expect(listing.sections[1].events.count == 4)
        #expect(EventListing(upcoming: []).isEmpty)
    }

    @Test("Sends APNs tokens as hex")
    func pushTokenHex() {
        #expect(Data([0x0a, 0xff, 0x01]).hexEncodedString == "0aff01")
    }
}

@Suite("App configuration")
struct AppConfigurationTests {
    @Test("Derives the websocket URL from the HTTP base")
    func realtimeURL() {
        let https = AppConfiguration(baseURL: URL(string: "https://api.hotmess.social")!)
        #expect(https.realtimeURL?.absoluteString == "wss://api.hotmess.social/connection")

        let http = AppConfiguration(baseURL: URL(string: "http://localhost:3000")!)
        #expect(http.realtimeURL?.absoluteString == "ws://localhost:3000/connection")
    }

    @Test("Builds avatar URLs against the configured host")
    func avatarURL() throws {
        let configuration = AppConfiguration(baseURL: URL(string: "https://api.hotmess.social")!)
        let id = try #require(UUID(uuidString: "5B3C8A72-4E19-4D06-B2F5-8C7A1E0D9B22"))

        #expect(
            configuration.avatarURL(forUserID: id).absoluteString
                == "https://api.hotmess.social/users/5B3C8A72-4E19-4D06-B2F5-8C7A1E0D9B22/picture"
        )
    }

    @Test("Falls back to production when the bundle carries no server key")
    func missingInfoPlistKeys() {
        // An empty bundle stands in for a build where the xcconfig didn't apply;
        // the old code force-unwrapped this and crashed on launch.
        let configuration = AppConfiguration(bundle: Bundle(for: BundleAnchor.self))

        #expect(configuration.baseURL == AppConfiguration.defaultBaseURL)
        #expect(configuration.beaconUUID == nil)
        #expect(configuration.facebookAppID == nil)
        #expect(configuration.facebookEnvironment == "unknown")
        #expect(configuration.environment == .production)
    }

    @Test("Passes the build's environment to the AudienceKit SDK")
    func audienceKitEnvironment() {
        let staging = AppConfiguration(baseURL: AppConfiguration.defaultBaseURL, environment: .staging)

        #expect(staging.audienceKit.environment == .staging)
    }

    @Test("Names the Facebook environment from the app ID")
    func facebookEnvironment() {
        let staging = AppConfiguration(
            baseURL: AppConfiguration.defaultBaseURL,
            facebookAppID: "1660272792277019"
        )

        #expect(staging.facebookEnvironment == "staging")
    }
}

@Suite("AudienceKit")
struct AudienceKitMappingTests {
    @Test("Builds the SDK configuration from the app's")
    func sdkConfiguration() {
        let configuration = AppConfiguration(
            baseURL: URL(string: "https://api.audiencekit.com")!,
            facebookAppID: "842337999153841"
        )

        #expect(configuration.audienceKit.host == "hotmess.admin.audiencekit.com")
        #expect(configuration.audienceKit.facebookAppID == "842337999153841")
        #expect(configuration.audienceKit.baseURL == configuration.baseURL)
    }

    @Test("Maps SDK errors onto the app's")
    func errorMapping() {
        #expect(APIError(AudienceKitError.unauthorized) == .unauthorized)
        #expect(APIError(AudienceKitError.notFound) == .notFound)
        #expect(APIError(AudienceKitError.http(status: 502)) == .server(status: 502))
        #expect(APIError(AudienceKitError.network(URLError(.notConnectedToInternet))) == .offline)
    }

    @Test("Reads record UUIDs from plain and global IDs")
    func recordIDs() throws {
        let uuid = try #require(UUID(uuidString: "7B4E0C6A-1D2F-4E8A-9C3B-5F6A7B8C9D0E"))
        #expect(RecordID.uuid(uuid.uuidString.lowercased()) == uuid)

        let global = Data("gid://hot-mess/Venue/\(uuid.uuidString.lowercased())".utf8).base64EncodedString()
        #expect(RecordID.uuid(global) == uuid)
        #expect(RecordID.uuid("nope") == nil)
    }
}

/// Only here so `Bundle(for:)` can find the test bundle.
private final class BundleAnchor {}

@Suite("API errors")
struct APIErrorTests {
    @Test("Maps connectivity failures onto a retryable offline error")
    func offlineMapping() {
        #expect(APIError(urlError: URLError(.notConnectedToInternet)) == .offline)
        #expect(APIError(urlError: URLError(.timedOut)) == .offline)
        #expect(APIError.offline.isRetryable)
    }

    @Test("Does not offer a retry for failures a retry cannot fix")
    func nonRetryable() {
        #expect(APIError.unauthorized.isRetryable == false)
        #expect(APIError.decoding("nope").isRetryable == false)
        #expect(APIError.server(status: 503).isRetryable)
    }

    @Test("Always has something to show the user")
    func messages() {
        let errors: [APIError] = [
            .offline, .unauthorized, .notFound, .server(status: 500),
            .decoding("x"), .invalidURL, .transport("boom"),
        ]

        for error in errors {
            #expect(error.errorDescription?.isEmpty == false)
        }
    }
}

@Suite("Chat subscription identifier")
struct ChatIdentifierTests {
    /// Action Cable finds a subscription by this exact string, so a key order
    /// that changes between calls loses messages.
    @Test("Sorts its keys, so every frame names the same subscription")
    func sortedKeys() throws {
        let id = try #require(UUID(uuidString: "0A1E0AAC-1D01-42D1-9DE5-F0279842D9C0"))
        let room = ChatRoom(kind: .venue, id: id, name: "Why KiKi")

        let identifier = VenueChatConnection.identifier(for: room)

        #expect(identifier == #"{"channel":"RealtimeChannel","venue_id":"0a1e0aac-1d01-42d1-9de5-f0279842d9c0"}"#)
        #expect((0..<20).allSatisfy { _ in VenueChatConnection.identifier(for: room) == identifier })
    }
}
