//
//  LoginScreen.swift
//  HotMess
//

import SwiftUI

/// Replaces `LoginViewController`, a nib-backed singleton that presented and
/// dismissed itself from four `NotificationCenter` observers. It is now just
/// what `RootView` shows when there is no session.
struct LoginScreen: View {
    @Environment(AppModel.self) private var model
    @State private var isShowingError = false

    var body: some View {
        ZStack {
            Image("LoginBackground")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
                .overlay(.black.opacity(0.35))

            VStack(spacing: 32) {
                Spacer()

                Image("Overlay")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 260)

                Spacer()

                VStack(spacing: 16) {
                    Button {
                        Task { await model.session.signIn() }
                    } label: {
                        Label(String(localized: "Continue with Facebook"), systemImage: "person.badge.key")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(isSigningIn)

                    Text("Hot Mess uses your Facebook profile to find your friends and the events near you.")
                        .font(.hotMess(.footnote))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white.opacity(0.8))
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 48)
            }
            .overlay {
                if isSigningIn {
                    ProgressView()
                        .controlSize(.large)
                        .tint(.white)
                }
            }
        }
        .preferredColorScheme(.dark)
        .onChange(of: model.session.state) { _, state in
            if case .failed = state { isShowingError = true }
        }
        .alert(String(localized: "Sign In Failed"), isPresented: $isShowingError) {
            Button(String(localized: "OK"), role: .cancel) {}
        } message: {
            Text(failureMessage ?? String(localized: "Please try again."))
        }
    }

    private var isSigningIn: Bool {
        model.session.state == .signingIn
    }

    private var failureMessage: String? {
        if case let .failed(message) = model.session.state { return message }
        return nil
    }
}
