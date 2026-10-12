//
//  AppModel.swift
//  HotMess
//

import AudienceKit
import Foundation
import Observation
import os

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
    /// Who the user blocked, and whether they've agreed to the terms.
    let safety: SafetyStore
    /// The user's notifications while the app is in front, shown in the app.
    let notifications: NotificationStream
    /// The app's one realtime connection: every GraphQL subscription (the
    /// notifications above, the chat room on screen) rides this socket. It's
    /// open while any of them runs, which is while the app is in front and
    /// signed in, and closes once they've all ended.
    let cable: AudienceCable

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
            credentialStore: SessionStore.credentialStore,
            session: .hotMess
        )
        self.audienceKit = audienceKit

        let api = HotMessAPI(client: APIClient(audienceKit: audienceKit))
        self.api = api

        brand = BrandStore(audienceKit: audienceKit)
        session = SessionStore(api: api, audienceKit: audienceKit, brand: brand, configuration: configuration)
        location = LocationProvider(api: api, configuration: configuration)
        checkout = CoverCheckout(api: api, configuration: configuration)
        safety = SafetyStore(api: api)
        // A socket the server refuses as unauthorized signs out the way an
        // HTTP 401 does. The cable reads the session token from the SDK's
        // store whenever it (re)opens, so a new sign-in is picked up.
        let credentialStore = SessionStore.credentialStore
        let cable = AudienceCable(
            url: GraphQLCable.url(for: configuration),
            token: { try? credentialStore.load()?.token },
            unauthorized: { [session] token in
                guard let token else { return }
                Task { @MainActor in await session.sessionRejected(token: token) }
            },
            openSocket: { request in
                WebSocketTaskSocket(URLSession.realtime.webSocketTask(with: GraphQLCable.handshake(request)))
            }
        )
        self.cable = cable
        notifications = NotificationStream(
            cable: cable,
            audienceID: { [configuration, api] in
                if let audienceID = configuration.audienceID { return audienceID }
                return try? await api.audienceID()
            },
            isSignedIn: { [session] in session.isSignedIn }
        )
        notifications.onReceive = { [weak self] notification in
            if notification.ping != nil { self?.pingsChanged() }
        }

        // The API ended the session (a 401, or a socket refused as
        // unauthorized): forget the user's things as signing out does.
        session.onSessionEnded = { [weak self] in self?.forgetUser() }
    }

    func start() async {
        ErrorReporter.shared.start(audienceKit: audienceKit, configuration: configuration)

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
        forgetUser()
        session.signOut()
    }

    /// Forgets what was loaded for the signed-in user.
    private func forgetUser() {
        friends.forget()
        safety.forget()
        notifications.reset()
        location.forget()
        Task { [cable] in await cable.disconnect() }
    }

    /// Core Location launched the app in the background for a venue geofence
    /// or a significant change. Picking the monitor back up is what delivers
    /// the event, which is then reported with the stored session; nothing
    /// else (branding, the version check, the user) is loaded.
    func startInBackground() async {
        guard location.tracksInBackground, await session.hasStoredSession else { return }
        location.startInBackground()
    }

    /// Deletes the account on the server, then signs out here. The API
    /// erases everything it keeps about the user.
    func deleteAccount() async throws {
        try await api.deleteAccount()
        signOut()
    }

    /// Connects Facebook to an account that signed in with Apple, then
    /// re-reads what depends on it. False when the person cancels.
    func connectFacebook() async throws -> Bool {
        guard try await session.connectFacebook() else { return false }

        friends.forget()
        await safety.load(force: true)
        return true
    }

    func pingsChanged() {
        pingRevision += 1
    }

    /// Goes where a tapped notification leads, whether the system showed it
    /// or the app did: the `url` its payload carries (a universal link such as
    /// `https://hotmess.social/pings/<id>`), never its `kind`. A notification
    /// with no route, or one the app has no screen for, opens Now.
    func open(_ notification: PingNotification) {
        if let url = notification.url, open(url) { return }
        openNow()
    }

    /// "I'm in" on a friend's Ping notification: joins the whole Ping.
    func join(_ notification: PingNotification) async {
        guard let pingID = notification.pingID else { return }

        do {
            _ = try await api.joinPing(pingID)
        } catch {
            Log.app.error("Joining a ping from a notification failed: \(error.localizedDescription, privacy: .public)")
        }
        pingsChanged()
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
        switch DeepLink.destination(for: url) {
        case let .route(route):
            open(route)
            return true
        case .now:
            openNow()
            return true
        case nil:
            return false
        }
    }
}
