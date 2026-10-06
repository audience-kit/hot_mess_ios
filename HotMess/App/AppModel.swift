//
//  AppModel.swift
//  HotMess
//

import AudienceKit
import Foundation
import Observation

/// The app's composition root: it builds the services once and holds the
/// navigation state the rest of the UI reads.
@MainActor
@Observable
final class AppModel {
    let configuration: AppConfiguration
    let api: HotMessAPI
    let audienceKit: AudienceKitClient
    let session: SessionStore
    /// The audience's look, from AudienceKit branding.
    let brand: BrandStore
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

        let audienceKit = AudienceKitClient(
            configuration: configuration.audienceKit,
            tokenStore: SessionStore.tokenStore,
            session: .hotMess
        )
        self.audienceKit = audienceKit

        let api = HotMessAPI(client: APIClient(audienceKit: audienceKit))
        self.api = api

        brand = BrandStore(audienceKit: audienceKit)
        session = SessionStore(api: api, audienceKit: audienceKit, configuration: configuration)
        location = LocationProvider(api: api, configuration: configuration)
    }

    func start() async {
        // Branding is public, so the login screen can wear the audience's colours.
        Task { await brand.load() }
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
