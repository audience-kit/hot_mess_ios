//
//  ChatViews.swift
//  HotMess
//

import SwiftUI
import UIKit

// The shared chat kit (design system "Chat"): ChatThreadView and ChatBubble for
// a room's transcript, RoomBanner, ChatComposer, PresenceDot and ChatLine.
// None of these know about venues: rooms pass their title as `roomName`, so a
// venue room and a locale-wide room share them.

// MARK: - Colours

extension Color {
    /// Text and icons on `hotMessAccent` fills (`on-accent`). White on the
    /// light accent; dark on the dark accent, where white is only 2.4:1.
    static var hotMessOnAccent: Color { .dynamic(light: 0xFFFFFF, dark: 0x3A0A22) }

    /// `warning`: icons on `hotMessWarningSoft`.
    static var hotMessWarning: Color { .dynamic(light: 0x8A5300, dark: 0xF2B84B) }

    /// `warning-soft`: the background of a warning strip.
    static var hotMessWarningSoft: Color { .dynamic(light: 0xFDF1D9, dark: 0x34270E) }

    /// `presence-online`: connected to a chat room now.
    static var hotMessPresenceOnline: Color { .dynamic(light: 0x1F9D55, dark: 0x2FBF5B) }

    /// `presence-push`: not in chat, but gets push notifications.
    static var hotMessPresencePush: Color { .dynamic(light: 0xF5B400, dark: 0xF5B400) }

    /// `presence-push-edge`: keeps the yellow ring visible on light surfaces.
    static var hotMessPresencePushEdge: Color { .dynamic(light: 0x8A5300, dark: 0xF5B400) }

    /// A colour that resolves per light or dark appearance from 0xRRGGBB values.
    static func dynamic(light: UInt32, dark: UInt32) -> Color {
        Color(uiColor: UIColor { traits in
            let rgb = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(
                red: CGFloat((rgb >> 16) & 0xFF) / 255,
                green: CGFloat((rgb >> 8) & 0xFF) / 255,
                blue: CGFloat(rgb & 0xFF) / 255,
                alpha: 1
            )
        })
    }
}

/// Chat metrics from the design system's tokens.
enum ChatMetrics {
    /// `radius-bubble`.
    static let bubbleRadius: CGFloat = 16
    /// `radius-sm`: the "tail" corner of a group's last bubble.
    static let tailRadius: CGFloat = 4
    /// `size-bubble-max`.
    static let bubbleMaxWidth: CGFloat = 280
    /// Bubbles are never wider than this share of the transcript.
    static let bubbleMaxFraction: CGFloat = 0.75
    /// `size-avatar-sm`.
    static let avatarSize: CGFloat = 28
    /// Messages from one sender closer together than this form a group.
    static let groupGap: TimeInterval = 5 * 60
    /// A time divider follows any gap at least this long.
    static let dividerGap: TimeInterval = 15 * 60
}

/// How chat formats times.
enum ChatTime {
    /// A time divider's label, like "Fri 9 PM" or "Fri 9:26 PM".
    static func divider(_ date: Date, calendar: Calendar = .current) -> String {
        let style = Date.FormatStyle.dateTime
            .weekday(.abbreviated)
            .hour(.defaultDigits(amPM: .abbreviated))

        if calendar.component(.minute, from: date) == 0 {
            return date.formatted(style)
        }

        return date.formatted(style.minute(.twoDigits))
    }

    /// A compact age for chat previews: "now", "2m", "3h", "4d".
    static func relative(_ date: Date, now: Date = .now) -> String {
        let seconds = max(0, now.timeIntervalSince(date))

        switch seconds {
        case ..<60:
            return String(localized: "now")
        case ..<3600:
            return String(localized: "\(Int(seconds / 60))m")
        case ..<86_400:
            return String(localized: "\(Int(seconds / 3600))h")
        default:
            return String(localized: "\(Int(seconds / 86_400))d")
        }
    }
}

// MARK: - Presence

/// Whether someone can be reached right now.
enum PresenceState: Hashable, Sendable {
    /// Connected to a chat room now.
    case online
    /// Not in chat, but has a device that gets push notifications.
    case push
    /// Neither. Draws nothing.
    case offline
}

/// Green when someone is in chat, a yellow ring when they'll get a push
/// notification, nothing otherwise. Usually drawn by `Avatar(presence:)`.
struct PresenceDot: View {
    let state: PresenceState
    /// 10 on 28 avatars, 12 on 40 and up. The ring adds 2 on each side.
    var size: CGFloat = 10
    /// The ring that separates the dot from the photo under it.
    var ringColor: Color = Color(.secondarySystemGroupedBackground)

    var body: some View {
        switch state {
        case .online:
            Circle()
                .fill(Color.hotMessPresenceOnline)
                .frame(width: size, height: size)
                .modifier(PresenceRing(color: ringColor, label: String(localized: "In chat now")))
        case .push:
            ZStack {
                Circle()
                    .fill(Color.hotMessPresencePush)
                Circle()
                    .fill(ringColor)
                    .frame(width: size * 0.45, height: size * 0.45)
                Circle()
                    .strokeBorder(Color.hotMessPresencePushEdge, lineWidth: 1)
            }
            .frame(width: size, height: size)
            .modifier(PresenceRing(color: ringColor, label: String(localized: "Gets notifications")))
        case .offline:
            EmptyView()
        }
    }
}

private struct PresenceRing: ViewModifier {
    let color: Color
    let label: String

    func body(content: Content) -> some View {
        content
            .padding(2)
            .background(color, in: .circle)
            .accessibilityElement()
            .accessibilityLabel(label)
    }
}

// MARK: - Thread

/// One message as a chat room shows it. Rooms map their own message model to
/// this in the view layer.
struct ChatThreadMessage: Identifiable, Hashable, Sendable {
    let id: String
    /// Messages group by this, so it must be stable per sender.
    let authorID: String
    let authorName: String?
    let avatarURL: URL?
    let text: String
    /// When it was sent. Without one, the message joins its sender's group and
    /// no time divider is drawn around it.
    let sentAt: Date?
    /// Sent by the person reading.
    let isOwn: Bool
    var presence: PresenceState? = nil
}

/// A chat room's transcript: bubbles grouped by sender, with time dividers and
/// an empty state. Oldest first, kept scrolled to the newest message.
struct ChatThreadView: View {
    let messages: [ChatThreadMessage]
    /// The room's name, for the empty state ("Everyone at {name} can see…").
    let roomName: String

    @State private var width: CGFloat = 0

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                if messages.isEmpty {
                    ChatEmptyState(roomName: roomName)
                } else {
                    LazyVStack(spacing: 0) {
                        ForEach(ChatThreadRow.rows(for: messages)) { row in
                            ChatThreadRowView(row: row, maxBubbleWidth: maxBubbleWidth)
                                .id(row.id)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
            }
            .defaultScrollAnchor(.bottom, for: .initialOffset)
            .defaultScrollAnchor(.bottom, for: .sizeChanges)
            .scrollDismissesKeyboard(.interactively)
            .onGeometryChange(for: CGFloat.self) { geometry in
                geometry.size.width
            } action: { newValue in
                width = newValue
            }
            .onChange(of: messages.count) { _, _ in
                guard let last = messages.last else { return }
                withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
            }
        }
    }

    private var maxBubbleWidth: CGFloat {
        guard width > 0 else { return ChatMetrics.bubbleMaxWidth }
        return min(ChatMetrics.bubbleMaxWidth, (width - 32) * ChatMetrics.bubbleMaxFraction)
    }
}

/// A message with where it falls in its group.
struct ChatThreadRow: Identifiable, Hashable, Sendable {
    let message: ChatThreadMessage
    /// A time divider to draw above this message, if one opens here.
    let divider: Date?
    let isFirstInGroup: Bool
    let isLastInGroup: Bool
    /// The first row of the transcript, which needs no space above.
    let isFirstRow: Bool

    var id: String { message.id }

    static func rows(for messages: [ChatThreadMessage]) -> [ChatThreadRow] {
        let dividers = messages.indices.map { index in divider(at: index, in: messages) }

        return messages.indices.map { index in
            let message = messages[index]
            let isFirst = index == 0
                || dividers[index] != nil
                || !sameGroup(messages[index - 1], message)
            let isLast = index == messages.count - 1
                || dividers[index + 1] != nil
                || !sameGroup(message, messages[index + 1])

            return ChatThreadRow(
                message: message,
                divider: dividers[index],
                isFirstInGroup: isFirst,
                isLastInGroup: isLast,
                isFirstRow: index == 0
            )
        }
    }

    private static func divider(at index: Int, in messages: [ChatThreadMessage]) -> Date? {
        guard let sentAt = messages[index].sentAt else { return nil }
        guard index > 0 else { return sentAt }
        guard let previous = messages[index - 1].sentAt else { return nil }

        return sentAt.timeIntervalSince(previous) >= ChatMetrics.dividerGap ? sentAt : nil
    }

    private static func sameGroup(_ earlier: ChatThreadMessage, _ later: ChatThreadMessage) -> Bool {
        guard earlier.authorID == later.authorID, earlier.isOwn == later.isOwn else { return false }
        guard let earlierAt = earlier.sentAt, let laterAt = later.sentAt else { return true }

        return laterAt.timeIntervalSince(earlierAt) < ChatMetrics.groupGap
    }
}

private struct ChatThreadRowView: View {
    let row: ChatThreadRow
    let maxBubbleWidth: CGFloat

    private var message: ChatThreadMessage { row.message }

    var body: some View {
        VStack(spacing: 0) {
            if let divider = row.divider {
                Text(ChatTime.divider(divider))
                    .font(.hotMess(.caption, semibold: true))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.top, row.isFirstRow ? 0 : 12)
                    .padding(.bottom, 4)
                    .accessibilityAddTraits(.isHeader)
            }

            HStack(alignment: .bottom, spacing: 8) {
                if !message.isOwn {
                    if row.isLastInGroup {
                        Avatar(
                            url: message.avatarURL,
                            initials: message.authorName?.initialsForDisplay,
                            size: ChatMetrics.avatarSize,
                            presence: message.presence
                        )
                        .accessibilityHidden(true)
                    } else {
                        Color.clear
                            .frame(width: ChatMetrics.avatarSize, height: 1)
                    }
                }

                VStack(alignment: message.isOwn ? .trailing : .leading, spacing: 2) {
                    if !message.isOwn, row.isFirstInGroup, let name = message.authorName, !name.isEmpty {
                        Text(name)
                            .font(.hotMess(.caption, semibold: true))
                            .foregroundStyle(.secondary)
                            .padding(.leading, 12)
                            .accessibilityHidden(true)
                    }

                    ChatBubble(text: message.text, isOwn: message.isOwn, isLastInGroup: row.isLastInGroup)
                        .accessibilityLabel(accessibilityLabel)
                }
                .frame(maxWidth: maxBubbleWidth, alignment: message.isOwn ? .trailing : .leading)
            }
            .frame(maxWidth: .infinity, alignment: message.isOwn ? .trailing : .leading)
        }
        .padding(.top, topSpacing)
    }

    /// 2 between bubbles in a group, 8 between groups.
    private var topSpacing: CGFloat {
        if row.isFirstRow || row.divider != nil { return 0 }
        return row.isFirstInGroup ? 8 : 2
    }

    private var accessibilityLabel: String {
        if message.isOwn {
            return String(localized: "You: \(message.text)")
        }
        let name = message.authorName.flatMap { $0.isEmpty ? nil : $0 } ?? String(localized: "Someone")
        return "\(name): \(message.text)"
    }
}

/// One chat bubble. The last bubble of a group drops its corner nearest the
/// sender to a small "tail".
struct ChatBubble: View {
    let text: String
    let isOwn: Bool
    var isLastInGroup: Bool = true

    var body: some View {
        Text(text)
            .font(.hotMess(.subheadline))
            .foregroundStyle(isOwn ? Color.hotMessOnAccent : Color.primary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background {
                if isOwn {
                    shape.fill(Color.hotMessAccent)
                } else {
                    shape
                        .fill(Color(.secondarySystemGroupedBackground))
                        .shadow(color: .black.opacity(0.12), radius: 1, x: 0, y: 1)
                }
            }
            .textSelection(.enabled)
    }

    private var shape: UnevenRoundedRectangle {
        let tail = isLastInGroup ? ChatMetrics.tailRadius : ChatMetrics.bubbleRadius
        let radius = ChatMetrics.bubbleRadius

        return UnevenRoundedRectangle(
            topLeadingRadius: radius,
            bottomLeadingRadius: isOwn ? radius : tail,
            bottomTrailingRadius: isOwn ? tail : radius,
            topTrailingRadius: radius,
            style: .continuous
        )
    }
}

/// An empty room: "Say hello."
struct ChatEmptyState: View {
    let roomName: String

    var body: some View {
        VStack(spacing: 4) {
            Text("Say hello.")
                .font(.hotMess(.headline, semibold: true))
            Text("Everyone at \(roomName) can see what you write here.")
                .font(.hotMess(.subheadline))
                .foregroundStyle(.secondary)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 16)
        .padding(.vertical, 40)
    }
}

// MARK: - Banner

/// The strip under a room's title that says why the reader is (or isn't
/// fully) in the room. Only one shows; `range` wins.
struct RoomBanner: View {
    enum Kind: Hashable, Sendable {
        /// An admin in the room from outside the place it's for.
        case range
        case connecting
        /// The connection's own reason when it gave one, else a plain "Offline."
        case offline(String?)
    }

    let kind: Kind
    let roomName: String

    var body: some View {
        switch kind {
        case .range:
            HStack(spacing: 8) {
                Image(systemName: "location.slash")
                    .foregroundStyle(Color.hotMessWarning)
                    .accessibilityHidden(true)
                Text("You're not at \(roomName). You're in this chat because you're an admin.")
                    .foregroundStyle(.primary)
            }
            .font(.hotMess(.footnote))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.hotMessWarningSoft)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("chat.outOfRange")
        case .connecting, .offline:
            Text(stripText)
                .font(.hotMess(.footnote))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 4)
                .background(Color(.tertiarySystemFill))
                .accessibilityIdentifier(kind == .connecting ? "chat.connecting" : "chat.offline")
        }
    }

    private var stripText: String {
        switch kind {
        case .connecting: String(localized: "Connecting…")
        case let .offline(reason): reason ?? String(localized: "Offline.")
        case .range: ""
        }
    }
}

// MARK: - Composer

/// The message field and send button pinned to the bottom of a room. Sending
/// is the room's own code; this is only the look.
struct ChatComposer: View {
    @Binding var text: String
    /// False while the field is empty or the room is offline.
    let canSend: Bool
    let send: () -> Void

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            TextField(String(localized: "Message"), text: $text, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.hotMess(.body))
                .lineLimit(1 ... 4)
                .submitLabel(.send)
                .onSubmit(send)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .frame(minHeight: 40)
                .background(Color(.tertiarySystemGroupedBackground), in: .rect(cornerRadius: 20))
                .overlay {
                    RoundedRectangle(cornerRadius: 20)
                        .strokeBorder(Color(.systemGray), lineWidth: 1)
                }

            Button(action: send) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(canSend ? Color.hotMessOnAccent : Color.secondary)
                    .frame(width: 40, height: 40)
                    .background(canSend ? Color.hotMessAccent : Color(.tertiarySystemFill), in: .circle)
            }
            .buttonStyle(.plain)
            .disabled(!canSend)
            .accessibilityLabel(String(localized: "Send"))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.secondarySystemGroupedBackground))
        .overlay(alignment: .top) {
            Divider()
        }
    }
}

// MARK: - Chat line

/// A flat, bubble-less chat message: the Now screen's "Small talk" preview.
struct ChatLine: View {
    /// Falls back to "Someone".
    let author: String?
    let avatarURL: URL?
    let text: String
    /// Pre-formatted, like "2m".
    let time: String
    var presence: PresenceState? = nil
    /// Lines of text before an ellipsis; `nil` shows it all.
    var lineLimit: Int? = 2

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Avatar(
                url: avatarURL,
                initials: author?.initialsForDisplay,
                size: ChatMetrics.avatarSize,
                presence: presence
            )

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text(displayAuthor)
                        .font(.hotMess(.caption, semibold: true))
                    Text(time)
                        .font(.hotMess(.caption))
                        .monospacedDigit()
                }
                .foregroundStyle(.secondary)
                .lineLimit(1)

                Text(text)
                    .font(.hotMess(.subheadline))
                    .lineLimit(lineLimit)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }

    private var displayAuthor: String {
        guard let author, !author.isEmpty else { return String(localized: "Someone") }
        return author
    }
}

// MARK: - Previews

private enum ChatPreviewData {
    static let start = Date(timeIntervalSince1970: 1_791_590_400) // A Friday, 9pm UTC.

    static func message(
        _ index: Int,
        _ author: String,
        _ text: String,
        minutes: Double,
        own: Bool = false,
        presence: PresenceState? = nil
    ) -> ChatThreadMessage {
        ChatThreadMessage(
            id: "\(index)",
            authorID: own ? "me" : author,
            authorName: own ? "Me" : author,
            avatarURL: nil,
            text: text,
            sentAt: start.addingTimeInterval(minutes * 60),
            isOwn: own,
            presence: presence
        )
    }

    static let messages: [ChatThreadMessage] = [
        message(0, "Sam", "Anyone at the bar?", minutes: 0),
        message(1, "Sam", "The line's out the door", minutes: 1, presence: .online),
        message(2, "Alex", "Just got here", minutes: 3, presence: .push),
        message(3, "Me", "On my way, save me a spot", minutes: 4, own: true),
        message(4, "Me", "Five minutes", minutes: 4.5, own: true),
        message(5, "Sam", "DJ just started. This is a much longer message to show how a bubble wraps when it runs past the maximum width.", minutes: 25, presence: .online),
        message(6, "Me", "🔥", minutes: 26, own: true),
    ]
}

#Preview("Thread") {
    NavigationStack {
        VStack(spacing: 0) {
            RoomBanner(kind: .range, roomName: "The Eagle")
            ChatThreadView(messages: ChatPreviewData.messages, roomName: "The Eagle")
            ChatComposer(text: .constant(""), canSend: false) {}
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("The Eagle")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview("Empty, connecting") {
    VStack(spacing: 0) {
        RoomBanner(kind: .connecting, roomName: "The Eagle")
        ChatThreadView(messages: [], roomName: "The Eagle")
        ChatComposer(text: .constant("Hi"), canSend: true) {}
    }
    .background(Color(.systemGroupedBackground))
}

#Preview("Banners") {
    VStack(spacing: 12) {
        RoomBanner(kind: .range, roomName: "The Eagle")
        RoomBanner(kind: .connecting, roomName: "The Eagle")
        RoomBanner(kind: .offline(nil), roomName: "The Eagle")
    }
}

#Preview("Bubbles") {
    VStack(alignment: .leading, spacing: 2) {
        ChatBubble(text: "In a group", isOwn: false, isLastInGroup: false)
        ChatBubble(text: "Last of the group", isOwn: false)
        ChatBubble(text: "Mine", isOwn: true)
            .frame(maxWidth: .infinity, alignment: .trailing)
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}

#Preview("Presence") {
    HStack(spacing: 16) {
        Avatar(url: nil, initials: "SA", size: 28, presence: .online)
        Avatar(url: nil, initials: "AL", size: 28, presence: .push)
        Avatar(url: nil, initials: "JO", size: 28, presence: .offline)
        Avatar(url: nil, initials: "SA", size: 56, presence: .online)
        Avatar(url: nil, initials: "AL", size: 56, presence: .push)
    }
    .padding()
    .background(Color(.secondarySystemGroupedBackground))
}

#Preview("Chat lines") {
    VStack(alignment: .leading, spacing: 12) {
        ChatLine(author: "Sam", avatarURL: nil, text: "The line's out the door", time: "2m", presence: .online)
        ChatLine(author: nil, avatarURL: nil, text: "A longer line that runs past two lines on a phone so it shows the ellipsis at the end of the second line.", time: "1h")
    }
    .padding()
}
