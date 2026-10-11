//
//  NotificationStream.swift
//  HotMess
//

import Foundation
import Observation

/// A notification the API sent the user, as `myNotifications` brings it to the
/// open app: the same one APNs delivers, with the same `notification_id`.
struct InAppNotification: Identifiable, Equatable, Sendable {
    /// `notificationId`, which the push's `notification_id` repeats.
    let id: String
    let title: String?
    let body: String?
    /// The iOS category its push has (`PING`), if any.
    let category: String?
    /// What the push payload carries next to `aps` (`kind`, `ping_id`,
    /// `notification_id`), each value as a string.
    let data: [String: String]
    let sentAt: Date?

    /// The Ping it's about, read the way a push's payload is.
    var ping: PingNotification? { PingNotification(userInfo: data) }

    /// The `notification_id` a push's payload (or `data`) carries, if any.
    static func notificationID(in userInfo: [AnyHashable: Any]) -> String? {
        switch userInfo["notification_id"] {
        case let id as String where !id.isEmpty: id
        case let id as NSNumber: id.stringValue
        default: nil
        }
    }
}

/// The last few notification IDs the app has shown, in the app or as a system
/// banner, so the other copy of each is dropped. Holds at most `capacity`,
/// forgetting the oldest first.
struct RecentNotificationIDs: Sendable {
    let capacity: Int
    private var order: [String] = []
    private var ids: Set<String> = []

    init(capacity: Int = 64) {
        self.capacity = max(1, capacity)
    }

    var count: Int { order.count }

    func contains(_ id: String) -> Bool {
        ids.contains(id)
    }

    /// Remembers `id`; false when it was already remembered.
    @discardableResult
    mutating func insert(_ id: String) -> Bool {
        guard ids.insert(id).inserted else { return false }

        order.append(id)
        if order.count > capacity {
            ids.remove(order.removeFirst())
        }
        return true
    }

    mutating func removeAll() {
        order.removeAll()
        ids.removeAll()
    }
}

/// `Subscription.myNotifications` over `GraphQLChannel`: the document, and
/// what its frames mean.
enum NotificationStreamConnection {
    enum Event: Sendable, Equatable {
        /// The subscription went out: notifications arrive from now on. (The
        /// server sends nothing on subscribing.)
        case listening
        case received(InAppNotification)
        /// The server turned the subscription away (a build without the
        /// permission, a server without the field). Retrying won't help.
        case refused
        case disconnected(String?)
    }

    static let operationName = "MyNotifications"

    static let document = """
    subscription MyNotifications {
      notification: myNotifications { notificationId title body category data sentAt }
    }
    """

    static func executeData() -> String {
        GraphQLCable.executeData(operationName: operationName, query: document)
    }

    static func socket(
        url: URL,
        token: String?,
        audienceID: String,
        channelID: String = UUID().uuidString.lowercased()
    ) -> GraphQLCableSocket<Event> {
        GraphQLCableSocket(
            url: url,
            token: token,
            identifier: GraphQLCable.identifier(audienceID: audienceID, channelID: channelID),
            executeData: executeData(),
            name: "Notifications",
            confirmed: .listening,
            closed: { .disconnected($0) },
            parse: { incoming(from: $0) }
        )
    }

    static func incoming(from data: Data) -> GraphQLCable.Incoming<Event> {
        switch GraphQLCable.Frame<Result>(data: data) {
        case .confirmed:
            return .confirmed
        case .rejected:
            return .events([.refused])
        case .disconnect:
            return .events([.disconnected(nil)])
        case let .result(result, more):
            var events: [Event] = []
            if let notification = result.notification {
                events.append(.received(notification))
            } else if !result.errors.isEmpty {
                Log.realtime.error("Notifications subscription refused: \(result.errors.joined(separator: "; "), privacy: .public)")
                return .events([.refused])
            }
            if !more { events.append(.disconnected(nil)) }
            return .events(events)
        case .ignored:
            return .events([])
        }
    }

    /// The events one frame means, ignoring the confirmation.
    static func events(from data: Data) -> [Event] {
        switch incoming(from: data) {
        case .confirmed: []
        case let .events(events): events
        }
    }

    /// `{ data: { notification }, errors }`.
    private struct Result: Decodable {
        let notification: InAppNotification?
        let errors: [String]

        enum CodingKeys: String, CodingKey { case data, errors }
        private enum DataKeys: String, CodingKey { case notification }

        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let data = try? container.nestedContainer(keyedBy: DataKeys.self, forKey: .data)
            notification = ((try? data?.decodeIfPresent(Wire.self, forKey: .notification)) ?? nil)?.notification
            errors = GraphQLCable.errors(in: container, forKey: .errors)
        }
    }

    /// One `PushNotification`. Its `data` is a JSON object (or, from some
    /// servers, that object as a string); its values are kept as strings.
    private struct Wire: Decodable {
        let notification: InAppNotification?

        enum CodingKeys: String, CodingKey {
            case notificationId, title, body, category, data, sentAt
        }

        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let data = Self.data(in: container)
            let id = ((try? container.decodeIfPresent(Scalar.self, forKey: .notificationId)) ?? nil)?.text
                ?? InAppNotification.notificationID(in: data)

            guard let id, !id.isEmpty else {
                notification = nil
                return
            }

            notification = InAppNotification(
                id: id,
                title: Self.text(in: container, forKey: .title),
                body: Self.text(in: container, forKey: .body),
                category: Self.text(in: container, forKey: .category),
                data: data,
                sentAt: Self.text(in: container, forKey: .sentAt).flatMap(HotMessDecoding.date(from:))
            )
        }

        private static func text(in container: KeyedDecodingContainer<CodingKeys>, forKey key: CodingKeys) -> String? {
            guard let text = (try? container.decodeIfPresent(String.self, forKey: key)) ?? nil,
                  !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            else { return nil }
            return text
        }

        private static func data(in container: KeyedDecodingContainer<CodingKeys>) -> [String: String] {
            if let object = (try? container.decodeIfPresent([String: Scalar].self, forKey: .data)) ?? nil {
                return object.compactMapValues(\.text)
            }
            if let string = (try? container.decodeIfPresent(String.self, forKey: .data)) ?? nil,
               let object = try? JSONDecoder().decode([String: Scalar].self, from: Data(string.utf8)) {
                return object.compactMapValues(\.text)
            }
            return [:]
        }
    }

    /// A JSON string, number or boolean, as text; `nil` for anything else.
    private struct Scalar: Decodable {
        let text: String?

        init(from decoder: any Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let string = try? container.decode(String.self) {
                text = string
            } else if let int = try? container.decode(Int.self) {
                text = String(int)
            } else if let double = try? container.decode(Double.self) {
                text = String(double)
            } else if let bool = try? container.decode(Bool.self) {
                text = String(bool)
            } else {
                text = nil
            }
        }
    }
}

/// The user's notifications while the app is in front: follows
/// `myNotifications`, shows each one as an in-app banner, and tells the
/// notification centre to skip the system copy of one already shown.
///
/// `run()` follows the subscription until its task is cancelled, which the
/// signed-in UI does when the app goes to the background or the user signs out
/// (see `NotificationBannerHost`). A dropped or silent socket reconnects on its
/// own, after a wait that grows with each failure in a row, like chat's.
@MainActor
@Observable
final class NotificationStream {
    /// The notification the banner shows now, if any.
    private(set) var banner: InAppNotification?
    /// The subscription is open, so the in-app copy of a push is on its way.
    var isListening = false

    /// How long the system copy of a notification waits for its in-app copy
    /// while the subscription is open: the two race, and either can be first.
    @ObservationIgnored var systemCopyWindow: Duration = .milliseconds(1500)
    /// Called for every notification shown in the app (Now reloads for a Ping).
    @ObservationIgnored var onReceive: @MainActor (InAppNotification) -> Void = { _ in }

    @ObservationIgnored private var recent = RecentNotificationIDs()
    @ObservationIgnored private let url: URL?
    @ObservationIgnored private let audienceID: @MainActor () async -> String?
    @ObservationIgnored private let token: @MainActor () -> String?

    /// - Parameters:
    ///   - url: the Action Cable endpoint (`AppConfiguration.realtimeURL`).
    ///   - audienceID: the audience the subscription runs in, or `nil` when
    ///     it can't be worked out now.
    ///   - token: the session token, or `nil` when signed out.
    init(
        url: URL?,
        audienceID: @escaping @MainActor () async -> String? = { nil },
        token: @escaping @MainActor () -> String? = { nil }
    ) {
        self.url = url
        self.audienceID = audienceID
        self.token = token
    }

    /// Follows `myNotifications` until cancelled, or until the server refuses it.
    func run() async {
        guard let url else { return }

        var failures = 0
        while !Task.isCancelled {
            switch await follow(url: url) {
            case .stopped, .refused:
                return
            case .listened:
                failures = 0
            case .dropped:
                failures += 1
            }

            do {
                try await Task.sleep(for: VenueChatViewModel.reconnectDelay(afterFailures: failures))
            } catch {
                return
            }
        }
    }

    /// Shows a notification that came over the subscription, unless it was
    /// already shown (as a system banner, or over an earlier socket).
    func receive(_ notification: InAppNotification) {
        guard recent.insert(notification.id) else { return }

        banner = notification
        onReceive(notification)
    }

    /// Hides the banner, if it still shows that notification.
    func dismiss(_ id: InAppNotification.ID) {
        if banner?.id == id { banner = nil }
    }

    /// Forgets what was shown, on signing out.
    func reset() {
        banner = nil
        recent.removeAll()
    }

    /// Whether the system should show a push that arrived in the foreground:
    /// not if its in-app copy was shown, or arrives within `systemCopyWindow`
    /// while the subscription is open. Otherwise it's shown, and remembered so
    /// a late in-app copy isn't shown again. A push without an ID (from an
    /// older server) is always shown.
    func shouldPresentSystemCopy(notificationID id: String?) async -> Bool {
        guard let id else { return true }
        if recent.contains(id) { return false }

        if isListening {
            let deadline = ContinuousClock.now + systemCopyWindow
            while ContinuousClock.now < deadline {
                do {
                    try await Task.sleep(for: .milliseconds(100))
                } catch {
                    break
                }
                if recent.contains(id) { return false }
            }
        }

        recent.insert(id)
        return true
    }

    // MARK: - Private

    private enum Outcome {
        case stopped
        case refused
        /// The socket closed after the subscription went out.
        case listened
        /// The socket closed before it did.
        case dropped
    }

    /// One socket's life.
    private func follow(url: URL) async -> Outcome {
        guard let token = token() else { return .stopped }
        guard let audienceID = await audienceID() else { return .dropped }
        guard !Task.isCancelled else { return .stopped }

        let socket = NotificationStreamConnection.socket(url: url, token: token, audienceID: audienceID)
        await socket.connect()

        var outcome = Outcome.stopped
        var listened = false
        loop: for await event in socket.events {
            guard !Task.isCancelled else { break }

            switch event {
            case .listening:
                listened = true
                isListening = true
            case let .received(notification):
                receive(notification)
            case .refused:
                outcome = .refused
                break loop
            case .disconnected:
                outcome = listened ? .listened : .dropped
                break loop
            }
        }

        isListening = false
        await socket.disconnect()
        return Task.isCancelled ? .stopped : outcome
    }
}
