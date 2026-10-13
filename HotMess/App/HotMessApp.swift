//
//  HotMessApp.swift
//  HotMess
//

import FacebookCore
@preconcurrency import StripePaymentSheet
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
            Group {
#if DEBUG
                if let fixture = ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix("-HotMessUITestKaraoke=") }) {
                    KaraokeUITestScreen(mode: String(fixture.split(separator: "=").last ?? "venue"))
                } else { RootView() }
#else
                RootView()
#endif
            }
                .environment(model)
                .tint(model.brand.accent)
                .task { await start() }
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

    private func start() async {
#if DEBUG
        if ProcessInfo.processInfo.arguments.contains(where: { $0.hasPrefix("-HotMessUITestKaraoke=") }) { return }
#endif
        await model.start()
    }

    /// Stripe claims its bank redirects (`hotmess://stripe-redirect`), then a
    /// sign-in waiting on the Facebook app takes its `fb<app-id>://` redirect,
    /// then the Facebook SDK gets refusal (its own login comes back the same
    /// way), and anything none claims is treated as one of our own
    /// `hotmess://` links.
    private func handle(_ url: URL) {
        if StripeAPI.handleURLCallback(with: url) { return }
        if FacebookSignIn.handle(url) { return }

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
