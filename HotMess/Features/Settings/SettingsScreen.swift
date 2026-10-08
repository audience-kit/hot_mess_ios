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
    @State private var isConfirmingDelete = false
    @State private var isDeleting = false
    @State private var deleteFailed = false
    /// Venues whose door the user can work; Door mode shows only when there are some.
    @State private var doorVenues: [DoorVenue] = []

    var body: some View {
        List {
            profileSection
            facebookSection
            coverSection
            locationSection
            privacySection
            feedbackSection
            aboutSection
            dangerSection
            deleteSection
        }
        .listStyle(.insetGrouped)
        .navigationTitle(String(localized: "Me"))
        .task { await model.session.refreshUser() }
        .task { await loadDoorVenues() }
        .task { await model.safety.load() }
        .confirmationDialog(
            String(localized: "Sign out of Hot Mess?"),
            isPresented: $isConfirmingSignOut,
            titleVisibility: .visible
        ) {
            Button(String(localized: "Sign Out"), role: .destructive) {
                model.signOut()
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
        .alert(String(localized: "Delete your account?"), isPresented: $isConfirmingDelete) {
            Button(String(localized: "Delete Account"), role: .destructive) {
                Task { await deleteAccount() }
            }
            Button(String(localized: "Cancel"), role: .cancel) {}
        } message: {
            Text("This permanently deletes your Hot Mess account, your messages, RSVPs, Pings and friends list, and signs you out. Cover passes you bought stay with the venue. It can't be undone.")
        }
        .alert(String(localized: "Couldn't delete your account"), isPresented: $deleteFailed) {
            Button(String(localized: "OK"), role: .cancel) {}
        } message: {
            Text("Please try again, or email feedback@hotmess.social and we'll delete it for you.")
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
                        .font(.hotMess(.headline, semibold: true))

                    if let locale = model.location.locale {
                        Text(locale.name)
                            .font(.hotMess(.subheadline))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    /// For an account that signed in with Apple and hasn't connected Facebook.
    @ViewBuilder
    private var facebookSection: some View {
        if !model.safety.hasFacebook {
            Section {
                ConnectFacebookButton()
            } footer: {
                ConnectFacebookFooter()
            }
        }
    }

    private var coverSection: some View {
        Section {
            NavigationLink {
                PassesScreen()
            } label: {
                Label(String(localized: "Passes"), systemImage: "ticket")
            }
            .accessibilityIdentifier("me.passes")

            if !doorVenues.isEmpty {
                NavigationLink {
                    DoorScreen(venues: doorVenues)
                } label: {
                    Label(String(localized: "Door"), systemImage: "qrcode.viewfinder")
                }
                .accessibilityIdentifier("me.door")
            }
        } footer: {
            if !doorVenues.isEmpty {
                Text("Scan cover passes at \(doorVenues.map(\.name).formatted(.list(type: .and))).")
            }
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

    private var privacySection: some View {
        Section(String(localized: "Privacy & Safety")) {
            NavigationLink {
                BlockedPeopleScreen()
            } label: {
                Label(String(localized: "Blocked People"), systemImage: "hand.raised")
            }
            .accessibilityIdentifier("me.blocked")

            Link(destination: LegalLinks.privacy) {
                Label(String(localized: "Privacy Policy"), systemImage: "hand.raised.square")
            }

            Link(destination: LegalLinks.terms) {
                Label(String(localized: "Terms of Use"), systemImage: "doc.text")
            }
        }
    }

    private var feedbackSection: some View {
        Section {
            NavigationLink {
                ReportProblemScreen()
            } label: {
                Label(String(localized: "Report a Problem"), systemImage: "exclamationmark.bubble")
            }
            .accessibilityIdentifier("me.reportProblem")

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

    private var deleteSection: some View {
        Section {
            Button(role: .destructive) {
                isConfirmingDelete = true
            } label: {
                if isDeleting {
                    HStack {
                        Text("Deleting Account…")
                        Spacer()
                        ProgressView()
                    }
                } else {
                    Text("Delete Account")
                }
            }
            .disabled(isDeleting)
            .accessibilityIdentifier("me.deleteAccount")
        } footer: {
            Text("Deletes your account and everything Hot Mess keeps about you.")
        }
    }

    // MARK: - Helpers

    private func deleteAccount() async {
        isDeleting = true
        defer { isDeleting = false }

        do {
            try await model.deleteAccount()
        } catch {
            deleteFailed = true
        }
    }

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

    private func loadDoorVenues() async {
        do {
            doorVenues = try await model.api.doorVenues()
        } catch {
            // Door mode stays hidden; it's only for venue staff.
        }
    }

    private func resetLocalData() {
        model.session.resetLocalData()
        ImageCache.default.clearMemoryCache()
        ImageCache.default.clearDiskCache()
        didReset = true
    }
}
