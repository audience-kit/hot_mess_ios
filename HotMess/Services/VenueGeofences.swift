//
//  VenueGeofences.swift
//  HotMess
//

import CoreLocation
import Foundation

/// A venue's envelope: the circle around it that counts as being there. The
/// API buffers the venue's point by its `distanceTolerance`, so the envelope
/// is exactly this circle and Core Location can watch it as a region.
struct VenueFence: Decodable, Hashable, Sendable, Identifiable {
    let id: UUID
    let latitude: Double
    let longitude: Double
    /// Metres.
    let radius: Double

    var center: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    init(id: UUID, latitude: Double, longitude: Double, radius: Double) {
        self.id = id
        self.latitude = latitude
        self.longitude = longitude
        self.radius = radius
    }

    private enum CodingKeys: String, CodingKey {
        case id, point
        case radius = "distance_tolerance"
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let point = try container.decode(GeoPoint.self, forKey: .point)

        self.init(
            id: try container.decode(UUID.self, forKey: .id),
            latitude: point.y,
            longitude: point.x,
            radius: try container.decode(Double.self, forKey: .radius)
        )
    }

    /// Metres from `position` to the edge of the envelope; negative inside it.
    func distanceToEdge(from position: CLLocation) -> CLLocationDistance {
        position.distance(from: CLLocation(latitude: latitude, longitude: longitude)) - radius
    }
}

/// Which regions to monitor from a position.
///
/// iOS monitors at most 20 regions per app, so the plan takes the venues
/// nearest the position and adds one "re-center" circle around the position
/// itself. The re-center circle stops short of every venue that didn't make
/// the cut, so the app can't walk into an unwatched venue without first
/// leaving it; leaving it is the cue to plan again from the new position.
struct GeofencePlan: Equatable, Sendable {
    /// One region is the re-center circle; the rest are venues.
    static let regionLimit = 20
    /// Smallest re-center circle: Core Location can't tell much smaller ones apart.
    static let minimumRecenterRadius: CLLocationDistance = 150
    /// Largest re-center circle, for when every venue nearby is already watched:
    /// far enough to reach the next city, near enough to notice the trip.
    static let maximumRecenterRadius: CLLocationDistance = 25_000

    let venues: [VenueFence]
    let recenterLatitude: Double
    let recenterLongitude: Double
    let recenterRadius: CLLocationDistance

    var recenterCenter: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: recenterLatitude, longitude: recenterLongitude)
    }

    init(around position: Coordinates, venues candidates: [VenueFence], regionLimit: Int = Self.regionLimit) {
        let here = CLLocation(latitude: position.latitude, longitude: position.longitude)
        let sorted = candidates
            .map { (fence: $0, edge: $0.distanceToEdge(from: here)) }
            .sorted { $0.edge < $1.edge }

        let watched = sorted.prefix(max(regionLimit - 1, 0))
        let nearestUnwatched = sorted.dropFirst(watched.count).first?.edge

        venues = watched.map(\.fence)
        recenterLatitude = position.latitude
        recenterLongitude = position.longitude
        recenterRadius = min(
            max(nearestUnwatched ?? Self.maximumRecenterRadius, Self.minimumRecenterRadius),
            Self.maximumRecenterRadius
        )
    }
}
