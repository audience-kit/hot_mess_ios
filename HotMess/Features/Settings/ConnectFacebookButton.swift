//
//  ConnectFacebookButton.swift
//  HotMess
//

import SwiftUI

/// "Connect Facebook", for an account that signed in with Apple. Facebook is
/// what brings someone's friends; connecting it keeps the same account, or
/// moves the Apple sign-in onto the account their Facebook profile already
/// had.
struct ConnectFacebookButton: View {
    @Environment(AppModel.self) private var model
    @State private var isConnecting = false
    @State private var failureMessage: String?

    var body: some View {
        Button {
            Task { await connect() }
        } label: {
            HStack(spacing: 12) {
                if isConnecting {
                    ProgressView()
                } else {
                    Image("Facebook")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 22, height: 22)
                        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                }

                Text(isConnecting ? String(localized: "Connecting…") : String(localized: "Connect Facebook"))
            }
        }
        .disabled(isConnecting)
        .accessibilityIdentifier("connectFacebook")
        .alert(
            String(localized: "Couldn't connect Facebook"),
            isPresented: Binding(
                get: { failureMessage != nil },
                set: { if !$0 { failureMessage = nil } }
            )
        ) {
            Button(String(localized: "OK"), role: .cancel) {}
        } message: {
            Text(failureMessage ?? "")
        }
    }

    private func connect() async {
        isConnecting = true
        defer { isConnecting = false }

        do {
            _ = try await model.connectFacebook()
        } catch {
            failureMessage = error.localizedDescription
        }
    }
}

/// What connecting Facebook adds, under the button.
struct ConnectFacebookFooter: View {
    var body: some View {
        Text("You signed in with Apple. Connect Facebook to see which friends are out and where.")
    }
}
