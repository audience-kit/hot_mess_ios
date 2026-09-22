//
//  NetworkingTests.swift
//  HotMessTests
//

import Foundation
import Testing

@testable import HotMess

@Suite("Endpoint URLs")
struct EndpointTests {
    private let base = URL(string: "https://api.hotmess.social")!

    @Test("Joins a rooted path onto the base")
    func simplePath() throws {
        let url = try HotMessAPI.Endpoints.me.url(relativeTo: base)

        #expect(url.absoluteString == "https://api.hotmess.social/v1/me")
    }

    @Test("Does not double up the separator when the base has a trailing slash")
    func trailingSlashBase() throws {
        let slashed = try #require(URL(string: "https://api.hotmess.social/"))
        let url = try HotMessAPI.Endpoints.me.url(relativeTo: slashed)

        #expect(url.absoluteString == "https://api.hotmess.social/v1/me")
    }

    @Test("Puts coordinates on the query string")
    func coordinateQuery() throws {
        let coordinates = Coordinates(latitude: 37.7726, longitude: -122.4099)
        let url = try HotMessAPI.Endpoints.now(near: coordinates).url(relativeTo: base)
        let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        let items = try #require(components.queryItems)

        #expect(components.path == "/v1/now")
        #expect(items.contains(URLQueryItem(name: "latitude", value: "37.7726")))
        #expect(items.contains(URLQueryItem(name: "longitude", value: "-122.4099")))
        #expect(items.count == 2)
    }

    @Test("Adds beacon identifiers only when both are present and non-zero")
    func beaconQuery() {
        var coordinates = Coordinates(latitude: 1, longitude: 2)
        #expect(coordinates.queryItems.count == 2)

        coordinates.beaconMajor = 7
        #expect(coordinates.queryItems.count == 2, "a major on its own is not useful")

        coordinates.beaconMinor = 0
        #expect(coordinates.queryItems.count == 2, "zero means unset")

        coordinates.beaconMinor = 9
        #expect(coordinates.queryItems.count == 4)
    }

    @Test("Omits the query string entirely when there is no location")
    func noCoordinates() throws {
        let url = try HotMessAPI.Endpoints.now(near: nil).url(relativeTo: base)

        #expect(url.absoluteString == "https://api.hotmess.social/v1/now")
    }

    @Test("Uses the right verb and auth policy per endpoint")
    func methodsAndAuth() {
        let id = UUID()

        #expect(HotMessAPI.Endpoints.venue(id).method == .get)
        #expect(HotMessAPI.Endpoints.venue(id).requiresAuthentication)

        let rsvp = HotMessAPI.Endpoints.rsvp(.attending, forEvent: id)
        #expect(rsvp.method == .post)
        #expect(rsvp.body != nil)

        // Minting a token cannot require the token it is about to mint.
        let token = HotMessAPI.Endpoints.token(
            facebookToken: "fb",
            device: DeviceDescription(identifier: "d", version: "1", build: "1", model: "iPhone")
        )
        #expect(token.requiresAuthentication == false)
    }

    @Test("Nests the location report the way the API expects")
    func locationReportShape() throws {
        let report = LocationReport(
            coordinates: Coordinates(latitude: 1.5, longitude: -2.5, beaconMajor: 3, beaconMinor: 4)
        )
        let data = try JSONEncoder().encode(report)
        let json = try JSONSerialization.jsonObject(with: data)
        let object = try #require(json as? [String: Any])

        let point = try #require(object["coordinates"] as? [String: Any])
        let beacon = try #require(object["beacon"] as? [String: Any])

        #expect(point["latitude"] as? Double == 1.5)
        #expect(point["longitude"] as? Double == -2.5)
        #expect(beacon["major"] as? Int == 3)
        #expect(beacon["minor"] as? Int == 4)
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
    }

    @Test("Names the Facebook environment from the app ID")
    func facebookEnvironment() {
        let staging = AppConfiguration(
            baseURL: AppConfiguration.defaultBaseURL,
            facebookAppID: "915436455177328"
        )

        #expect(staging.facebookEnvironment == "staging")
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
