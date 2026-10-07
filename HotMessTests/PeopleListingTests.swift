//
//  PeopleListingTests.swift
//  HotMessTests
//

import Foundation
import Testing

@testable import HotMess

@Suite("People near you")
struct PeopleListingTests {
    private let seattle = UUID()
    private let portland = UUID()
    private let now = Date(timeIntervalSince1970: 1_791_604_800)

    private func entry(
        _ name: String,
        home: UUID? = nil,
        featured: [UUID] = [],
        gigs: [PersonEntry.Gig] = []
    ) -> PersonEntry {
        PersonEntry(
            person: Person(id: UUID(), name: name),
            localeIDs: Set([home].compactMap { $0 } + featured),
            gigs: gigs,
            friends: []
        )
    }

    private func gig(in locale: UUID, hours: Double) -> PersonEntry.Gig {
        PersonEntry.Gig(date: now.addingTimeInterval(hours * 3600), localeID: locale, venueName: "Neighbours")
    }

    @Test("Playing this week comes first, soonest gig first, and isn't repeated under based here")
    func playingThenBased() {
        let listing = PeopleListing(everyone: [
            entry("Based", home: seattle),
            entry("Later", gigs: [gig(in: seattle, hours: 72)]),
            entry("Tonight", home: seattle, gigs: [gig(in: seattle, hours: 2)]),
        ])

        let local = listing.local(to: seattle, now: now)

        #expect(local.playing.map(\.entry.person.name) == ["Tonight", "Later"])
        #expect(local.based.map(\.person.name) == ["Based"])
    }

    @Test("Gigs elsewhere, past or beyond a week don't count, and nobody local is empty")
    func outsideTheWindow() {
        let listing = PeopleListing(everyone: [
            entry("Elsewhere", home: portland, gigs: [gig(in: portland, hours: 2)]),
            entry("Next month", gigs: [gig(in: seattle, hours: 24 * 30)]),
            entry("Last week", gigs: [gig(in: seattle, hours: -24 * 7)]),
            entry("Nowhere"),
        ])

        #expect(listing.local(to: seattle, now: now).isEmpty)
        #expect(listing.local(to: portland, now: now).playing.count == 1)
    }

    @Test("People featured in a city are based there too, without a home venue")
    func featured() {
        let listing = PeopleListing(everyone: [
            entry("Featured", featured: [seattle, portland]),
            entry("Home", home: portland),
        ])

        #expect(listing.local(to: seattle, now: now).based.map(\.person.name) == ["Featured"])
        #expect(listing.local(to: portland, now: now).based.map(\.person.name) == ["Featured", "Home"])
    }

    @Test("A gig that started earlier tonight still counts")
    func startedTonight() {
        let listing = PeopleListing(everyone: [entry("On now", gigs: [gig(in: seattle, hours: -3)])])

        #expect(listing.local(to: seattle, now: now).playing.count == 1)
    }
}
