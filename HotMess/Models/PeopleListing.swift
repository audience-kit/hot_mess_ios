//
//  PeopleListing.swift
//  HotMess
//

import AudienceKit
import Foundation

/// A person on the People tab, with where they're local and which of your
/// friends are with them.
struct PersonEntry: Hashable, Sendable, Identifiable {
    let person: Person
    /// The locales they're based in: their home venue's, and every one
    /// they're featured in.
    let localeIDs: Set<UUID>
    /// Upcoming gigs, soonest first.
    let gigs: [Gig]
    /// Your friends at their home venue or a gig's venue right now, each once.
    let friends: [Friend]

    var id: UUID { person.id }

    struct Gig: Hashable, Sendable {
        let date: Date
        let localeID: UUID?
        let venueName: String?
    }
}

extension PersonEntry {
    init?(_ person: AudienceKit.Person, resolve: (String?) -> URL?) {
        guard let base = Person(person, resolve: resolve) else { return nil }

        let venues = [person.homeVenue] + (person.events ?? []).map(\.venue)
        var seen = Set<UUID>()
        let friends = venues
            .compactMap { $0?.friends }
            .joined()
            .compactMap { Friend($0) }
            .filter { seen.insert($0.id).inserted }

        self.init(
            person: base,
            localeIDs: Set(
                ([person.homeVenue?.locale?.id] + (person.locales ?? []).map(\.id))
                    .compactMap { $0.flatMap(RecordID.uuid) }
            ),
            gigs: (person.events ?? []).compactMap { event in
                guard let date = event.startDate else { return nil }
                return Gig(
                    date: date,
                    localeID: (event.venue?.locale?.id ?? event.locale?.id).flatMap(RecordID.uuid),
                    venueName: event.venue?.name
                )
            },
            friends: friends
        )
    }
}

extension Friend {
    init?(_ friend: AudienceKit.Friend) {
        guard let id = RecordID.uuid(friend.id) else { return nil }
        self.init(id: id, name: friend.name ?? "", facebookID: friend.facebookId.map(FacebookID.init))
    }
}

/// The audience's people, as everyone or as who's local to one city.
struct PeopleListing: Hashable, Sendable {
    let everyone: [PersonEntry]

    /// How far ahead "playing this week" looks, and how far back a gig that
    /// started tonight still counts.
    static let window: TimeInterval = 7 * 24 * 60 * 60
    static let grace: TimeInterval = 6 * 60 * 60

    struct Playing: Hashable, Sendable, Identifiable {
        let entry: PersonEntry
        let gig: PersonEntry.Gig

        var id: UUID { entry.id }
    }

    struct Local: Hashable, Sendable {
        /// People with a gig in the city this week, soonest gig first.
        let playing: [Playing]
        /// People based in or featured in the city who aren't playing it
        /// this week.
        let based: [PersonEntry]

        var isEmpty: Bool { playing.isEmpty && based.isEmpty }
    }

    var isEmpty: Bool { everyone.isEmpty }

    func local(to localeID: UUID, now: Date = .now) -> Local {
        let earliest = now.addingTimeInterval(-Self.grace)
        let latest = now.addingTimeInterval(Self.window)

        let playing = everyone
            .compactMap { entry -> Playing? in
                entry.gigs
                    .first { $0.localeID == localeID && $0.date >= earliest && $0.date <= latest }
                    .map { Playing(entry: entry, gig: $0) }
            }
            .sorted { $0.gig.date < $1.gig.date }

        let playingIDs = Set(playing.map(\.id))
        let based = everyone.filter { $0.localeIDs.contains(localeID) && !playingIDs.contains($0.id) }

        return Local(playing: playing, based: based)
    }
}
