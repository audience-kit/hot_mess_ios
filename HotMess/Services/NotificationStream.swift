//
//  NotificationStream.swift
//  HotMess
//

import AudienceKit
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
    /// What the push payload carries next to `aps` (`url`, `kind`, `ping_id`,
    /// `notification_id`), each value as a string.
    let data: [String: String]
    let sentAt: Date?
    /// The route to open for it, the same `url` the push carries; `nil` when
    /// it leads nowhere in particular.
    let url: URL?

    init(id: String, title: String?, body: String?, category: String?, data: [String: String], sentAt: Date?,
         url: URL? = nil) {
        self.id = id
        self.title = title
        self.body = body
        self.category = category
        self.data = data
        self.sentAt = sentAt
        self.url = url ?? data["url"].flatMap(URL.init(string:))
    }

    /// What to act on, read the way a push's payload is, with the typed `url`
    /// standing in when `data` has none.
    var ping: PingNotification? {
        var userInfo: [AnyHashable: Any] = data
        if userInfo["url"] == nil, let url { userInfo["url"] = url.absoluteString }
        return PingNotification(userInfo: userInfo)
    }

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

/// `Subscription.myNotifications` on the app's cable: the document, and
/// what its events mean.
enum NotificationStreamConnection {
    enum Event: Sendable, Equatable {
        /// The subscription went out: notifications arrive from now on. (The
        /// server sends nothing on subscribing.)
        case listening
        case received(InAppNotification)
        /// The server turned the subscription away (a build without the
        /// permission, a server without the field). Retrying won't help.
        case refused
        /// The socket dropped or went quiet; the cable subscribes again on its
        /// own unless `reconnects` is false (the session ended).
        case disconnected(String?, reconnects: Bool)
    }

    static let operationName = "MyNotifications"

    static let document = """
    subscription MyNotifications {
      notification: myNotifications { notificationId title body category data sentAt url }
    }
    """

    /// The events one of the cable's events means.
    static func events(from event: AudienceCable.Event) -> [Event] {
        switch event {
        case .subscribed:
            [.listening]
        case let .result(data):
            events(fromResult: data)
        case .rejected:
            [.refused]
        case let .disconnected(reason, reconnects):
            [.disconnected(reason, reconnects: reconnects)]
        }
    }

    /// What one `{ data, errors }` result means: the notification, a refusal,
    /// or nothing (one without an ID, which can't be deduped).
    static func events(fromResult data: Data) -> [Event] {
        guard let result = try? JSONDecoder().decode(Result.self, from: data) else { return [] }
        if let notification = result.notification {
            return [.received(notification)]
        }
        if !result.errors.isEmpty {
            Log.realtime.error("Notifications subscription refused: \(result.errors.joined(separator: "; "), privacy: .public)")
            return [.refused]
        }
        return []
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
            case notificationId, title, body, category, data, sentAt, url
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
                sentAt: Self.text(in: container, forKey: .sentAt).flatMap(HotMessDecoding.date(from:)),
                url: Self.text(in: container, forKey: .url).flatMap(URL.init(string:))
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
/// `run()` follows the subscription on the app's one cable until its task is
/// cancelled, which the signed-in UI does when the app goes to the background
/// or the user signs out (see `NotificationBannerHost`); with chat's rooms it's
/// what keeps the cable open. A dropped or silent socket is the cable's to
/// reconnect, and it subscribes this again when it does.
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
    @ObservationIgnored private let cable: AudienceCable?
    @ObservationIgnored private let audienceID: @MainActor () async -> String?
    @ObservationIgnored private let isSignedIn: @MainActor () -> Bool

    /// - Parameters:
    ///   - cable: the app's one cable (`AppModel.cable`).
    ///   - audienceID: the audience the subscription runs in, or `nil` when
    ///     it can't be worked out now.
    ///   - isSignedIn: whether there's a session to follow it with.
    init(
        cable: AudienceCable?,
        audienceID: @escaping @MainActor () async -> String? = { nil },
        isSignedIn: @escaping @MainActor () -> Bool = { false }
    ) {
        self.cable = cable
        self.audienceID = audienceID
        self.isSignedIn = isSignedIn
    }

    /// Follows `myNotifications` until cancelled, signed out, or refused.
    /// The cable reconnects a dropped socket itself; this only subscribes
    /// again when the server ends the subscription, or the audience couldn't
    /// be worked out.
    func run() async {
        guard let cable else { return }

        var failures = 0
        while !Task.isCancelled {
            switch await follow(cable: cable) {
            case .stopped, .refused:
                return
            case .listened:
                failures = 0
            case .dropped:
                failures += 1
            }

            do {
                try await Task.sleep(for: AudienceCable.reconnectDelay(afterFailures: failures))
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
        /// The server ended the subscription after it went out.
        case listened
        /// It ended before it went out.
        case dropped
    }

    /// One subscription's life on the cable. Ending the loop (cancelled,
    /// refused) ends the subscription, and the cable closes its socket once
    /// nothing else is on it.
    private func follow(cable: AudienceCable) async -> Outcome {
        guard isSignedIn() else { return .stopped }
        guard let audienceID = await audienceID() else { return .dropped }
        guard !Task.isCancelled else { return .stopped }

        let subscription = await cable.subscribe(
            query: NotificationStreamConnection.document,
            operationName: NotificationStreamConnection.operationName,
            audienceID: audienceID
        )

        var outcome = Outcome.dropped
        var listened = false
        loop: for await cableEvent in subscription {
            guard !Task.isCancelled else { break }

            for event in NotificationStreamConnection.events(from: cableEvent) {
                switch event {
                case .listening:
                    listened = true
                    isListening = true
                case let .received(notification):
                    receive(notification)
                case .refused:
                    outcome = .refused
                    break loop
                case let .disconnected(_, reconnects):
                    isListening = false
                    if !reconnects {
                        outcome = .stopped
                        break loop
                    }
                }
            }
        }

        isListening = false
        if Task.isCancelled { return .stopped }
        if outcome == .dropped, listened { return .listened }
        return outcome
    }
}
