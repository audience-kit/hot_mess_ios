//
//  PersonScreen.swift
//  HotMess
//

import SwiftUI

/// Person detail, replacing `PersonViewController`.
struct PersonScreen: View {
    let personID: UUID

    @Environment(AppModel.self) private var model
    @State private var viewModel: PersonViewModel?

    var body: some View {
        LoadStateView(state: viewModel?.state ?? .loading, retry: reload) { detail in
            List {
                Section {
                    header(detail.person)
                        .listRowInsets(EdgeInsets())
                }

                if !detail.socialLinks.isEmpty {
                    Section(String(localized: "Elsewhere")) {
                        ForEach(detail.socialLinks) { link in
                            socialLinkRow(link)
                        }
                    }
                }

                Section(String(localized: "Events")) {
                    if detail.events.isEmpty {
                        Text("No upcoming events.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(detail.events) { event in
                            NavigationLink(value: AppRoute.event(event.id)) {
                                EventRow(event: event)
                            }
                        }
                    }
                }

                if !detail.tracks.isEmpty {
                    Section {
                        ForEach(detail.tracks) { track in
                            trackRow(track)
                        }
                    } footer: {
                        Image("PoweredBySoundCloud")
                            .resizable()
                            .scaledToFit()
                            .frame(height: 20)
                            .accessibilityLabel(String(localized: "Powered by SoundCloud"))
                    }
                }
            }
            .listStyle(.insetGrouped)
        }
        .navigationTitle(viewModel?.state.value?.name ?? String(localized: "Person"))
        .navigationBarTitleDisplayMode(.inline)
        .task {
            ensureViewModel()
            await viewModel?.load()
        }
    }

    // MARK: - Pieces

    private func header(_ person: Person) -> some View {
        ZStack(alignment: .bottomLeading) {
            RemoteImage(url: person.coverURL)
                .frame(height: 180)

            HStack(alignment: .bottom, spacing: 12) {
                Avatar(
                    url: person.pictureURL,
                    initials: person.name.initialsForDisplay,
                    size: 84
                )
                .overlay { Circle().strokeBorder(.white, lineWidth: 4) }

                VStack(alignment: .leading, spacing: 2) {
                    Text(person.name)
                        .font(.hotMess(.title3, semibold: true))

                    if let role = person.role, !role.isEmpty {
                        Text(role)
                            .font(.hotMess(.subheadline))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.bottom, 8)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, -28)
        }
        .padding(.bottom, 36)
    }

    @ViewBuilder
    private func socialLinkRow(_ link: SocialLink) -> some View {
        if let url = link.url {
            Link(destination: url) {
                HStack(spacing: 12) {
                    socialIcon(link)
                    Text(verbatim: "/\(link.handle)")
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.footnote)
                        .foregroundStyle(.tertiary)
                }
            }
        } else {
            HStack(spacing: 12) {
                socialIcon(link)
                Text(verbatim: "/\(link.handle)")
            }
        }
    }

    @ViewBuilder
    private func socialIcon(_ link: SocialLink) -> some View {
        if let assetName = link.assetName {
            Image(assetName)
                .resizable()
                .scaledToFit()
                .frame(width: 24, height: 24)
                .clipShape(.rect(cornerRadius: 4))
        } else {
            Image(systemName: "link")
                .frame(width: 24, height: 24)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func trackRow(_ track: Track) -> some View {
        if let url = track.providerURL {
            Link(destination: url) {
                TrackRow(track: track)
            }
            .buttonStyle(.plain)
        } else {
            TrackRow(track: track)
        }
    }

    private func ensureViewModel() {
        if viewModel == nil {
            viewModel = PersonViewModel(api: model.api, personID: personID)
        }
    }

    private func reload() {
        Task {
            ensureViewModel()
            await viewModel?.load()
        }
    }
}
