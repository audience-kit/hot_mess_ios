//
//  AppRoute.swift
//  HotMess
//

import Foundation

/// Somewhere in the app that can be linked to.
enum AppRoute: Hashable, Sendable {
    case venue(UUID)
    case event(UUID)
    case person(UUID)
    case venueChat(Venue)
    /// A locale's chat room, for people out in it who aren't at a venue.
    case localeChat(AppLocale)

    /// Which tab the route belongs in.
    var tab: AppTab {
        switch self {
        case .venue, .venueChat: .venues
        case .event: .events
        case .person: .people
        case .localeChat: .now
        }
    }
}

enum AppTab: Hashable, Sendable, CaseIterable {
    case now
    case events
    case venues
    case people
    case me

    var title: String {
        switch self {
        case .now: String(localized: "Now")
        case .events: String(localized: "Events")
        case .venues: String(localized: "Venues")
        case .people: String(localized: "People")
        case .me: String(localized: "Me")
        }
    }

    /// SF Symbols replace the flat 2017 PNG glyphs: they pick up the tint,
    /// adapt to Dark Mode, and scale with Dynamic Type.
    var systemImage: String {
        switch self {
        case .now: "house.fill"
        case .events: "calendar"
        case .venues: "mappin.and.ellipse"
        case .people: "person.2.fill"
        case .me: "person.crop.circle"
        }
    }
}

/// Where a link leads: a screen to push, or Now from the top (a Ping, which
/// Now shows; `https://hotmess.social/pings/<id>` is what a Ping's push
/// carries as its `url`).
enum DeepLinkDestination: Hashable, Sendable {
    case route(AppRoute)
    case now
}

/// Parses the app's deep links.
///
/// Handles both `hotmess://venues/<uuid>` and
/// `https://hotmess.social/venues/<uuid>`. The original indexed
/// `pathComponents[1]` and `[2]` and force-unwrapped the result, so any
/// unexpected link crashed the app on open.
enum DeepLink {
    /// Everything the app opens from a link, pushes included.
    static func destination(for url: URL?) -> DeepLinkDestination? {
        guard let url else { return nil }
        if let route = route(for: url) { return .route(route) }
        return segments(of: url).first == "pings" ? .now : nil
    }

    /// A screen to push, or `nil` for a link with none (Now, or an unknown one).
    static func route(for url: URL) -> AppRoute? {
        let segments = segments(of: url)
        guard segments.count >= 2, let id = UUID(uuidString: segments[1]) else { return nil }

        switch segments[0] {
        case "venues": return .venue(id)
        case "events": return .event(id)
        case "people": return .person(id)
        default: return nil
        }
    }

    /// `["venues", "<uuid>"]` for either form of link.
    private static func segments(of url: URL) -> [String] {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return []
        }

        if url.scheme == "hotmess" {
            // hotmess://venues/<uuid> — the type is the host.
            return [components.host, components.path]
                .compactMap { $0 }
                .flatMap { $0.split(separator: "/").map(String.init) }
        }
        return components.path.split(separator: "/").map(String.init)
    }
}
