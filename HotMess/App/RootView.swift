//
//  RootView.swift
//  HotMess
//

import SwiftUI

/// Chooses between the launch, login, update-required and signed-in states.
struct RootView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Group {
            if model.session.requiresUpdate {
                UpdateRequiredView(versionInfo: model.session.versionRequirement)
            } else {
                switch model.session.state {
                case .restoring:
                    LaunchView()
                case .signedOut, .signingIn, .failed:
                    LoginScreen()
                case .signedIn:
                    MainTabView()
                }
            }
        }
        .animation(.default, value: model.session.state)
    }
}

/// Shown while the stored session is being checked, so the app doesn't flash
/// the login screen on every cold start.
struct LaunchView: View {
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 24) {
                Image("Overlay")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 240)

                ProgressView()
                    .tint(.white)
            }
        }
    }
}

struct MainTabView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model

        TabView(selection: $model.selectedTab) {
            Tab(AppTab.now.title, systemImage: AppTab.now.systemImage, value: AppTab.now) {
                NavigationStack(path: $model.nowPath) {
                    NowScreen()
                        .navigationDestination(for: AppRoute.self) { RouteDestination(route: $0) }
                }
            }

            Tab(AppTab.events.title, systemImage: AppTab.events.systemImage, value: AppTab.events) {
                NavigationStack(path: $model.eventsPath) {
                    EventsScreen()
                        .navigationDestination(for: AppRoute.self) { RouteDestination(route: $0) }
                }
            }

            Tab(AppTab.venues.title, systemImage: AppTab.venues.systemImage, value: AppTab.venues) {
                NavigationStack(path: $model.venuesPath) {
                    VenuesScreen()
                        .navigationDestination(for: AppRoute.self) { RouteDestination(route: $0) }
                }
            }

            Tab(AppTab.people.title, systemImage: AppTab.people.systemImage, value: AppTab.people) {
                NavigationStack(path: $model.peoplePath) {
                    PeopleScreen()
                        .navigationDestination(for: AppRoute.self) { RouteDestination(route: $0) }
                }
            }

            Tab(AppTab.me.title, systemImage: AppTab.me.systemImage, value: AppTab.me) {
                NavigationStack {
                    SettingsScreen()
                }
            }
        }
    }
}

/// Maps a route onto the screen that shows it, so every stack pushes the same
/// destinations.
struct RouteDestination: View {
    let route: AppRoute

    var body: some View {
        switch route {
        case let .venue(id):
            VenueScreen(venueID: id)
        case let .event(id):
            EventScreen(eventID: id)
        case let .person(id):
            PersonScreen(personID: id)
        case let .venueChat(venue):
            VenueChatScreen(venue: venue)
        }
    }
}

/// The hard stop the API can impose on old builds.
struct UpdateRequiredView: View {
    let versionInfo: VersionInfo?

    @Environment(AppModel.self) private var model

    var body: some View {
        ContentUnavailableView {
            Label(String(localized: "Update Required"), systemImage: "arrow.down.circle")
        } description: {
            Text(description)
        }
    }

    private var description: String {
        let source = model.configuration.isTestFlight
            ? String(localized: "TestFlight")
            : String(localized: "the App Store")

        guard let versionInfo else {
            return String(localized: "Update Hot Mess in \(source) to continue.")
        }

        return String(localized: "Update to version \(versionInfo.minimumVersion) in \(source) to continue.")
    }
}
