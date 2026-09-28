//
//  Track.swift
//  HotMess
//

import Foundation

struct Track: Codable, Hashable, Sendable, Identifiable {
    let id: UUID
    let title: String
    let provider: String
    let providerURL: URL?
    let waveformURL: URL?
    let artworkURL: URL?

    enum CodingKeys: String, CodingKey {
        case id, title, provider
        case providerURL = "provider_url"
        case waveformURL = "waveform_url"
        case artworkURL = "artwork_url"
    }

    init(
        id: UUID,
        title: String,
        provider: String,
        providerURL: URL? = nil,
        waveformURL: URL? = nil,
        artworkURL: URL? = nil
    ) {
        self.id = id
        self.title = title
        self.provider = provider
        self.providerURL = providerURL
        self.waveformURL = waveformURL
        self.artworkURL = artworkURL
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        provider = try container.decodeIfPresent(String.self, forKey: .provider) ?? ""
        providerURL = try container.decodeURLIfPresent(forKey: .providerURL)
        waveformURL = try container.decodeURLIfPresent(forKey: .waveformURL)
        artworkURL = try container.decodeURLIfPresent(forKey: .artworkURL)
    }
}
