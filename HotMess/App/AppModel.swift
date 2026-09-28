//
//  AppModel.swift
//  HotMess
//

import Foundation
import Observation

/// The app's composition root: it builds the services once and holds the
/// navigation state the rest of the UI reads.
@MainActor
@Observable
final class AppModel {
    let configuration: AppConfiguration
    let api: HotMessAPI
    let session: SessionStore
    let location: LocationProvider

    var selectedTab: AppTab = .now

    /// One navigation path per tab, so a deep link can push onto the right
    /// stack without disturbing the others.
    var nowPath: [AppRoute] = []
    var eventsPath: [AppRoute] = []
    var venuesPath: [AppRoute] = []
    var peoplePath: [AppRoute] = []

    static let shared = AppModel()

    init(configuration: AppConfiguration = AppConfiguration()) {
        self.configuration = configuration

        let api = HotMessAPI(client: APIClient(configuration: configuration))
        self.api = api

        session = SessionStore(api: api, configuration: configuration)
        location = LocationProvider(api: api, configuration: configuration)
    }

    func start() async {
        await session.start()

        if session.isSignedIn {
            location.start()
        }
    }

    /// Jumps to a route, switching tabs and resetting that tab's stack first —
    /// matching the old `popToRootViewController` then `push` behaviour.
    func open(_ route: AppRoute) {
        selectedTab = route.tab

        switch route.tab {
        case .now: nowPath = [route]
        case .events: eventsPath = [route]
        case .venues: venuesPath = [route]
        case .people: peoplePath = [route]
        case .me: break
        }
    }

    func open(_ url: URL) -> Bool {
        guard let route = DeepLink.route(for: url) else { return false }

        open(route)
        return true
    }
}
