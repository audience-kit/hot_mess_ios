//
//  AppDelegate.swift
//  HotMess
//

import FacebookCore
import Foundation
import os
import UIKit

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
