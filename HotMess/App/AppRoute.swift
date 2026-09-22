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

    /// Which tab the route belongs in.
    var tab: AppTab {
        switch self {
        case .venue, .venueChat: .venues
        case .event: .events
        case .person: .people
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

/// Parses the app's deep links.
///
/// Handles both `hotmess://venues/<uuid>` and
/// `https://hotmess.social/venues/<uuid>`. The original indexed
/// `pathComponents[1]` and `[2]` and force-unwrapped the result, so any
/// unexpected link crashed the app on open.
enum DeepLink {
    static func route(for url: URL) -> AppRoute? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return nil
        }

        let segments: [String]

        if url.scheme == "hotmess" {
            // hotmess://venues/<uuid> — the type is the host.
            segments = [components.host, components.path]
                .compactMap { $0 }
                .flatMap { $0.split(separator: "/").map(String.init) }
        } else {
            segments = components.path.split(separator: "/").map(String.init)
        }

        guard segments.count >= 2, let id = UUID(uuidString: segments[1]) else { return nil }

        switch segments[0] {
        case "venues": return .venue(id)
        case "events": return .event(id)
        case "people": return .person(id)
        default: return nil
        }
    }
}
