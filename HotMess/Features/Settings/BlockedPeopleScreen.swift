//
//  BlockedPeopleScreen.swift
//  HotMess
//

import SwiftUI

/// People the user blocked in chat, each with Unblock.
struct BlockedPeopleScreen: View {
    @Environment(AppModel.self) private var model

    @State private var failed = false

    var body: some View {
        List {
            if model.safety.blockedUsers.isEmpty {
                ContentUnavailableView {
                    Label(String(localized: "No one blocked"), systemImage: "hand.raised")
                } description: {
                    Text("Press and hold someone's message in chat to block them. You won't see their messages in any room, and they aren't told.")
                }
                .listRowBackground(Color.clear)
            } else {
                Section {
                    ForEach(model.safety.blockedUsers) { user in
                        HStack(spacing: 12) {
                            Avatar(url: user.avatarURL, initials: initials(user), size: 36)
                            Text(user.name ?? String(localized: "Someone"))
                                .font(.hotMess(.body))
                            Spacer()
                            Button(String(localized: "Unblock")) {
                                Task { await unblock(user) }
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                } footer: {
                    Text("You won’t see blocked people in chat. They aren’t told when you block or unblock them.")
                }
            }
        }
        .navigationTitle(String(localized: "Blocked People"))
        .task { await model.safety.load(force: true) }
        .alert(String(localized: "Couldn't unblock them"), isPresented: $failed) {
            Button(String(localized: "OK"), role: .cancel) {}
        }
    }

    private func initials(_ user: BlockedUser) -> String? {
        user.name?.split(separator: " ").compactMap(\.first).prefix(2).map(String.init).joined()
    }

    private func unblock(_ user: BlockedUser) async {
        do {
            try await model.safety.unblock(user.id)
        } catch {
            failed = true
        }
    }
}
