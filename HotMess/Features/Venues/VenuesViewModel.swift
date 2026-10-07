//
//  VenuesViewModel.swift
//  HotMess
//

import AudienceKit
import CoreLocation
import Foundation
import MapKit
import Observation

/// A venue that has a position, ready to draw on a map.
struct VenuePin: Identifiable, Hashable, Sendable {
    let id: UUID
    let name: String
    let coordinate: CLLocationCoordinate2D

    static func == (lhs: VenuePin, rhs: VenuePin) -> Bool { lhs.id == rhs.id }

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

extension VenueCollection {
    var pins: [VenuePin] {
        venues.compactMap { venue in
            venue.coordinate.map { VenuePin(id: venue.id, name: venue.name, coordinate: $0) }
        }
    }

    /// The region that frames the results: the server's envelope when it sends
    /// one, otherwise a box around the pins.
    var region: MKCoordinateRegion? {
        envelope?.region ?? MKCoordinateRegion.containing(pins.map(\.coordinate))
    }

    /// The audience's visible venues from AudienceKit GraphQL, in the audience's
    /// order. Only venues in `localeID` are kept once the device's locale is
    /// known; until then every venue shows.
    init(audienceVenues: [AudienceKit.Venue], localeID: UUID?, resolve: (String?) -> URL?) {
        let visible = audienceVenues
            .filter { !$0.hidden }
            .filter { localeID == nil || RecordID.uuid($0.locale.id) == localeID }
            .sorted { ($0.order, $0.name) < ($1.order, $1.name) }

        self.init(venues: visible.compactMap { Venue($0, resolve: resolve) })
    }
}

extension Venue {
    /// A list row's worth of venue from AudienceKit GraphQL. Detail screens
    /// still load the full venue over REST by its UUID.
    init?(_ venue: AudienceKit.Venue, resolve: (String?) -> URL?) {
        guard let id = RecordID.uuid(venue.id) else { return nil }

        self.init(
            id: id,
            name: venue.name,
            subtitle: venue.locale.name ?? venue.locale.label,
            photoURL: resolve(venue.page?.photoUrl ?? venue.photoUrl),
            heroURL: resolve(venue.page?.coverImageUrl ?? venue.coverImageUrl),
            point: venue.location?.coordinate.map { GeoPoint(x: $0.longitude, y: $0.latitude) }
        )
    }
}

@MainActor
@Observable
final class VenuesViewModel {
    private(set) var state: LoadState<VenueCollection> = .idle

    private let audienceKit: AudienceKitClient

    init(audienceKit: AudienceKitClient) {
        self.audienceKit = audienceKit
    }

    func load(localeID: UUID?) async {
        if state.value == nil { state = .loading }

        do {
            let venues = try await audienceKit.venues()
            state = .loaded(VenueCollection(audienceVenues: venues, localeID: localeID, resolve: audienceKit.url(for:)))
        } catch is CancellationError {
        } catch let error as AudienceKitError {
            state = LoadState(catching: APIError(error))
        } catch {
            state = LoadState(catching: error)
        }
    }
}
