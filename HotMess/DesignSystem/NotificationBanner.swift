//
//  NotificationBanner.swift
//  HotMess
//

import SwiftUI

extension View {
    /// Follows the user's notifications while the app is in front, and shows
    /// each one as a banner over the top of the screen. Attach once, above
    /// the tabs: the subscription lives as long as the signed-in UI does, and
    /// stops whenever the app goes to the background.
    func notificationBannerHost() -> some View {
        modifier(NotificationBannerHost())
    }
}

private struct NotificationBannerHost: ViewModifier {
    @Environment(AppModel.self) private var model
    @Environment(\.scenePhase) private var scenePhase

    /// How long a banner stays up untouched.
    private static let displayTime: Duration = .seconds(5)

    func body(content: Content) -> some View {
        let stream = model.notifications

        content
            .overlay(alignment: .top) {
                if let notification = stream.banner {
                    NotificationBanner(
                        notification: notification,
                        open: { open(notification) },
                        join: notification.ping?.kind == .ping && notification.category == PingNotification.category
                            ? { join(notification) }
                            : nil,
                        dismiss: { withAnimation(HotMessMotion.quick) { stream.dismiss(notification.id) } }
                    )
                    .id(notification.id)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .task(id: notification.id) {
                        try? await Task.sleep(for: Self.displayTime)
                        withAnimation(HotMessMotion.quick) { stream.dismiss(notification.id) }
                    }
                }
            }
            .animation(HotMessMotion.quick, value: stream.banner)
            // Cancelled on going to the background and when the signed-in UI goes
            // away; once chat has left too, the cable closes its socket.
            .task(id: scenePhase != .background) {
                guard scenePhase != .background else { return }
                await stream.run()
            }
    }

    private func open(_ notification: InAppNotification) {
        model.notifications.dismiss(notification.id)
        if let ping = notification.ping { model.open(ping) }
    }

    private func join(_ notification: InAppNotification) {
        model.notifications.dismiss(notification.id)
        guard let ping = notification.ping else { return }
        Task { await model.join(ping) }
    }
}

/// One notification, as a card under the status bar: tap to go where it
/// leads, swipe up to put it away.
struct NotificationBanner: View {
    let notification: InAppNotification
    let open: () -> Void
    /// "I'm in", for a friend's Ping.
    var join: (() -> Void)?
    let dismiss: () -> Void

    @GestureState private var drag: CGFloat = 0

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Button(action: open) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "bell.badge.fill")
                        .font(.hotMess(.body, semibold: true))
                        .foregroundStyle(Color.hotMessAccent)
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 2) {
                        if let title = notification.title {
                            Text(title)
                                .font(.hotMess(.subheadline, semibold: true))
                                .foregroundStyle(.primary)
                        }
                        if let body = notification.body {
                            Text(body)
                                .font(.hotMess(.subheadline))
                                .foregroundStyle(.secondary)
                                .lineLimit(3)
                        }
                    }
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("notification.banner")

            if let join {
                Button(String(localized: "I'm in"), action: join)
                    .font(.hotMess(.subheadline, semibold: true))
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.capsule)
                    .accessibilityIdentifier("notification.banner.join")
            }
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: HotMessRadius.lg, style: .continuous))
        .shadow(color: .black.opacity(0.15), radius: 12, y: 4)
        .padding(.horizontal, 12)
        .padding(.top, 4)
        .offset(y: min(0, drag))
        .gesture(
            DragGesture(minimumDistance: 10)
                .updating($drag) { value, state, _ in state = value.translation.height }
                .onEnded { value in
                    if value.translation.height < -24 { dismiss() }
                }
        )
        .accessibilityAction(named: String(localized: "Dismiss"), dismiss)
    }
}
