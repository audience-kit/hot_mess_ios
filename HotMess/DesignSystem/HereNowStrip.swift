//
//  HereNowStrip.swift
//  HotMess
//

import SwiftUI

/// Someone in a chat room now, as the Here now strip draws them.
struct HereNowPerson: Identifiable, Hashable, Sendable {
    let id: UUID
    /// A friend's full name, else the "First L." rooms send everyone. `nil`
    /// when the room hasn't said.
    let name: String?
    let avatarURL: URL?
    let isFriend: Bool

    var displayName: String { name ?? String(localized: "Someone") }

    /// Under their avatar.
    var firstName: String { name?.firstNameForDisplay ?? String(localized: "Someone") }

    /// What VoiceOver reads: "Aurora Bell, friend, here now".
    var accessibilityLabel: String {
        isFriend
            ? String(localized: "\(displayName), friend, here now")
            : String(localized: "\(displayName), here now")
    }

    /// Friends first, then everyone else, each by name. People with no name
    /// come last in their group.
    static func sorted(_ people: some Sequence<HereNowPerson>) -> [HereNowPerson] {
        people.sorted { lhs, rhs in
            if lhs.isFriend != rhs.isFriend { return lhs.isFriend }

            switch (lhs.name, rhs.name) {
            case let (left?, right?):
                let order = left.localizedStandardCompare(right)
                if order != .orderedSame { return order == .orderedAscending }
            case (.some, nil):
                return true
            case (nil, .some):
                return false
            case (nil, nil):
                break
            }

            // A stable order for people with the same name.
            return lhs.id.uuidString < rhs.id.uuidString
        }
    }
}

/// Who else is in a chat room now: a count and their faces in one short row
/// under the room's banner, friends first with an accent ring and a heart.
/// Draw it only when someone else is here.
struct HereNowStrip: View {
    let people: [HereNowPerson]

    var body: some View {
        // One compact row: the count, then the faces. A horizontal scroll view
        // takes all the height it's offered, so it's held to its content's;
        // otherwise it splits the screen with the thread below it.
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(alignment: .center, spacing: 10) {
                Text(countLabel)
                    .font(.hotMess(.caption, semibold: true))
                    .foregroundStyle(.secondary)
                    .fixedSize()
                    .accessibilityAddTraits(.isHeader)

                ForEach(people) { person in
                    HereNowFace(person: person)
                }
            }
            .padding(.horizontal, 16)
            // Room for the friend badge, which sits above the ring.
            .padding(.top, 2)
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .overlay(alignment: .bottom) {
            Divider()
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("chat.hereNow")
    }

    private var countLabel: String {
        String(localized: "\(people.count) here now")
    }
}

/// One person in the Here now strip: their avatar, in the room (so always
/// with the online dot), and their first name under it. A friend gets an
/// accent ring and a heart badge, and their name in accent ink.
struct HereNowFace: View {
    let person: HereNowPerson
    /// The surface behind the strip, for the rings around the dot and badge.
    var surface: Color = Color(.secondarySystemGroupedBackground)

    private static let avatarSize: CGFloat = 32
    /// The gap between the photo and a friend's ring.
    private static let ringInset: CGFloat = 2

    var body: some View {
        VStack(spacing: 2) {
            Avatar(url: person.avatarURL, initials: person.name?.initialsForDisplay, size: Self.avatarSize)
                .padding(Self.ringInset)
                .overlay {
                    if person.isFriend {
                        Circle().strokeBorder(Color.hotMessAccent, lineWidth: 2)
                    }
                }
                // Drawn over the ring, which would otherwise cover half of it.
                .overlay(alignment: .bottomTrailing) {
                    PresenceDot(state: .online, size: 10, ringColor: surface)
                        .offset(x: -1, y: -1)
                }
                .overlay(alignment: .topTrailing) {
                    if person.isFriend {
                        FriendBadge(surface: surface)
                            .offset(x: 3, y: -3)
                    }
                }

            Text(person.firstName)
                .font(.hotMess(.caption2, semibold: person.isFriend))
                .foregroundStyle(person.isFriend ? Color.hotMessAccentInk : Color.secondary)
                .lineLimit(1)
                .frame(maxWidth: Self.avatarSize + Self.ringInset * 2 + 16)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(person.accessibilityLabel)
    }
}

/// The small heart on a friend's avatar.
private struct FriendBadge: View {
    let surface: Color

    var body: some View {
        Image(systemName: "heart.fill")
            .font(.system(size: 7, weight: .bold))
            .foregroundStyle(Color.hotMessOnAccent)
            .frame(width: 13, height: 13)
            .background(Color.hotMessAccent, in: .circle)
            .padding(2)
            .background(surface, in: .circle)
            .accessibilityHidden(true)
    }
}

// MARK: - Previews

#Preview("Here now") {
    let people = HereNowPerson.sorted([
        HereNowPerson(id: UUID(), name: "Sam K.", avatarURL: nil, isFriend: false),
        HereNowPerson(id: UUID(), name: "Aurora Bell", avatarURL: nil, isFriend: true),
        HereNowPerson(id: UUID(), name: "Jo P.", avatarURL: nil, isFriend: false),
        HereNowPerson(id: UUID(), name: "Alex Rivera", avatarURL: nil, isFriend: true),
        HereNowPerson(id: UUID(), name: nil, avatarURL: nil, isFriend: false),
    ])

    VStack(spacing: 0) {
        RoomBanner(kind: .range, roomName: "The Eagle")
        HereNowStrip(people: people)
        PinnedBar(author: "The Eagle", title: "Beer bust starts at 3") {}
        Spacer()
    }
    .background(Color(.systemGroupedBackground))
}
