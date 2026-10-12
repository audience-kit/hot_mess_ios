//
//  PushNotifications.swift
//  HotMess
//

import Foundation
import UIKit
import UserNotifications

/// What a push carries for the app to act on, read from its payload next to
/// `aps`: `url`, the route to open (a universal link on the audience's web
/// origin, such as `https://hotmess.social/pings/<id>`), and `ping_id` for
/// the "I'm in" action. The payload's `kind` is for analytics only; the app
/// never branches on it.
struct PingNotification: Equatable, Sendable {
    /// The notification category of a Ping push, which carries "I'm in".
    static let category = "PING"
    /// The category's one action, "I'm in", which joins in the background.
    static let joinAction = "PING_JOIN"

    /// Where the notification leads. `nil` when the payload has no route.
    let url: URL?
    let pingID: String?

    init(url: URL? = nil, pingID: String?) {
        self.url = url
        self.pingID = pingID
    }

    /// `nil` when the payload has neither a route nor a Ping.
    init?(userInfo: [AnyHashable: Any]) {
        let url = (userInfo["url"] as? String).flatMap(URL.init(string:))

        let pingID: String?
        switch userInfo["ping_id"] {
        case let id as String where !id.isEmpty: pingID = id
        case let id as NSNumber: pingID = id.stringValue
        default: pingID = nil
        }

        guard url != nil || pingID != nil else { return nil }
        self.url = url
        self.pingID = pingID
    }

    /// Whether it is about a Ping (one was sent, or joined), so Now reloads.
    var isPing: Bool {
        pingID != nil || DeepLink.destination(for: url) == .now
    }
}

/// Push permission, registration and the Ping notification category.
@MainActor
enum PushNotifications {
    /// The `PING` category with its "I'm in" action. The action has no
    /// options, so it runs in the background without opening the app.
    static func registerCategories() {
        let join = UNNotificationAction(
            identifier: PingNotification.joinAction,
            title: String(localized: "I'm in"),
            options: []
        )
        let category = UNNotificationCategory(
            identifier: PingNotification.category,
            actions: [join],
            intentIdentifiers: [],
            options: []
        )
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }

    /// Asks to show alerts (the system only asks once) and registers with
    /// APNs, which hands the token to `AppDelegate`.
    static func requestAuthorizationAndRegister() async {
        let granted = await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
                if let error {
                    Log.app.error("Notification authorization failed: \(error.localizedDescription, privacy: .public)")
                }
                continuation.resume(returning: granted)
            }
        }
        Log.app.info("Notification authorization granted: \(granted, privacy: .public)")

        UIApplication.shared.registerForRemoteNotifications()
    }
}
