//
//  Ping.swift
//  HotMess
//

import Foundation

/// "I want to go out tonight": a friend's call to go out, which lasts until
/// 5am and may name venues and events (or none, for "anywhere tonight?").
///
/// Only the sender's friends on Hot Mess see it. Each person has at most one
/// active Ping; sending again edits it.
struct Ping: Decodable, Hashable, Sendable, Identifiable {
    let id: String
    /// Who sent it.
    let user: Friend
    /// The sender's own words, which may hold emoji.
    let note: String?
    let createdAt: Date
    /// The next 5am in the Ping's locale.
    let expiresAt: Date
    /// Sent by the signed-in user.
    let isMine: Bool
    /// The signed-in user is in, on any pick or on the Ping as a whole.
    let joined: Bool
    /// The picks in the order the sender made them. Empty means "anywhere".
    let targets: [PingTarget]
    /// Everyone who is in, oldest first. With the sender they are the
    /// Ping's circle.
    let joins: [PingJoin]
    /// Who can see it.
    let reach: PingReach
    /// The circle member the viewer knows, when the viewer sees this Ping
    /// through them rather than as the sender's friend.
    let via: Friend?

    enum CodingKeys: String, CodingKey {
        case id, user, note, joined, targets, joins, reach, via
        case createdAt = "created_at"
        case expiresAt = "expires_at"
        case isMine = "is_mine"
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(String.self, forKey: .id)
        user = try container.decode(Friend.self, forKey: .user)
        let note = try container.decodeIfPresent(String.self, forKey: .note)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.note = note?.isEmpty == false ? note : nil
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        expiresAt = try container.decode(Date.self, forKey: .expiresAt)
        isMine = try container.decodeIfPresent(Bool.self, forKey: .isMine) ?? false
        joined = try container.decodeIfPresent(Bool.self, forKey: .joined) ?? false
        targets = try container.decodeIfPresent([PingTarget].self, forKey: .targets) ?? []
        joins = try container.decodeIfPresent([PingJoin].self, forKey: .joins) ?? []
        reach = try container.decodeIfPresent(PingReach.self, forKey: .reach) ?? .friends
        via = try container.decodeIfPresent(Friend.self, forKey: .via)
    }

    init(
        id: String,
        user: Friend,
        note: String? = nil,
        createdAt: Date,
        expiresAt: Date,
        isMine: Bool = false,
        joined: Bool = false,
        targets: [PingTarget] = [],
        joins: [PingJoin] = [],
        reach: PingReach = .friends,
        via: Friend? = nil
    ) {
        self.id = id
        self.user = user
        self.note = note
        self.createdAt = createdAt
        self.expiresAt = expiresAt
        self.isMine = isMine
        self.joined = joined
        self.targets = targets
        self.joins = joins
        self.reach = reach
        self.via = via
    }
}

/// Who can see a Ping.
enum PingReach: String, Decodable, Hashable, Sendable, CaseIterable {
    /// Only the sender's friends.
    case friends = "FRIENDS"
    /// Friends of anyone in the circle, so it spreads as people join.
    case friendsOfCircle = "FRIENDS_OF_CIRCLE"

    init(from decoder: any Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = PingReach(rawValue: raw) ?? .friends
    }

    var title: String {
        switch self {
        case .friends: String(localized: "My friends")
        case .friendsOfCircle: String(localized: "Friends of the circle")
        }
    }
}

/// One pick on a Ping: a venue or an event.
struct PingTarget: Decodable, Hashable, Sendable, Identifiable {
    let id: String
    let venue: Venue?
    let event: Event?
    /// Who is in for this pick.
    let joins: [PingJoin]

    enum CodingKeys: String, CodingKey {
        case id, venue, event, joins
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(String.self, forKey: .id)
        venue = try container.decodeIfPresent(Venue.self, forKey: .venue)
        event = try container.decodeIfPresent(Event.self, forKey: .event)
        joins = try container.decodeIfPresent([PingJoin].self, forKey: .joins) ?? []
    }

    init(id: String, venue: Venue? = nil, event: Event? = nil, joins: [PingJoin] = []) {
        self.id = id
        self.venue = venue
        self.event = event
        self.joins = joins
    }

    var name: String { event?.name ?? venue?.name ?? "" }

    /// The place this pick names, for matching against the send sheet's picks.
    var place: PingPlace? {
        if let event { return .event(event.id) }
        if let venue { return .venue(venue.id) }
        return nil
    }

    /// Whether this pick is `venueID` itself or one of its events.
    func isAt(venueID: UUID) -> Bool {
        venue?.id == venueID || event?.venue?.id == venueID
    }
}

/// Someone who is in, for one pick or (with no `targetID`) the whole Ping.
struct PingJoin: Decodable, Hashable, Sendable, Identifiable {
    let id: String
    let user: Friend
    let targetID: String?

    enum CodingKeys: String, CodingKey {
        case id, user
        case targetID = "target_id"
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(String.self, forKey: .id)
        user = try container.decode(Friend.self, forKey: .user)
        targetID = try container.decodeIfPresent(String.self, forKey: .targetID)
    }

    init(id: String, user: Friend, targetID: String? = nil) {
        self.id = id
        self.user = user
        self.targetID = targetID
    }
}

/// A venue or event that can be picked for a Ping.
enum PingPlace: Hashable, Sendable {
    case venue(UUID)
    case event(UUID)
}

// MARK: - Display

extension Ping {
    /// The picks' names, "Drag Bingo · The Wildrose", or `nil` for "anywhere".
    var placesSummary: String? {
        let names = targets.map(\.name).filter { !$0.isEmpty }
        return names.isEmpty ? nil : names.joined(separator: " · ")
    }

    /// The picks as send-sheet places, in the sender's order.
    var places: [PingPlace] { targets.compactMap(\.place) }

    /// Everyone who is in, once each, oldest first.
    var people: [Friend] {
        var seen = Set<UUID>()
        return joins.map(\.user).filter { seen.insert($0.id).inserted }
    }

    /// The circle: the sender, then everyone who is in.
    var circle: [Friend] {
        var seen: Set<UUID> = [user.id]
        return [user] + joins.map(\.user).filter { seen.insert($0.id).inserted }
    }

    /// "via Sam", when the viewer sees this through a circle member.
    var viaText: String? {
        via.map { String(localized: "via \($0.firstName)") }
    }

    /// "Sam is in", "Sam and Alex are in", or `nil` when nobody is yet.
    var peopleSummary: String? {
        Self.inSummary(people)
    }

    /// Whether `userID` is in on `target`.
    func isJoined(_ target: PingTarget, by userID: UUID?) -> Bool {
        guard let userID else { return false }
        return target.joins.contains { $0.user.id == userID }
            || joins.contains { $0.user.id == userID && $0.targetID == target.id }
    }

    /// Whether `userID` is in on the Ping as a whole rather than one pick.
    /// Without a user ID it falls back on `joined`.
    func isJoinedAsWhole(by userID: UUID?) -> Bool {
        guard let userID else { return joined }
        return joins.contains { $0.user.id == userID && $0.targetID == nil }
    }

    /// The picks at `venueID`: the venue itself or its events.
    func targets(atVenue venueID: UUID) -> [PingTarget] {
        targets.filter { $0.isAt(venueID: venueID) }
    }

    func target(forEvent eventID: UUID) -> PingTarget? {
        targets.first { $0.event?.id == eventID }
    }

    /// "Ends 5:00 AM".
    var endsText: String {
        String(localized: "Ends \(expiresAt.formatted(date: .omitted, time: .shortened))")
    }

    func isActive(at date: Date) -> Bool { expiresAt > date }

    /// Friends' Pings to show: still running, not the user's own, newest first.
    static func friendFeed(_ pings: [Ping], at date: Date) -> [Ping] {
        pings
            .filter { !$0.isMine && $0.isActive(at: date) }
            .sorted { $0.createdAt > $1.createdAt }
    }

    /// "Sam is in", "Sam and Alex are in", or `nil` for nobody.
    static func inSummary(_ friends: [Friend]) -> String? {
        guard !friends.isEmpty else { return nil }
        let names = friends.map(\.firstName).formatted(.list(type: .and))
        return friends.count == 1
            ? String(localized: "\(names) is in")
            : String(localized: "\(names) are in")
    }
}

extension PingTarget {
    /// What the pick is, under its name: when and where for an event, the
    /// venue's summary for a venue.
    var detail: String? {
        if let event { return event.subtitle }
        return venue?.summary
    }

    var imageURL: URL? { event?.coverURL ?? venue?.photoURL }
}

extension Now {
    /// The same Now with `ping` swapped in where it already appears: as the
    /// user's own Ping when it is theirs, otherwise in the friends' Pings.
    func replacing(_ ping: Ping) -> Now {
        var now = self
        if ping.isMine {
            now.myPing = ping
        } else if let index = now.friendPings.firstIndex(where: { $0.id == ping.id }) {
            now.friendPings[index] = ping
        } else {
            now.friendPings.insert(ping, at: 0)
        }
        return now
    }

    /// The same Now with the user's own Ping gone.
    func removingMyPing() -> Now {
        var now = self
        now.myPing = nil
        return now
    }
}

extension Array where Element == Ping {
    /// The list with `ping` swapped in for the one with its ID.
    func replacing(_ ping: Ping) -> [Ping] {
        map { $0.id == ping.id ? ping : $0 }
    }
}
