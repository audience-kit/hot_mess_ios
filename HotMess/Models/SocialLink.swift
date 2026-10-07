//
//  SocialLink.swift
//  HotMess
//

import Foundation

struct SocialLink: Codable, Hashable, Sendable, Identifiable {
    let id: UUID
    let handle: String
    let provider: String
    let url: URL?

    /// The bundled glyph for a known network, or `nil` to fall back to a
    /// system symbol.
    var assetName: String? {
        switch provider.lowercased() {
        case "facebook": "Facebook"
        case "soundcloud": "SoundCloud"
        case "instagram": "Instagram"
        case "twitter", "x": "Twitter"
        default: nil
        }
    }

    /// The system symbol for a network without a bundled glyph.
    var systemImage: String {
        switch provider.lowercased() {
        case "spotify", "apple_music": "music.note"
        default: "link"
        }
    }

    /// What the row says: the service for music links, whose handles are URL
    /// paths, otherwise "/handle".
    var label: String {
        switch provider.lowercased() {
        case "spotify": "Spotify"
        case "apple_music": "Apple Music"
        default: "/\(handle)"
        }
    }

    /// The app fans tip them with, for a Cash App or Venmo link; `nil` for a
    /// social profile.
    var tipApp: String? {
        switch provider.lowercased() {
        case "cashapp": "Cash App"
        case "venmo": "Venmo"
        default: nil
        }
    }

    enum CodingKeys: String, CodingKey {
        case id, handle, provider, url
    }

    init(id: UUID, handle: String, provider: String, url: URL? = nil) {
        self.id = id
        self.handle = handle
        self.provider = provider
        self.url = url
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(UUID.self, forKey: .id)
        handle = try container.decodeIfPresent(String.self, forKey: .handle) ?? ""
        provider = try container.decodeIfPresent(String.self, forKey: .provider) ?? ""
        url = try container.decodeURLIfPresent(forKey: .url)
    }
}
