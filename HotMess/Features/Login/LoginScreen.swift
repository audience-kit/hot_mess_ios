//
//  LoginScreen.swift
//  HotMess
//

import AuthenticationServices
import SwiftUI

/// What `RootView` shows when there is no session: the Hot Mess silhouette in
/// the audience's colours, its name and tagline, and Facebook sign-in, with
/// Sign in with Apple beside it (App Store guideline 4.8).
struct LoginScreen: View {
    @Environment(AppModel.self) private var model
    @AppStorage("hasAgreedToEULA") private var hasAgreedToEULA = false
    @State private var isShowingEULA = false
    @State private var pendingFacebookSignIn = false
    @State private var pendingAppleResult: Result<ASAuthorization, any Error>?
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
            if state == .signedIn {
                Task {
                    try? await model.safety.acceptTerms()
                }
            } else if case let .failed(message) = state {
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
        .sheet(isPresented: $isShowingEULA) {
            EULAView {
                hasAgreedToEULA = true
                if pendingFacebookSignIn {
                    pendingFacebookSignIn = false
                    Task { await model.session.signIn() }
                } else if let result = pendingAppleResult {
                    pendingAppleResult = nil
                    model.session.signInWithApple(result)
                }
            }
            .preferredColorScheme(nil)
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
            if model.session.state == .signedOut, let notice = model.session.endedNotice {
                Text(notice)
                    .font(.hotMess(.subheadline, semibold: true))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("login.sessionEnded")
            }

            eulaAgreementRow

            Button {
                if hasAgreedToEULA {
                    Task { await model.session.signIn() }
                } else {
                    pendingFacebookSignIn = true
                    isShowingEULA = true
                }
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

            SignInWithAppleButton(.continue) { request in
                request.requestedScopes = [.fullName, .email]
            } onCompletion: { result in
                if hasAgreedToEULA {
                    model.session.signInWithApple(result)
                } else {
                    pendingAppleResult = result
                    isShowingEULA = true
                }
            }
            .signInWithAppleButtonStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 54, maxHeight: 54)
            .clipShape(Capsule())
            .disabled(isSigningIn)
            .accessibilityIdentifier("login.apple")

            Text("Hot Mess uses your Facebook profile to find your friends and the events near you. With Apple, you can connect Facebook later.")
                .font(.hotMess(.footnote))
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.7))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var eulaAgreementRow: some View {
        HStack(alignment: .top, spacing: 10) {
            Button {
                hasAgreedToEULA.toggle()
            } label: {
                Image(systemName: hasAgreedToEULA ? "checkmark.square.fill" : "square")
                    .font(.system(size: 20))
                    .foregroundStyle(hasAgreedToEULA ? Color.hotMessAccentInk : .white.opacity(0.85))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("login.eulaCheckbox")

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Text("I agree to the")
                        .foregroundStyle(.white.opacity(0.9))
                    Button {
                        isShowingEULA = true
                    } label: {
                        Text("Terms of Use (EULA)")
                            .underline()
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("login.openEULA")
                }
                Text("Zero tolerance for objectionable content or abusive users.")
                    .font(.hotMess(.caption2))
                    .foregroundStyle(.white.opacity(0.7))
            }
            .font(.hotMess(.caption))
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 4)
    }

    private var isSigningIn: Bool {
        model.session.state == .signingIn
    }

    private var failureMessage: String? {
        if case let .failed(message) = model.session.state { return message }
        return nil
    }
}
