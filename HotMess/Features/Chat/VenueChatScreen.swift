//
//  VenueChatScreen.swift
//  HotMess
//

import SwiftUI
import UIKit

/// A venue's chat room, replacing `VenueConversationViewController` and the
/// 1,300-line `OldVenueConversationViewController` beside it. Both were built
/// around a collection view whose cells were commented out, and the working one
/// dequeued a cell with an empty reuse identifier — a guaranteed crash the
/// moment a message arrived.
struct VenueChatScreen: View {
    let venue: Venue

    @Environment(AppModel.self) private var model
    @State private var viewModel: VenueChatViewModel?

    var body: some View {
        VStack(spacing: 0) {
            if let viewModel, viewModel.connectionState == .notPresent {
                notPresent(viewModel)
            } else if let viewModel {
                if let kind = bannerKind(viewModel) {
                    RoomBanner(kind: kind, roomName: venue.name)
                }
                ChatThreadView(messages: threadMessages(viewModel), roomName: venue.name)
                composer(viewModel)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(venue.name)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            let viewModel = makeViewModel()
            self.viewModel = viewModel
            await viewModel.run()
        }
        .onDisappear {
            let viewModel = self.viewModel
            Task { await viewModel?.stop() }
        }
    }

    // MARK: - Pieces

    /// The server only lets people at the venue into its room.
    private func notPresent(_ viewModel: VenueChatViewModel) -> some View {
        ContentUnavailableView {
            Label(String(localized: "Only for people at \(venue.name)"), systemImage: "location.slash")
        } description: {
            Text("The room opens when you're there. Your location has to be on so Hot Mess can tell.")
        } actions: {
            Button(String(localized: "Try again")) {
                Task { await viewModel.retry() }
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// Admins can join from anywhere; say when they couldn't have otherwise.
    /// That wins over the connection strip.
    private func bannerKind(_ viewModel: VenueChatViewModel) -> RoomBanner.Kind? {
        if viewModel.isOutOfRange { return .range }

        switch viewModel.connectionState {
        case .connecting: return .connecting
        case let .disconnected(reason): return .offline(reason)
        case .connected, .notPresent: return nil
        }
    }

    private func threadMessages(_ viewModel: VenueChatViewModel) -> [ChatThreadMessage] {
        viewModel.messages.map { message in
            ChatThreadMessage(
                id: message.id.uuidString,
                authorID: message.userID.uuidString,
                authorName: message.name,
                avatarURL: message.avatarURL,
                text: message.body,
                sentAt: message.sentAt,
                isOwn: viewModel.isOutgoing(message)
            )
        }
    }

    private func composer(_ viewModel: VenueChatViewModel) -> some View {
        @Bindable var viewModel = viewModel

        return ChatComposer(text: $viewModel.draft, canSend: viewModel.canSend) {
            Task { await viewModel.send() }
        }
    }

    private func makeViewModel() -> VenueChatViewModel {
        if let viewModel { return viewModel }

        return VenueChatViewModel(
            venue: venue,
            configuration: model.configuration,
            userID: model.session.userID,
            token: model.session.bearerToken,
            reportPresence: { [location = model.location] in await location.reportCurrentPosition() }
        )
    }
}
