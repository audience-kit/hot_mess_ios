//
//  AppDelegate.swift
//  HotMess
//

import FacebookCore
import Foundation
import os
import UIKit
import UserNotifications

/// What is genuinely left for UIKit to do: boot the Facebook SDK and receive
/// push tokens. Everything the old 160-line delegate did — deep links, version
/// gating, login presentation, location start/stop — now lives in SwiftUI or in
/// a service.
@MainActor
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        ApplicationDelegate.shared.application(
            application,
            didFinishLaunchingWithOptions: launchOptions
        )

        // Set before launch finishes, so a tap or an action that launched
        // the app is delivered here.
        UNUserNotificationCenter.current().delegate = self
        PushNotifications.registerCategories()

        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        let session = AppModel.shared.session

        Task { await session.registerForPushNotifications(deviceToken: deviceToken) }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: any Error
    ) {
        Log.app.error("Remote notification registration failed: \(error.localizedDescription, privacy: .public)")
    }
}

// MARK: - Notifications

extension AppDelegate: UNUserNotificationCenterDelegate {
    /// Pings show as banners in the foreground too, and Now picks up the change.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        if PingNotification(userInfo: notification.request.content.userInfo) != nil {
            await AppDelegate.pingsChanged()
        }
        return [.banner, .list, .sound]
    }

    /// "I'm in" from a `ping` push joins the whole Ping in the background;
    /// tapping a `ping` or `ping_join` push opens Now.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let action = response.actionIdentifier
        guard let notification = PingNotification(userInfo: response.notification.request.content.userInfo) else {
            return
        }

        if action == PingNotification.joinAction {
            await AppDelegate.join(notification)
        } else if action == UNNotificationDefaultActionIdentifier {
            await AppDelegate.openNow()
        }
    }

    @MainActor
    private static func join(_ notification: PingNotification) async {
        guard let pingID = notification.pingID else { return }
        let model = AppModel.shared

        do {
            _ = try await model.api.joinPing(pingID)
        } catch {
            Log.app.error("Joining a ping from a notification failed: \(error.localizedDescription, privacy: .public)")
        }
        model.pingsChanged()
    }

    @MainActor
    private static func openNow() {
        AppModel.shared.openNow()
    }

    @MainActor
    private static func pingsChanged() {
        AppModel.shared.pingsChanged()
    }
}
