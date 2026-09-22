//
//  VersionInfo.swift
//  HotMess
//

import Foundation

/// The minimum client the API will talk to, served from `/`.
struct VersionInfo: Decodable, Hashable, Sendable {
    let minimumBuild: Int
    let currentVersion: String
    let minimumVersion: String

    enum CodingKeys: String, CodingKey {
        case minimumBuild = "minimum_build"
        case currentVersion = "current_version"
        case minimumVersion = "minimum_version"
    }
}

/// `/` wraps the version block several layers deep.
struct ServiceManifest: Decodable, Sendable {
    let apple: VersionInfo

    private enum RootKeys: String, CodingKey { case client }
    private enum ClientKeys: String, CodingKey { case mobile }
    private enum MobileKeys: String, CodingKey { case apple }

    init(from decoder: any Decoder) throws {
        let root = try decoder.container(keyedBy: RootKeys.self)
        let client = try root.nestedContainer(keyedBy: ClientKeys.self, forKey: .client)
        let mobile = try client.nestedContainer(keyedBy: MobileKeys.self, forKey: .mobile)

        apple = try mobile.decode(VersionInfo.self, forKey: .apple)
    }
}
