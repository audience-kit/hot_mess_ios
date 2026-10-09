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
    /// Whether the user has agreed to the terms is read before the room opens.
    @State private var isCheckingTerms = true
    @State private var reportTarget: ChatThreadMessage?
    @State private var blockOffer: ChatThreadMessage?
    @State private var blockTarget: ChatThreadMessage?
    @State private var failureMessage: String?

    var body: some View {
        Group {
            if isCheckingTerms {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if !model.safety.hasAcceptedTerms {
                ChatTermsPrompt {
                    try await model.safety.acceptTerms()
                }
            } else {
                roomContent(viewModel)
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(room.name)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await model.safety.load()
            isCheckingTerms = false
        }
        // The room opens only once they've agreed to the terms.
        .task(id: model.safety.hasAcceptedTerms) {
            guard model.safety.hasAcceptedTerms else { return }

            let viewModel = makeViewModel()
            self.viewModel = viewModel
            await viewModel.run()
        }
        .onDisappear {
            let viewModel = self.viewModel
            Task { await viewModel?.stop() }
        }
        .confirmationDialog(
            String(localized: "Why are you reporting this message?"),
            isPresented: isPresenting($reportTarget),
            titleVisibility: .visible,
            presenting: reportTarget
        ) { message in
            ForEach(ChatReportReason.allCases) { reason in
                Button(reason.title) {
                    Task { await report(message, reason: reason) }
                }
            }
            Button(String(localized: "Cancel"), role: .cancel) {}
        } message: { _ in
            Text("The room's admins will look at it. They can remove the sender from the room.")
        }
        .alert(
            String(localized: "Thanks for reporting it"),
            isPresented: isPresenting($blockOffer),
            presenting: blockOffer
        ) { message in
            Button(blockTitle(message), role: .destructive) {
                Task { await block(message) }
            }
            Button(String(localized: "Not Now"), role: .cancel) {}
        } message: { _ in
            Text("Block them too, and you won't see their messages in any room.")
        }
        .alert(
            blockTitle(blockTarget),
            isPresented: isPresenting($blockTarget),
            presenting: blockTarget
        ) { message in
            Button(String(localized: "Block"), role: .destructive) {
                Task { await block(message) }
            }
            Button(String(localized: "Cancel"), role: .cancel) {}
        } message: { _ in
            Text("You won't see their messages in any room. They won't be told. You can unblock them in Settings.")
        }
        .alert(
            String(localized: "Something went wrong"),
            isPresented: isPresenting($failureMessage),
            presenting: failureMessage
        ) { _ in
            Button(String(localized: "OK"), role: .cancel) {}
        } message: { message in
            Text(message)
        }
    }

    @ViewBuilder
    private func roomContent(_ viewModel: VenueChatViewModel?) -> some View {
        VStack(spacing: 0) {
            if let viewModel, viewModel.connectionState == .notPresent {
                notPresent(viewModel)
            } else if let viewModel {
                if let kind = bannerKind(viewModel) {
                    RoomBanner(kind: kind, roomName: room.name, isLocale: room.kind == .locale)
                }
                // Who else is here, friends first. Above the pinned
                // announcement, which the thread draws at its top.
                let blocked = model.safety.blockedIDs
                let hereNow = viewModel.hereNow.filter { !blocked.contains($0.id) }
                if !hereNow.isEmpty {
                    HereNowStrip(people: hereNow)
                }
                // Each minute, so a special leaves the room when it ends.
                TimelineView(.everyMinute) { timeline in
                    let messages = threadMessages(viewModel, at: timeline.date)
                    ChatThreadView(
                        messages: messages,
                        roomName: room.name,
                        pinned: pinned(viewModel, in: messages),
                        onRetry: { id in
                            guard let id = UUID(uuidString: id) else { return }
                            Task { await viewModel.resend(id) }
                        },
                        onReport: { reportTarget = $0 },
                        onBlock: { blockTarget = $0 }
                    )
                }
                composer(viewModel)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    // MARK: - Reporting and blocking

    private func report(_ message: ChatThreadMessage, reason: ChatReportReason) async {
        guard let id = UUID(uuidString: message.id) else { return }

        do {
            try await model.safety.report(messageID: id, sender: sender(of: message), reason: reason, block: false)
            if !model.safety.isBlocked(UUID(uuidString: message.authorID)) {
                blockOffer = message
            }
        } catch {
            failureMessage = String(localized: "The report didn't go through. Please try again.")
        }
    }

    private func block(_ message: ChatThreadMessage) async {
        guard let sender = sender(of: message) else { return }

        do {
            try await model.safety.block(sender)
        } catch {
            failureMessage = String(localized: "Couldn't block them. Please try again.")
        }
    }

    private func sender(of message: ChatThreadMessage) -> BlockedUser? {
        UUID(uuidString: message.authorID).map { BlockedUser(id: $0, name: message.authorName, avatarURL: message.avatarURL) }
    }

    private func blockTitle(_ message: ChatThreadMessage?) -> String {
        if let name = message?.authorName, !name.isEmpty {
            return String(localized: "Block \(name)")
        }
        return String(localized: "Block")
    }

    /// A Bool binding for an optional, for dialogs presenting one.
    private func isPresenting<Value>(_ value: Binding<Value?>) -> Binding<Bool> {
        Binding(
            get: { value.wrappedValue != nil },
            set: { if !$0 { value.wrappedValue = nil } }
        )
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
    /// Friends show by their full name, everyone in the room now with a green
    /// dot, and friends a notification reaches with a yellow one. Specials that
    /// have ended, and people the user blocked, are left out.
    private func threadMessages(_ viewModel: VenueChatViewModel, at date: Date) -> [ChatThreadMessage] {
        let friends = model.friends.byID
        let blocked = model.safety.blockedIDs
        let sent = viewModel.messages
            .filter { $0.isShowing(at: date) }
            .filter { $0.isFromPlace || !blocked.contains($0.userID) }
            .map { message in
                message.threadMessage(
                    currentUserID: viewModel.userID,
                    friends: friends,
                    online: viewModel.onlineUserIDs,
                    reachable: viewModel.reachableUserIDs
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

    /// The pinned announcement, as the thread draws it.
    private func pinned(_ viewModel: VenueChatViewModel, in messages: [ChatThreadMessage]) -> ChatThreadMessage? {
        guard let pinned = viewModel.pinnedAnnouncement else { return nil }
        let id = pinned.id.uuidString
        // A pinned announcement can be older than the lines the room shows.
        return messages.first { $0.id == id && $0.announcementTitle != nil }
            ?? pinned.threadMessage(
                currentUserID: viewModel.userID,
                friends: model.friends.byID,
                online: viewModel.onlineUserIDs,
                reachable: viewModel.reachableUserIDs
            )
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
            friends: model.friends,
            reportPresence: { [location = model.location] in await location.reportCurrentPosition() }
        )
    }
}
