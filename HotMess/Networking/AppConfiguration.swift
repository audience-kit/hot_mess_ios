//
//  AppConfiguration.swift
//  HotMess
//

import Foundation

/// Values baked into the bundle by the per-environment `.xcconfig` files.
///
/// Every lookup has a fallback: the original read these with
/// `Bundle.main.infoDictionary![…] as! String`, so a missing key took the app
/// down on launch.
struct AppConfiguration: Sendable, Hashable {
    let baseURL: URL
    let beaconUUID: UUID?
    let facebookAppID: String?
    let version: String
    let build: Int

    static let defaultBaseURL = URL(string: "https://api.hotmess.social")!

    init(bundle: Bundle = .main) {
        let serverBase = bundle.object(forInfoDictionaryKey: "HotMessServerBase") as? String

        baseURL = serverBase.flatMap(URL.init(string:)) ?? Self.defaultBaseURL
        beaconUUID = (bundle.object(forInfoDictionaryKey: "HotMessBeaconID") as? String)
            .flatMap(UUID.init(uuidString:))
        facebookAppID = bundle.object(forInfoDictionaryKey: "FacebookAppID") as? String
        version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0"
        build = (bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String)
            .flatMap(Int.init) ?? 0
    }

    init(baseURL: URL, beaconUUID: UUID? = nil, facebookAppID: String? = nil, version: String = "0.0", build: Int = 0) {
        self.baseURL = baseURL
        self.beaconUUID = beaconUUID
        self.facebookAppID = facebookAppID
        self.version = version
        self.build = build
    }

    /// Which Facebook app the build is pointed at, for the settings screen.
    var facebookEnvironment: String {
        switch facebookAppID ?? "" {
        case "713525445368431": String(localized: "production")
        case "915436455177328": String(localized: "staging")
        case "842337999153841": String(localized: "development")
        default: String(localized: "unknown")
        }
    }

    /// The API serves every user's avatar from the same path.
    func avatarURL(forUserID id: UUID) -> URL {
        baseURL.appendingPathComponent("users/\(id.uuidString)/picture")
    }

    /// The websocket endpoint, derived from the HTTP base so the two can never
    /// drift apart. `URLSessionWebSocketTask` requires a `ws`/`wss` scheme,
    /// which the old Starscream-based client papered over.
    var realtimeURL: URL? {
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            return nil
        }

        components.scheme = components.scheme == "http" ? "ws" : "wss"

        let base = components.path.hasSuffix("/")
            ? String(components.path.dropLast())
            : components.path
        components.path = base + "/connection"

        return components.url
    }

    /// TestFlight builds carry a sandbox receipt.
    var isTestFlight: Bool {
        Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt"
    }
}
