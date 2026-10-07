//
//  PingCards.swift
//  HotMess
//

import SwiftUI

/// The user's own running Ping, on top of Now: the picks, who can see it,
/// who's in, when it ends, and Edit / End.
struct MyPingCard: View {
    let ping: Ping
    let edit: () -> Void
    let end: () -> Void

    @State private var confirmingEnd = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("Your ping")
                    .font(.hotMess(.subheadline, semibold: true))
                    .foregroundStyle(Color.hotMessAccent)

                Text(ping.reach.title)
                    .font(.hotMess(.footnote))
                    .foregroundStyle(.secondary)

                Spacer(minLength: 8)

                Text(ping.endsText)
                    .font(.hotMess(.footnote))
                    .foregroundStyle(.secondary)
            }

            Text(ping.placesSummary ?? String(localized: "Anywhere tonight?"))
                .font(.hotMess(.headline, semibold: true))
                .lineLimit(3)

            if let note = ping.note {
                Text("“\(note)”")
                    .font(.hotMess(.subheadline))
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }

            HStack(spacing: 10) {
                if !ping.people.isEmpty {
                    FriendFaces(friends: ping.people)
                }

                Text(ping.peopleSummary ?? String(localized: "No one's in yet"))
                    .font(.hotMess(.subheadline))
                    .foregroundStyle(ping.people.isEmpty ? Color.secondary : Color.primary)
                    .lineLimit(2)

                Spacer(minLength: 8)
            }

            HStack(spacing: 12) {
                Button(action: edit) {
                    Text("Edit")
                        .font(.hotMess(.subheadline, semibold: true))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button(role: .destructive) {
                    confirmingEnd = true
                } label: {
                    Text("End")
                        .font(.hotMess(.subheadline, semibold: true))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(16)
        .background(Color.hotMessAccent.opacity(0.1), in: .rect(cornerRadius: CardMetrics.cornerRadius))
        .overlay {
            RoundedRectangle(cornerRadius: CardMetrics.cornerRadius)
                .strokeBorder(Color.hotMessAccent.opacity(0.3), lineWidth: 1)
        }
        .confirmationDialog(
            String(localized: "End your ping?"),
            isPresented: $confirmingEnd,
            titleVisibility: .visible
        ) {
            Button(String(localized: "End ping"), role: .destructive, action: end)
        } message: {
            Text("Your friends won't see it any more.")
        }
    }
}

/// A friend's Ping on Now: who sent it (and through whom you see it), the
/// circle, and "I'm in" on each pick or on the whole Ping.
struct FriendPingCard: View {
    let ping: Ping
    let userID: UUID?
    let isBusy: Bool
    let join: (PingTarget?) -> Void
    let leave: () -> Void

    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            HStack(spacing: 10) {
                FriendFaces(friends: ping.circle)

                if let summary = ping.peopleSummary {
                    Text(summary)
                        .font(.hotMess(.footnote))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            if ping.targets.isEmpty {
                wholePingButton
            } else {
                ForEach(ping.targets) { target in
                    targetRow(target)
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: CardMetrics.cornerRadius))
        .disabled(isBusy)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            Avatar(
                url: model.configuration.avatarURL(forUserID: ping.user.id),
                initials: ping.user.name.initialsForDisplay,
                size: 44
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(ping.user.firstName)
                    .font(.hotMess(.headline, semibold: true))

                if let via = ping.viaText {
                    Text(via)
                        .font(.hotMess(.footnote, semibold: true))
                        .foregroundStyle(.secondary)
                }

                Text(subtitle)
                    .font(.hotMess(.subheadline))
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }

            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }

    /// "“who's coming” · 9:46 PM", or "Anywhere tonight? · 9:30 PM".
    private var subtitle: String {
        let time = ping.createdAt.formatted(date: .omitted, time: .shortened)
        if let note = ping.note { return "“\(note)” · \(time)" }
        if ping.targets.isEmpty { return String(localized: "Anywhere tonight? · \(time)") }
        return time
    }

    private func targetRow(_ target: PingTarget) -> some View {
        HStack(spacing: 12) {
            targetLink(target) {
                HStack(spacing: 12) {
                    RemoteImage(url: target.imageURL)
                        .frame(width: 40, height: 40)
                        .clipShape(.rect(cornerRadius: 8))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(target.name)
                            .font(.hotMess(.subheadline, semibold: true))
                            .lineLimit(1)

                        Text(targetDetail(target))
                            .font(.hotMess(.footnote))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 0)
                }
                .contentShape(.rect)
            }

            PingJoinButton(isJoined: ping.isJoined(target, by: userID), compact: true) {
                join(target)
            } leave: {
                leave()
            }
        }
    }

    @ViewBuilder
    private func targetLink<Content: View>(_ target: PingTarget, @ViewBuilder label: () -> Content) -> some View {
        let content = label()
        if let event = target.event {
            NavigationLink(value: AppRoute.event(event.id)) { content }
                .buttonStyle(.plain)
        } else if let venue = target.venue {
            NavigationLink(value: AppRoute.venue(venue.id)) { content }
                .buttonStyle(.plain)
        } else {
            content
        }
    }

    private func targetDetail(_ target: PingTarget) -> String {
        let detail = target.detail ?? ""
        guard !target.joins.isEmpty else { return detail }
        let count = String(localized: "\(target.joins.count) in")
        return detail.isEmpty ? count : "\(detail) · \(count)"
    }

    private var wholePingButton: some View {
        PingJoinButton(isJoined: ping.isJoinedAsWhole(by: userID) || (userID == nil && ping.joined), compact: false) {
            join(nil)
        } leave: {
            leave()
        }
    }
}

/// "I'm in", or once you are, "You're in" with a way to leave.
struct PingJoinButton: View {
    let isJoined: Bool
    var compact = false
    let join: () -> Void
    let leave: () -> Void

    var body: some View {
        Group {
            if isJoined {
                Menu {
                    Button(String(localized: "Leave"), systemImage: "xmark", role: .destructive, action: leave)
                } label: {
                    Label(String(localized: "You're in"), systemImage: "checkmark")
                        .font(.hotMess(.subheadline, semibold: true))
                        .frame(maxWidth: compact ? nil : .infinity)
                }
                .buttonStyle(.bordered)
            } else {
                Button(action: join) {
                    Text("I'm in")
                        .font(.hotMess(.subheadline, semibold: true))
                        .frame(maxWidth: compact ? nil : .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .controlSize(compact ? .small : .regular)
        .fixedSize(horizontal: compact, vertical: false)
    }
}

/// Under a venue or event's hero: friends who picked this place tonight,
/// with "I'm in" and "Ping for here".
struct PingPlaceStrip: View {
    /// Friends' Pings that pick this place.
    let pings: [Ping]
    /// Whether the user is in on every one of them here.
    let isJoined: Bool
    let isBusy: Bool
    /// `nil` hides "Ping for here", for an event that isn't tonight.
    let pingForHere: (() -> Void)?
    let join: () -> Void
    let leave: () -> Void

    private var senders: [Friend] {
        var seen = Set<UUID>()
        return pings.map(\.user).filter { seen.insert($0.id).inserted }
    }

    var body: some View {
        DetailSection(String(localized: "Tonight")) {
            if pings.isEmpty {
                if let pingForHere {
                    HStack(spacing: 12) {
                        Text("Want to go here tonight?")
                            .font(.hotMess(.subheadline))
                        Spacer(minLength: 8)
                        Button(String(localized: "Ping for here"), action: pingForHere)
                            .font(.hotMess(.subheadline, semibold: true))
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        FriendFaces(friends: senders)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(headline)
                                .font(.hotMess(.subheadline, semibold: true))
                            Text(senders.map(\.firstName).formatted(.list(type: .and)))
                                .font(.hotMess(.footnote))
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                    }
                    .accessibilityElement(children: .combine)

                    HStack(spacing: 12) {
                        PingJoinButton(isJoined: isJoined, join: join, leave: leave)

                        if let pingForHere {
                            Button(action: pingForHere) {
                                Text("Ping for here")
                                    .font(.hotMess(.subheadline, semibold: true))
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    .disabled(isBusy)
                }
            }
        }
    }

    private var headline: String {
        senders.count == 1
            ? String(localized: "\(senders[0].firstName) wants to come here tonight")
            : String(localized: "\(senders.count) friends want to come here tonight")
    }
}
