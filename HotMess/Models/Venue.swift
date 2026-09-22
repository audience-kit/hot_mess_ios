//
//  Venue.swift
//  HotMess
//

import CoreLocation
import Foundation

struct Venue: Codable, Hashable, Sendable, Identifiable {
    let id: UUID
    let name: String
    let address: String?
    let subtitle: String?
    let phone: String?
    let facebookID: FacebookID?
    /// Metres from the device, when the request carried a location.
    let distance: Double?
    let photoURL: URL?
    let heroURL: URL?
    let point: GeoPoint?
    let isLiked: Bool

    var coordinate: CLLocationCoordinate2D? { point?.coordinate }

    var facebookURL: URL? { facebookID?.profileURL }

    /// What to show under the venue's name in a list row.
    var summary: String {
        subtitle ?? address ?? String(localized: "Address unavailable")
    }

    var shareURL: URL? { URL(string: "https://hotmess.social/venues/\(id.uuidString.lowercased())") }

    enum CodingKeys: String, CodingKey {
        case id, name, address, phone, point, distance
        case subtitle = "description"
        case facebookID = "facebook_id"
        case photoURL = "photo_url"
        case heroURL = "hero_url"
        case isLiked = "is_liked"
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        address = try container.decodeIfPresent(String.self, forKey: .address)
        subtitle = try container.decodeIfPresent(String.self, forKey: .subtitle)
        phone = try container.decodeIfPresent(String.self, forKey: .phone)
        facebookID = try container.decodeIfPresent(FacebookID.self, forKey: .facebookID)
        distance = try container.decodeIfPresent(Double.self, forKey: .distance)
        photoURL = try container.decodeURLIfPresent(forKey: .photoURL)
        heroURL = try container.decodeURLIfPresent(forKey: .heroURL)
        point = try container.decodeIfPresent(GeoPoint.self, forKey: .point)
        isLiked = try container.decodeIfPresent(Bool.self, forKey: .isLiked) ?? false
    }

    init(
        id: UUID,
        name: String,
        address: String? = nil,
        subtitle: String? = nil,
        phone: String? = nil,
        facebookID: FacebookID? = nil,
        distance: Double? = nil,
        photoURL: URL? = nil,
        heroURL: URL? = nil,
        point: GeoPoint? = nil,
        isLiked: Bool = false
    ) {
        self.id = id
        self.name = name
        self.address = address
        self.subtitle = subtitle
        self.phone = phone
        self.facebookID = facebookID
        self.distance = distance
        self.photoURL = photoURL
        self.heroURL = heroURL
        self.point = point
        self.isLiked = isLiked
    }
}

/// The payload of `/v1/venues` and `/v1/locales/{id}/venues`.
struct VenueCollection: Codable, Hashable, Sendable {
    let venues: [Venue]
    let envelope: GeoPolygon?

    init(venues: [Venue] = [], envelope: GeoPolygon? = nil) {
        self.venues = venues
        self.envelope = envelope
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        venues = try container.decodeIfPresent([Venue].self, forKey: .venues) ?? []
        envelope = try container.decodeIfPresent(GeoPolygon.self, forKey: .envelope)
    }

    enum CodingKeys: String, CodingKey {
        case venues, envelope
    }
}
