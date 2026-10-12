//
//  VersionInfo.swift
//  HotMess
//

import Foundation

/// The oldest build of the app the API still serves, from `GET /v1/status`'s
/// `clients.ios`: `minimumVersion`, `latestVersion` and where to update.
struct VersionInfo: Decodable, Hashable, Sendable {
    /// The oldest marketing version still supported, e.g. `1.0.15`.
    let minimumVersion: String
    /// The newest version in the store.
    let latestVersion: String?
    /// Where an older build updates.
    let storeURL: URL?

    enum CodingKeys: String, CodingKey {
        case minimumVersion
        case latestVersion
        case storeURL = "storeUrl"
    }

    init(minimumVersion: String, latestVersion: String? = nil, storeURL: URL? = nil) {
        self.minimumVersion = minimumVersion
        self.latestVersion = latestVersion
        self.storeURL = storeURL
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        minimumVersion = try container.decode(String.self, forKey: .minimumVersion)
        latestVersion = try container.decodeIfPresent(String.self, forKey: .latestVersion)
        storeURL = try container.decodeURLIfPresent(forKey: .storeURL)
    }

    /// Whether a build at `version` (`CFBundleShortVersionString`) is still
    /// served: it is at least `minimumVersion`, comparing dot-separated numbers
    /// so `1.0.15` is newer than `1.0.9`.
    func allows(version: String) -> Bool {
        Self.compare(version, minimumVersion) != .orderedAscending
    }

    static func compare(_ lhs: String, _ rhs: String) -> ComparisonResult {
        let left = components(lhs)
        let right = components(rhs)
        for index in 0 ..< max(left.count, right.count) {
            let l = index < left.count ? left[index] : 0
            let r = index < right.count ? right[index] : 0
            if l != r { return l < r ? .orderedAscending : .orderedDescending }
        }
        return .orderedSame
    }

    private static func components(_ version: String) -> [Int] {
        version.split(whereSeparator: { $0 == "." || $0 == "-" }).map { Int($0) ?? 0 }
    }
}

/// `GET /v1/status`: the API's version and what it asks of each client. Only
/// the iOS app's row is kept.
struct ServiceStatus: Decodable, Sendable {
    /// `api.version`, the contract date the API serves.
    let apiVersion: String?
    let ios: VersionInfo?

    private enum RootKeys: String, CodingKey { case api, clients }
    private enum APIKeys: String, CodingKey { case version }
    private enum ClientKeys: String, CodingKey { case ios }

    init(from decoder: any Decoder) throws {
        let root = try decoder.container(keyedBy: RootKeys.self)
        let api = try? root.nestedContainer(keyedBy: APIKeys.self, forKey: .api)
        apiVersion = try api?.decodeIfPresent(String.self, forKey: .version)
        let clients = try? root.nestedContainer(keyedBy: ClientKeys.self, forKey: .clients)
        ios = try clients?.decodeIfPresent(VersionInfo.self, forKey: .ios)
    }
}
