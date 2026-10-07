//
//  PushNotifications.swift
//  HotMess
//

import Foundation
import UIKit
import UserNotifications

/// What a push says about a Ping, read from its payload: top-level `kind`
/// and `ping_id` next to `aps`.
struct PingNotification: Equatable, Sendable {
    enum Kind: String, Sendable {
        /// A friend sent a Ping (category `PING`).
        case ping
        /// Someone is in on the user's own Ping.
        case pingJoin = "ping_join"
    }

    /// The notification category of a `ping` push.
    static let category = "PING"
    /// The category's one action, "I'm in", which joins in the background.
    static let joinAction = "PING_JOIN"

    let kind: Kind
    let pingID: String?

    init(kind: Kind, pingID: String?) {
        self.kind = kind
        self.pingID = pingID
    }

    init?(userInfo: [AnyHashable: Any]) {
        guard let raw = userInfo["kind"] as? String, let kind = Kind(rawValue: raw) else { return nil }
        self.kind = kind

        switch userInfo["ping_id"] {
        case let id as String where !id.isEmpty: pingID = id
        case let id as NSNumber: pingID = id.stringValue
        default: pingID = nil
        }
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
