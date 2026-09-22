//
//  HotMessApp.swift
//  HotMess
//

import FacebookCore
import SwiftUI
import UIKit

@main
@MainActor
struct HotMessApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var model = AppModel.shared
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .tint(.hotMessAccent)
                .task { await model.start() }
                .onOpenURL(perform: handle)
                .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
                    guard let url = activity.webpageURL else { return }
                    _ = model.open(url)
                }
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                if model.session.isSignedIn { model.location.start() }
            case .background:
                model.location.stop()
            default:
                break
            }
        }
    }

    /// Facebook gets first refusal on an incoming URL — its login flow comes
    /// back through `fb<app-id>://` — and anything it doesn't claim is treated
    /// as one of our own `hotmess://` links.
    private func handle(_ url: URL) {
        let handledByFacebook = ApplicationDelegate.shared.application(
            UIApplication.shared,
            open: url,
            sourceApplication: nil,
            annotation: nil
        )

        guard !handledByFacebook else { return }

        _ = model.open(url)
    }
}
