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
        {"reportLocation":{
          "venue":null,
          "nearby_venues":[{"id":"6f1c2c1e-4d2a-4f6b-9a37-0c1d2e3f4a5b","name":"Nyne",
                     "distance":120.5,"point":"POINT (-117.414777 47.6575451)","photo_url":null,"hero_url":null,
                     "profile":{"address":"232 W Sprague","phone":null,
                                "facebook":{"facebook_id":"123","is_liked":false}}}],
          "locale":{"id":"4e5f6071-8293-4a41-8d5e-6f7a8b9c0d1e","name":"Spokane",
                    "hero_url":"https://cdn.example/spokane.jpg","chat":{"open":false,"recent_messages":{"nodes":[]}},
                    "events":{"upcoming":{"nodes":[{"id":"9a8b7c6d-5e4f-4a3b-8c2d-1e0f9a8b7c6d","name":"Drag Bingo",
                               "start_at":"2026-10-13T20:00:00Z","end_at":null,"facebook_id":42,
                               "banner_url":null,"is_featured":false,"rsvp":"ATTENDING",
                               "venue":{"name":"To be announced","venue":null}}]}}},
          "audience":{"me":{"ping":null}}
        }}
        """#.utf8)

        let now = try JSONDecoder.hotMess.decode(ReportLocationResponse.self, from: json).reportLocation

        #expect(now.title == "Happening Now in Spokane")
        #expect(now.imageURL?.absoluteString == "https://cdn.example/spokane.jpg")
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
        {"reportLocation":{
          "nearby_venues":null,
          "venue":{"id":"6f1c2c1e-4d2a-4f6b-9a37-0c1d2e3f4a5b","name":"Nyne",
                   "distance":null,"point":null,"photo_url":null,"hero_url":null,
                   "profile":{"address":"232 W Sprague","phone":null,
                              "facebook":{"facebook_id":null,"is_liked":false}},
                   "chat":{"recent_messages":{"nodes":[{"id":"1b2c3d4e-5f60-4718-9a2b-3c4d5e6f7a8b",
                                       "message":"who's here?","name":"Sam",
                                       "user_id":"2c3d4e5f-6071-4829-8b3c-4d5e6f7a8b9c",
                                       "avatar_url":null,"sent_at":"2026-10-07T08:00:00Z"}]}},
                   "events":{"upcoming":{"nodes":[]}},
                   "friends":{"list":{"nodes":[{"id":"3d4e5f60-7182-4930-9c4d-5e6f7a8b9c0d","name":"Alex Friend",
                                       "facebook_id":"4242"}]}}},
          "locale":{"id":"4e5f6071-8293-4a41-8d5e-6f7a8b9c0d1e","name":"Spokane",
                    "friends":{"list":{"nodes":[]},"venues":{"nodes":[]}}}
        }}
        """#.utf8)

        let now = try JSONDecoder.hotMess.decode(ReportLocationResponse.self, from: json).reportLocation

        #expect(now.venue?.name == "Nyne")
        #expect(now.title == "Nyne")
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
        {"reportLocation":{
          "venue":null,"nearby_venues":[],
          "locale":{"id":"4e5f6071-8293-4a41-8d5e-6f7a8b9c0d1e","name":"Seattle",
                    "chat":{"open":true,
                            "recent_messages":{"nodes":[{"id":"1b2c3d4e-5f60-4718-9a2b-3c4d5e6f7a8b",
                                        "message":"anyone out?","name":"Ada",
                                        "user_id":"2c3d4e5f-6071-4829-8b3c-4d5e6f7a8b9c",
                                        "avatar_url":null,"sent_at":"2026-10-07T08:00:00Z"}]}}}
        }}
        """#.utf8)

        let now = try JSONDecoder.hotMess.decode(ReportLocationResponse.self, from: json).reportLocation

        #expect(now.locale == AppLocale(id: UUID(uuidString: "4E5F6071-8293-4A41-8D5E-6F7A8B9C0D1E")!, name: "Seattle"))
        #expect(now.localeChatOpen)
        #expect(now.localeMessages.map(\.body) == ["anyone out?"])
        #expect(now.recentMessages.isEmpty)
    }

    @Test("A locale's chat room subscribes to the locale channel")
    func localeChatRoom() {
        let locale = AppLocale(id: UUID(), name: "Seattle")
        let room = ChatRoom.locale(locale)

        #expect(room.channelName == "localeChat")
        #expect(room.subscriptionKey == "localeId")
        #expect(room.name == "Seattle")
        #expect(AppRoute.localeChat(locale).tab == .now)
    }

    @Test("Decodes where friends are when you aren't in a venue")
    func decodesFriendVenues() throws {
        let json = Data(#"""
        {"reportLocation":{
          "venue":null,"nearby_venues":[],
          "locale":{"id":"4e5f6071-8293-4a41-8d5e-6f7a8b9c0d1e","name":"Spokane","friends":{"list":{"nodes":[]},
          "venues":{"nodes":[{"venue":{"id":"6f1c2c1e-4d2a-4f6b-9a37-0c1d2e3f4a5b","name":"Nyne",
                                     "distance":null,"point":null,"photo_url":null,"hero_url":null,
                                     "profile":{"address":null,"phone":null,
                                                "facebook":{"facebook_id":null,"is_liked":false}}},
                            "friend_count":2,
                            "friends":[{"id":"3d4e5f60-7182-4930-9c4d-5e6f7a8b9c0d","name":"Alex Friend","facebook_id":null},
                                       {"id":"4e5f6071-8293-4a41-8d5e-6f7a8b9c0d1e","name":"Sam Chatter","facebook_id":null}]}]}}}
        }}
        """#.utf8)

        let now = try JSONDecoder.hotMess.decode(ReportLocationResponse.self, from: json).reportLocation

        let entry = try #require(now.friendVenues.first)
        #expect(entry.venue.name == "Nyne")
        #expect(entry.friendCount == 2)
        #expect(entry.friends.map(\.firstName) == ["Alex", "Sam"])
    }

    @Test("Features up to two events with a banner")
    func featuredEvents() {
        let banner = URL(string: "https://cdn.example/banner.jpg")
        let events = (0 ..< 4).map { index in
            Event(id: UUID(), name: "Event \(index)", startDate: Date(timeIntervalSince1970: Double(index)),
                  bannerURL: index == 3 ? nil : banner)
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

    @Test("Takes the signed-in user's avatar from me's photo")
    func meAvatar() throws {
        let json = Data("""
        {"me":{"self":{"id":"5b3c8a72-4e19-4d06-b2f5-8c7a1e0d9b22","name":"Rick M.","first_name":"Rick","last_name":"M",
        "photo":{"cdn_url":"https://cdn.hotmess.social/photos/rick.jpg"}}}}
        """.utf8)
        let user = try #require(try JSONDecoder.hotMess.decode(MeResponse.self, from: json).me?.profile?.user)
        #expect(user.name == "Rick M.")
        #expect(user.avatarURL?.absoluteString == "https://cdn.hotmess.social/photos/rick.jpg")

        let withoutPhoto = Data("""
        {"me":{"self":{"id":"5b3c8a72-4e19-4d06-b2f5-8c7a1e0d9b22","name":null,"first_name":"Rick","last_name":"M","photo":null}}}
        """.utf8)
        let plain = try #require(try JSONDecoder.hotMess.decode(MeResponse.self, from: withoutPhoto).me?.profile?.user)
        #expect(plain.name == "Rick M")
        #expect(plain.avatarURL == nil)
    }

    @Test("Decodes a friend's avatar, or none")
    func friendAvatar() throws {
        let json = Data("""
        [{"id":"5b3c8a72-4e19-4d06-b2f5-8c7a1e0d9b22","name":"Sam K","avatar_url":"https://cdn.hotmess.social/photos/sam.jpg"},
         {"id":"6c4d9b83-5f2a-4e17-a3f6-9d8b2f1e0c33","name":"Jo P","avatar_url":null}]
        """.utf8)
        let friends = try JSONDecoder.hotMess.decode([HotMess.Friend].self, from: json)
        let avatars: [String?] = friends.map { $0.avatarURL?.absoluteString }
        #expect(avatars == ["https://cdn.hotmess.social/photos/sam.jpg", nil])
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

    @Test("Reads record UUIDs in either case")
    func recordIDs() throws {
        let uuid = try #require(UUID(uuidString: "7B4E0C6A-1D2F-4E8A-9C3B-5F6A7B8C9D0E"))
        #expect(RecordID.uuid(uuid.uuidString.lowercased()) == uuid)
        #expect(RecordID.uuid(uuid.uuidString) == uuid)
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

@Suite("Chat subscription")
struct ChatIdentifierTests {
    /// Action Cable finds a subscription by this exact string, so a key order
    /// that changes between calls loses messages.
    @Test("Names GraphQLChannel, the audience and the operation, with sorted keys")
    func sortedKeys() {
        let identifier = VenueChatConnection.identifier(audienceID: "b0f8b66a-e636-495d-9475-0f5317ea08e0", channelID: "abc123")

        #expect(identifier == #"{"audience_id":"b0f8b66a-e636-495d-9475-0f5317ea08e0","channel":"GraphQLChannel","channelId":"abc123"}"#)
        #expect((0..<20).allSatisfy { _ in
            VenueChatConnection.identifier(audienceID: "b0f8b66a-e636-495d-9475-0f5317ea08e0", channelID: "abc123") == identifier
        })
    }

    @Test("Executes the room's subscription, aliased to room, with its ID")
    func execute() throws {
        let id = try #require(UUID(uuidString: "0A1E0AAC-1D01-42D1-9DE5-F0279842D9C0"))
        let venue = ChatRoom(kind: .venue, id: id, name: "Why KiKi")
        let locale = ChatRoom(kind: .locale, id: id, name: "Seattle")

        let data = VenueChatConnection.executeData(for: venue)
        let object = try #require(try JSONSerialization.jsonObject(with: Data(data.utf8)) as? [String: Any])
        #expect(object["action"] as? String == "execute")
        #expect(object["operationName"] as? String == "ChatRoom")
        #expect(object["variables"] as? [String: String] == ["id": "0a1e0aac-1d01-42d1-9de5-f0279842d9c0"])

        let query = try #require(object["query"] as? String)
        #expect(query.hasPrefix("subscription ChatRoom($id: ID!)"))
        #expect(query.contains("room: venueChat(venueId: $id)"))
        for type in ["ChatJoined", "ChatMessagePosted", "ChatMessageUpdated", "ChatMessageRemoved", "ChatPinChanged",
                     "ChatRoomCleared", "ChatPresenceChanged", "ChatRangeChanged", "ChatLeft"] {
            #expect(query.contains("... on \(type) "))
        }
        #expect(query.contains("sender_presence: senderPresence"))

        #expect(VenueChatConnection.subscriptionDocument(for: locale).contains("room: localeChat(localeId: $id)"))
        #expect(VenueChatConnection.executeData(for: venue) == data)
    }

    @Test("Sends a line to the room it's in")
    func sendVariables() throws {
        let id = try #require(UUID(uuidString: "0A1E0AAC-1D01-42D1-9DE5-F0279842D9C0"))

        #expect(HotMessAPI.sendMyChatMessageVariables("hi", in: ChatRoom(kind: .venue, id: id, name: "Why KiKi")) == [
            "input": ["venueId": "0a1e0aac-1d01-42d1-9de5-f0279842d9c0", "message": "hi"],
        ])
        #expect(HotMessAPI.sendMyChatMessageVariables("anyone out?", in: ChatRoom(kind: .locale, id: id, name: "Seattle")) == [
            "input": ["localeId": "0a1e0aac-1d01-42d1-9de5-f0279842d9c0", "message": "anyone out?"],
        ])
        #expect(HotMessAPI.Documents.sendMyChatMessage.contains("sendMyChatMessage(input: $input)"))
    }

    @Test("Decodes the mutation's line")
    func sendResponse() throws {
        let json = Data(#"{ "sendMyChatMessage": { "message": { "id": "0a1e0aac-1d01-42d1-9de5-f0279842d9c0", "message": "hi", "body": "hi", "user_id": "00000000-0000-0000-0000-0000000000aa", "sent_at": "2026-10-11T04:00:00Z", "kind": "TEXT", "role": null, "pinned": false, "posted_as_venue": false, "posted_as_person": false } } }"#.utf8)
        let message = VenueMessage(payload: try JSONDecoder.hotMess.decode(SendMyChatMessageResponse.self, from: json).sendMyChatMessage.message)

        #expect(message.id == UUID(uuidString: "0A1E0AAC-1D01-42D1-9DE5-F0279842D9C0"))
        #expect(message.body == "hi")
        #expect(message.kind == .text)
        #expect(message.sentAt == Date(timeIntervalSince1970: 1_791_691_200))
    }
}
