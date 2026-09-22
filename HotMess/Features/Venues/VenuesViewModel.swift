//
//  VenuesViewModel.swift
//  HotMess
//

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
}

@MainActor
@Observable
final class VenuesViewModel {
    private(set) var state: LoadState<VenueCollection> = .idle

    private let api: HotMessAPI

    init(api: HotMessAPI) {
        self.api = api
    }

    func load(localeID: UUID?, coordinates: Coordinates?) async {
        if state.value == nil { state = .loading }

        do {
            state = .loaded(try await api.venues(in: localeID, near: coordinates))
        } catch is CancellationError {
        } catch {
            state = LoadState(catching: error)
        }
    }
}
