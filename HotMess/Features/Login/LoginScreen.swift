//
//  LoginScreen.swift
//  HotMess
//

import SwiftUI

/// What `RootView` shows when there is no session: the Hot Mess silhouette in
/// the audience's colours, its name and tagline, and Facebook sign-in.
struct LoginScreen: View {
    @Environment(AppModel.self) private var model
    @State private var isShowingError = false
    @State private var hasAppeared = false
    @State private var isReportingProblem = false

    var body: some View {
        ZStack {
            // In a background so a fill-scaled image can't size the ZStack
            // past the screen, which pushed the button off an iPad's display.
            Color.clear
                .ignoresSafeArea()
                .background {
                    Image("LoginBackground")
                        .resizable()
                        .scaledToFill()
                        .ignoresSafeArea()
                        .accessibilityHidden(true)
                }
                .background(Color("LaunchBackground").ignoresSafeArea())

            VStack(spacing: 0) {
                header
                    .padding(.top, 72)

                Spacer(minLength: 32)

                signIn
                    .frame(maxWidth: 420)
                    .padding(.horizontal, 28)
                    .padding(.bottom, 32)
            }
            .opacity(hasAppeared ? 1 : 0)
            .offset(y: hasAppeared ? 0 : 12)
        }
        .preferredColorScheme(.dark)
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) { hasAppeared = true }
        }
        .onChange(of: model.session.state) { _, state in
            if case let .failed(message) = state {
                isShowingError = true
                ErrorReporter.shared.record(kind: "sign_in", message: message)
            }
        }
        .alert(String(localized: "Sign In Failed"), isPresented: $isShowingError) {
            Button(String(localized: "OK"), role: .cancel) {}
            Button(String(localized: "Report a Problem")) { isReportingProblem = true }
        } message: {
            Text(failureMessage ?? String(localized: "Please try again."))
        }
        .sheet(isPresented: $isReportingProblem) {
            NavigationStack {
                ReportProblemScreen()
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button(String(localized: "Cancel")) { isReportingProblem = false }
                        }
                    }
            }
            .preferredColorScheme(nil)
        }
    }

    private var header: some View {
        VStack(spacing: 10) {
            Text(model.brand.name)
                .font(.hotMess(.largeTitle, semibold: true))
                .scaleEffect(1.3)
                .padding(.bottom, 6)
                .foregroundStyle(.white)
                .accessibilityAddTraits(.isHeader)

            Text(model.brand.tagline ?? String(localized: "Find your people tonight."))
                .font(.hotMess(.title3))
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.85))
                .padding(.horizontal, 40)
        }
    }

    private var signIn: some View {
        VStack(spacing: 16) {
            Button {
                Task { await model.session.signIn() }
            } label: {
                HStack(spacing: 12) {
                    if isSigningIn {
                        ProgressView()
                            .tint(.black)
                    } else {
                        Image("Facebook")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 22, height: 22)
                            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                    }

                    Text(isSigningIn ? String(localized: "Signing In…") : String(localized: "Continue with Facebook"))
                        .font(.hotMess(.headline, semibold: true))
                }
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity, minHeight: 54)
                .background(.white, in: Capsule())
                .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .disabled(isSigningIn)
            .accessibilityIdentifier("login.facebook")
            .accessibilityLabel(String(localized: "Continue with Facebook"))

            Text("Hot Mess uses your Facebook profile to find your friends and the events near you.")
                .font(.hotMess(.footnote))
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.7))
                .fixedSize(horizontal: false, vertical: true)
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
