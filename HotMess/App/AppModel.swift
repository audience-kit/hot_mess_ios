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
    /// Paying cover and showing passes, over whichever tab asked.
    let checkout: CoverCheckout
    /// Friends seen so far, so chat can show them by their full name.
    let friends = FriendDirectory()

    var selectedTab: AppTab = .now

    /// One navigation path per tab, so a deep link can push onto the right
    /// stack without disturbing the others.
    var nowPath: [AppRoute] = []
    var eventsPath: [AppRoute] = []
    var venuesPath: [AppRoute] = []
    var peoplePath: [AppRoute] = []

    /// Bumped whenever Pings change somewhere other than Now (a push, the
    /// send sheet on a venue), so Now reloads.
    private(set) var pingRevision = 0

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
        session = SessionStore(api: api, audienceKit: audienceKit, brand: brand, configuration: configuration)
        location = LocationProvider(api: api, configuration: configuration)
        checkout = CoverCheckout(api: api, configuration: configuration)
    }

    func start() async {
        // UI tests start from the login screen.
        if ProcessInfo.processInfo.arguments.contains("-HotMessUITestSignedOut") {
            signOut()
        }

        // Branding is public, so the login screen can wear the audience's colours.
        Task { await brand.load() }
        await session.start()

        if session.isSignedIn {
            location.start()
            // Re-register every launch: APNs tokens change, and a restored
            // session never went through sign-in's registration.
            Task { await PushNotifications.requestAuthorizationAndRegister() }
        }
    }

    /// Signs out and forgets what was loaded for the user.
    func signOut() {
        friends.forget()
        session.signOut()
    }

    func pingsChanged() {
        pingRevision += 1
    }

    /// Shows Now from the top, for a tapped Ping notification.
    func openNow() {
        selectedTab = .now
        nowPath = []
        pingsChanged()
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
