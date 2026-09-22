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
            if let viewModel {
                transcript(viewModel)
                Divider()
                composer(viewModel)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
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

    private func transcript(_ viewModel: VenueChatViewModel) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 8) {
                    if viewModel.messages.isEmpty {
                        Text("Say hello.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .padding(.top, 40)
                    }

                    ForEach(viewModel.messages) { message in
                        MessageBubble(
                            message: message,
                            isOutgoing: viewModel.isOutgoing(message)
                        )
                        .id(message.id)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .onChange(of: viewModel.messages.count) { _, _ in
                guard let last = viewModel.messages.last else { return }
                withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
            }
        }
    }

    private func composer(_ viewModel: VenueChatViewModel) -> some View {
        @Bindable var viewModel = viewModel

        VStack(spacing: 6) {
            if case let .disconnected(reason) = viewModel.connectionState {
                Label(
                    reason ?? String(localized: "Disconnected"),
                    systemImage: "exclamationmark.triangle"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                TextField(String(localized: "Message"), text: $viewModel.draft, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1 ... 4)
                    .submitLabel(.send)
                    .onSubmit { Task { await viewModel.send() } }

                Button {
                    Task { await viewModel.send() }
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                }
                .disabled(!viewModel.canSend)
                .accessibilityLabel(String(localized: "Send"))
            }
        }
        .padding(12)
        .background(.bar)
    }

    private func makeViewModel() -> VenueChatViewModel {
        if let viewModel { return viewModel }

        return VenueChatViewModel(
            venue: venue,
            configuration: model.configuration,
            userID: model.session.userID,
            token: model.session.bearerToken
        )
    }
}

struct MessageBubble: View {
    let message: VenueMessage
    let isOutgoing: Bool

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isOutgoing { Spacer(minLength: 48) }

            if !isOutgoing {
                Avatar(url: message.avatarURL, size: 28)
            }

            Text(message.body)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .foregroundStyle(isOutgoing ? .white : .primary)
                .background(
                    isOutgoing ? Color.hotMessAccent : Color(.secondarySystemFill),
                    in: .rect(cornerRadius: 16)
                )

            if !isOutgoing { Spacer(minLength: 48) }
        }
        .frame(maxWidth: .infinity, alignment: isOutgoing ? .trailing : .leading)
    }
}
