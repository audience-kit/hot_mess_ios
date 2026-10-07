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
///
/// It also serves a locale's room, for people out in the locale who aren't at
/// a venue.
struct VenueChatScreen: View {
    let room: ChatRoom

    init(room: ChatRoom) {
        self.room = room
    }

    init(venue: Venue) {
        room = .venue(venue)
    }

    @Environment(AppModel.self) private var model
    @State private var viewModel: VenueChatViewModel?

    var body: some View {
        VStack(spacing: 0) {
            if let viewModel, viewModel.connectionState == .notPresent {
                notPresent(viewModel)
            } else if let viewModel {
                if let kind = bannerKind(viewModel) {
                    RoomBanner(kind: kind, roomName: room.name, isLocale: room.kind == .locale)
                }
                ChatThreadView(messages: threadMessages(viewModel), roomName: room.name) { id in
                    guard let id = UUID(uuidString: id) else { return }
                    Task { await viewModel.resend(id) }
                }
                composer(viewModel)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(room.name)
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

    /// The server only lets people at the venue (or out in the locale) into its room.
    private func notPresent(_ viewModel: VenueChatViewModel) -> some View {
        ContentUnavailableView {
            switch room.kind {
            case .venue:
                Label(String(localized: "Only for people at \(room.name)"), systemImage: "location.slash")
            case .locale:
                Label(String(localized: "Only for people out in \(room.name)"), systemImage: "location.slash")
            }
        } description: {
            switch room.kind {
            case .venue:
                Text("The room opens when you're there. Your location has to be on so Hot Mess can tell.")
            case .locale:
                Text("The room opens when you're out in \(room.name) and not at a venue. Venues have their own chat. Your location has to be on so Hot Mess can tell.")
            }
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

    /// The room's messages, then the reader's own lines still on their way.
    private func threadMessages(_ viewModel: VenueChatViewModel) -> [ChatThreadMessage] {
        let sent = viewModel.messages.map { message in
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

        let pending = viewModel.pending.map { message in
            ChatThreadMessage(
                id: message.id.uuidString,
                authorID: viewModel.userID?.uuidString ?? "",
                authorName: nil,
                avatarURL: nil,
                text: message.body,
                sentAt: message.createdAt,
                isOwn: true,
                delivery: message.state == .failed ? .failed : .sending
            )
        }

        return sent + pending
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
            room: room,
            configuration: model.configuration,
            userID: model.session.userID,
            token: model.session.bearerToken,
            reportPresence: { [location = model.location] in await location.reportCurrentPosition() }
        )
    }
}
