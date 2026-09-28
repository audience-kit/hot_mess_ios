//
//  SettingsScreen.swift
//  HotMess
//

import Kingfisher
import SwiftUI
import UIKit

/// The "Me" tab, replacing `SettingsViewController` — which built its rows from
/// nested `indexPath` switches and masked a Facebook profile view with a
/// `CAShapeLayer` sized from a frame that hadn't been laid out yet.
struct SettingsScreen: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openURL) private var openURL

    @State private var isConfirmingSignOut = false
    @State private var isConfirmingReset = false
    @State private var didReset = false

    var body: some View {
        List {
            profileSection
            locationSection
            feedbackSection
            aboutSection
            dangerSection
        }
        .listStyle(.insetGrouped)
        .navigationTitle(String(localized: "Me"))
        .task { await model.session.refreshUser() }
        .confirmationDialog(
            String(localized: "Sign out of Hot Mess?"),
            isPresented: $isConfirmingSignOut,
            titleVisibility: .visible
        ) {
            Button(String(localized: "Sign Out"), role: .destructive) {
                model.session.signOut()
            }
        }
        .confirmationDialog(
            String(localized: "Reset all local data?"),
            isPresented: $isConfirmingReset,
            titleVisibility: .visible
        ) {
            Button(String(localized: "Reset"), role: .destructive, action: resetLocalData)
        } message: {
            Text("This clears cached images and preferences. You stay signed in.")
        }
        .alert(String(localized: "Local Data Cleared"), isPresented: $didReset) {
            Button(String(localized: "OK"), role: .cancel) {}
        }
    }

    // MARK: - Sections

    private var profileSection: some View {
        Section {
            HStack(spacing: 16) {
                Avatar(
                    url: model.session.userID.map(model.configuration.avatarURL(forUserID:)),
                    initials: model.session.user?.initials,
                    size: 64
                )

                VStack(alignment: .leading, spacing: 4) {
                    Text(model.session.user?.name ?? String(localized: "Signed in"))
                        .font(.headline)

                    if let locale = model.location.locale {
                        Text(locale.name)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    @ViewBuilder
    private var locationSection: some View {
        Section(String(localized: "Location")) {
            InfoRow(
                title: String(localized: "Access"),
                value: locationStatusText,
                systemImage: "location"
            )

            if model.location.isDenied {
                Button(String(localized: "Open Settings")) {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        openURL(url)
                    }
                }
            }
        }
    }

    private var feedbackSection: some View {
        Section {
            if let url = feedbackURL {
                Link(destination: url) {
                    Label(String(localized: "Submit Feedback"), systemImage: "envelope")
                }
            }
        }
    }

    private var aboutSection: some View {
        Section(String(localized: "About")) {
            InfoRow(
                title: String(localized: "Version"),
                value: "\(model.configuration.version) (\(model.configuration.build))"
            )
            InfoRow(
                title: String(localized: "Facebook"),
                value: model.configuration.facebookEnvironment
            )
            InfoRow(
                title: String(localized: "Server"),
                value: model.configuration.baseURL.absoluteString
            )
        }
    }

    private var dangerSection: some View {
        Section {
            Button(String(localized: "Reset All Data"), role: .destructive) {
                isConfirmingReset = true
            }

            Button(String(localized: "Sign Out"), role: .destructive) {
                isConfirmingSignOut = true
            }
        }
    }

    // MARK: - Helpers

    private var locationStatusText: String {
        if model.location.isAuthorized { return String(localized: "Allowed") }
        if model.location.isDenied { return String(localized: "Denied") }
        return String(localized: "Not requested")
    }

    /// A `mailto:` link works with whatever mail client the user actually has;
    /// `MFMailComposeViewController` only handles Apple Mail.
    private var feedbackURL: URL? {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = "feedback@hotmess.social"
        components.queryItems = [
            URLQueryItem(name: "subject", value: "Hot Mess: Feedback"),
            URLQueryItem(
                name: "body",
                value: "\n\n---\nVersion \(model.configuration.version) (\(model.configuration.build))"
            ),
        ]

        return components.url
    }

    private func resetLocalData() {
        model.session.resetLocalData()
        ImageCache.default.clearMemoryCache()
        ImageCache.default.clearDiskCache()
        didReset = true
    }
}
