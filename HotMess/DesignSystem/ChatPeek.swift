//
//  ChatPeek.swift
//  HotMess
//

import SwiftUI

/// A read-only glimpse of a chat room (design system "ChatPeek"): the last few
/// messages as the room's own bubbles, with no message box. The whole panel is
/// one button that opens the room. It holds no connection; the screen showing
/// it refreshes `messages` when it loads.
struct ChatPeek: View {
    struct Participant: Identifiable {
        let id: String
        let name: String
        let avatarURL: URL?
        var presence: PresenceState? = nil
        var isPlace = false
    }

    /// What tapping the panel does.
    enum Destination {
        case route(AppRoute)
        case action(() -> Void)
    }

    /// "Chat" on a venue, "Small talk" on Now.
    let title: String
    /// The room's name, for VoiceOver: "Open the chat at {roomName}".
    let roomName: String
    /// Oldest first. Only the last `limit` show.
    let messages: [ChatThreadMessage]
    /// People in the room now, when known. Draws "N here now".
    var online: Int?
    var limit: Int
    var participants: [Participant]
    let destination: Destination

    @State private var width: CGFloat = 0

    init(
        title: String,
        roomName: String,
        messages: [ChatThreadMessage],
        online: Int? = nil,
        limit: Int = 3,
        participants: [Participant] = [],
        route: AppRoute
    ) {
        self.title = title
        self.roomName = roomName
        self.messages = messages
        self.online = online
        self.limit = limit
        self.participants = participants
        self.destination = .route(route)
    }

    init(
        title: String,
        roomName: String,
        messages: [ChatThreadMessage],
        online: Int? = nil,
        limit: Int = 3,
        participants: [Participant] = [],
        action: @escaping () -> Void
    ) {
        self.title = title
        self.roomName = roomName
        self.messages = messages
        self.online = online
        self.limit = limit
        self.participants = participants
        self.destination = .action(action)
    }

    var body: some View {
        Group {
            switch destination {
            case let .route(route):
                NavigationLink(value: route) { panel }
            case let .action(action):
                Button(action: action) { panel }
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("chat.peek")
    }

    private var visible: [ChatThreadMessage] {
        Array(messages.suffix(max(0, limit)))
    }

    private var panel: some View {
        VStack(alignment: .leading, spacing: 8) {
            header

            if !participants.isEmpty {
                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        ForEach(participants) { participant in
                            Avatar(
                                url: participant.avatarURL,
                                initials: participant.name.initialsForDisplay,
                                size: 32,
                                presence: participant.presence,
                                presenceRing: .hotMessSurfaceSunken,
                                isPlace: participant.isPlace
                            )
                        }
                    }
                    .padding(.vertical, 4)
                }
                .scrollIndicators(.hidden)
            }

            if visible.isEmpty {
                Text("No one's said anything yet. Say hello.")
                    .font(.hotMess(.subheadline))
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 0) {
                    ForEach(ChatThreadRow.rows(for: visible)) { row in
                        ChatPeekRow(row: row, maxBubbleWidth: maxBubbleWidth)
                    }
                }
            }

            HStack(spacing: 4) {
                Text(visible.isEmpty ? String(localized: "Start the chat") : String(localized: "Join the chat"))
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
            }
            .font(.hotMess(.subheadline, semibold: true))
            .foregroundStyle(Color.hotMessAccent)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.hotMessSurfaceSunken, in: .rect(cornerRadius: CardMetrics.cornerRadius))
        .contentShape(.rect(cornerRadius: CardMetrics.cornerRadius))
        .onGeometryChange(for: CGFloat.self) { geometry in
            geometry.size.width
        } action: { newValue in
            width = newValue
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(participants.map { participant in
            if let presence = participant.presence, presence != .offline {
                return participant.name + ", " + (presence == .online
                    ? String(localized: "In chat") : String(localized: "Reachable by notification"))
            }
            return participant.name
        }.joined(separator: "; "))
    }

    private var header: some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.hotMess(.subheadline, semibold: true))
                .foregroundStyle(.primary)

            Spacer(minLength: 0)

            if let online, online > 0 {
                HStack(spacing: 6) {
                    PresenceDot(state: .online, size: 8, ringColor: .hotMessSurfaceSunken)
                    Text("\(online) here now")
                        .monospacedDigit()
                }
                .font(.hotMess(.footnote))
                .foregroundStyle(.secondary)
            }
        }
    }

    /// Bubbles are at most 280 wide or 75% of the space inside the panel.
    private var maxBubbleWidth: CGFloat {
        guard width > 0 else { return ChatMetrics.bubbleMaxWidth }
        return min(ChatMetrics.bubbleMaxWidth, (width - 32) * ChatMetrics.bubbleMaxFraction)
    }

    private var accessibilityLabel: String {
        switch visible.count {
        case 0:
            String(localized: "Open the chat at \(roomName), no messages yet")
        case 1:
            String(localized: "Open the chat at \(roomName), 1 recent message")
        default:
            String(localized: "Open the chat at \(roomName), \(visible.count) recent messages")
        }
    }
}

/// One bubble in a peek: name above the first incoming bubble of a group,
/// avatar beside the last, text clamped to two lines. No time dividers.
private struct ChatPeekRow: View {
    let row: ChatThreadRow
    let maxBubbleWidth: CGFloat

    private var message: ChatThreadMessage { row.message }

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if !message.isOwn {
                if row.isLastInGroup {
                    ChatAvatar(message: message, presenceRing: .hotMessSurfaceSunken)
                } else {
                    Color.clear
                        .frame(width: ChatMetrics.avatarSize, height: 1)
                }
            }

            VStack(alignment: message.isOwn ? .trailing : .leading, spacing: 2) {
                if !message.isOwn, row.isFirstInGroup {
                    ChatSenderLine(name: message.authorName, role: message.role)
                        .padding(.leading, 12)
                }

                // Rich messages show their summary at a bubble's size.
                ChatBubble(
                    text: message.text,
                    isOwn: message.isOwn,
                    isLastInGroup: row.isLastInGroup,
                    isRole: message.role?.tintsBubble == true,
                    lineLimit: 2,
                    isSelectable: false
                )
            }
            .frame(maxWidth: maxBubbleWidth, alignment: message.isOwn ? .trailing : .leading)
        }
        .frame(maxWidth: .infinity, alignment: message.isOwn ? .trailing : .leading)
        .padding(.top, topSpacing)
    }

    /// 2 between bubbles in a group, 8 between groups.
    private var topSpacing: CGFloat {
        if row.isFirstRow { return 0 }
        return row.isFirstInGroup ? 8 : 2
    }
}

extension [VenueMessage] {
    /// Recent messages as a ChatPeek shows them: specials that have ended
    /// left out, friends by their full name, rich messages as their summary.
    func peekMessages(currentUserID: UUID?, friends: [UUID: Friend], at date: Date = .now) -> [ChatThreadMessage] {
        filter { $0.isShowing(at: date) }
            .map { $0.threadMessage(currentUserID: currentUserID, friends: friends, rich: false) }
    }
}

// MARK: - Previews

private enum ChatPeekPreviewData {
    static let start = Date(timeIntervalSince1970: 1_791_590_400)

    static let messages: [ChatThreadMessage] = [
        ChatThreadMessage(
            id: "1", authorID: "sam", authorName: "Sam B.", avatarURL: nil,
            text: "Anyone at the bar?", sentAt: start, isOwn: false
        ),
        ChatThreadMessage(
            id: "2", authorID: "sam", authorName: "Sam B.", avatarURL: nil,
            text: "DJ just started. This is a much longer message to show how a peek clamps a bubble to two lines with an ellipsis.",
            sentAt: start.addingTimeInterval(60), isOwn: false, presence: .online
        ),
        ChatThreadMessage(
            id: "3", authorID: "me", authorName: "Me", avatarURL: nil,
            text: "On my way, save me a spot", sentAt: start.addingTimeInterval(120), isOwn: true
        ),
    ]
}

#Preview("ChatPeek") {
    NavigationStack {
        ScrollView {
            VStack(spacing: 24) {
                ChatPeek(
                    title: "Chat",
                    roomName: "The Eagle",
                    messages: ChatPeekPreviewData.messages,
                    online: 4
                ) {}

                ChatPeek(title: "Small talk", roomName: "The Eagle", messages: []) {}
            }
            .padding(.horizontal, 16)
        }
        .background(Color(.systemGroupedBackground))
    }
}
