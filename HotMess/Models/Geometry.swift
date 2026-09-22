//
//  Geometry.swift
//  HotMess
//

import CoreLocation
import Foundation
import MapKit

/// A venue's position.
///
/// The server serialises PostGIS points as `{ "x": …, "y": … }` where `x` is
/// the latitude and `y` the longitude. That convention is preserved here and
/// kept in one place so the rest of the app only ever sees a coordinate.
struct GeoPoint: Codable, Hashable, Sendable {
    let x: Double
    let y: Double

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: x, longitude: y)
    }
}

/// A GeoJSON polygon, used for the bounding envelope of a venue search.
///
/// Replaces the GEOSwift dependency: the app only ever needed the polygon's
/// bounding box to frame a map.
struct GeoPolygon: Codable, Hashable, Sendable {
    /// GeoJSON rings in `[longitude, latitude]` order. The first ring is the
    /// exterior boundary; any others are holes.
    let coordinates: [[[Double]]]

    var exteriorCoordinates: [CLLocationCoordinate2D] {
        guard let ring = coordinates.first else { return [] }

        return ring.compactMap { pair in
            guard pair.count >= 2 else { return nil }
            return CLLocationCoordinate2D(latitude: pair[1], longitude: pair[0])
        }
    }

    /// The smallest region containing the polygon, or `nil` when it is empty.
    var region: MKCoordinateRegion? {
        let points = exteriorCoordinates
        guard let first = points.first else { return nil }

        var minLatitude = first.latitude, maxLatitude = first.latitude
        var minLongitude = first.longitude, maxLongitude = first.longitude

        for point in points.dropFirst() {
            minLatitude = min(minLatitude, point.latitude)
            maxLatitude = max(maxLatitude, point.latitude)
            minLongitude = min(minLongitude, point.longitude)
            maxLongitude = max(maxLongitude, point.longitude)
        }

        let center = CLLocationCoordinate2D(
            latitude: (minLatitude + maxLatitude) / 2,
            longitude: (minLongitude + maxLongitude) / 2
        )
        // A little padding so pins near the edge are not clipped.
        let span = MKCoordinateSpan(
            latitudeDelta: max(maxLatitude - minLatitude, 0.005) * 1.2,
            longitudeDelta: max(maxLongitude - minLongitude, 0.005) * 1.2
        )

        return MKCoordinateRegion(center: center, span: span)
    }
}

extension MKCoordinateRegion {
    /// A region that frames every supplied coordinate.
    static func containing(_ coordinates: [CLLocationCoordinate2D]) -> MKCoordinateRegion? {
        guard let first = coordinates.first else { return nil }

        var minLatitude = first.latitude, maxLatitude = first.latitude
        var minLongitude = first.longitude, maxLongitude = first.longitude

        for coordinate in coordinates.dropFirst() {
            minLatitude = min(minLatitude, coordinate.latitude)
            maxLatitude = max(maxLatitude, coordinate.latitude)
            minLongitude = min(minLongitude, coordinate.longitude)
            maxLongitude = max(maxLongitude, coordinate.longitude)
        }

        return MKCoordinateRegion(
            center: CLLocationCoordinate2D(
                latitude: (minLatitude + maxLatitude) / 2,
                longitude: (minLongitude + maxLongitude) / 2
            ),
            span: MKCoordinateSpan(
                latitudeDelta: max(maxLatitude - minLatitude, 0.005) * 1.4,
                longitudeDelta: max(maxLongitude - minLongitude, 0.005) * 1.4
            )
        )
    }
}
