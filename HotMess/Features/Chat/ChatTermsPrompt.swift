//
//  ChatTermsPrompt.swift
//  HotMess
//

import SwiftUI

/// Shown in place of a chat room until the user agrees to the terms of use,
/// which forbid objectionable content and abuse (App Store guideline 1.2).
/// Asked once per account; the API remembers.
struct ChatTermsPrompt: View {
    let accept: () async throws -> Void

    @State private var isAccepting = false
    @State private var didFail = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Image(systemName: "bubble.left.and.bubble.right")
                    .font(.system(size: 40))
                    .foregroundStyle(Color.hotMessAccentInk)
                    .accessibilityHidden(true)

                Text("Before you chat")
                    .font(.hotMess(.title2, semibold: true))
                    .accessibilityAddTraits(.isHeader)

                VStack(alignment: .leading, spacing: 10) {
                    rule("Be kind. No harassment, hate, threats or bullying.", systemImage: "heart")
                    rule("No nudity, sexual content or spam.", systemImage: "eye.slash")
                    rule("Don't share anyone's private information or out anyone.", systemImage: "lock")
                    rule("Press and hold a message to report it or block its sender.", systemImage: "hand.raised")
                }

                Text("There's no tolerance for objectionable content or abusive people. Admins remove messages and people that break these rules.")
                    .font(.hotMess(.subheadline))
                    .foregroundStyle(.secondary)

                Link(String(localized: "Read the Terms of Use"), destination: LegalLinks.terms)
                    .font(.hotMess(.subheadline, semibold: true))

                if didFail {
                    Text("That didn't go through. Please try again.")
                        .font(.hotMess(.footnote))
                        .foregroundStyle(.red)
                }

                Button {
                    Task { await agree() }
                } label: {
                    Text(isAccepting ? String(localized: "Saving…") : String(localized: "I Agree"))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(isAccepting)
                .accessibilityIdentifier("chat.acceptTerms")
            }
            .padding(24)
            .frame(maxWidth: 520)
            .frame(maxWidth: .infinity)
        }
    }

    private func rule(_ text: LocalizedStringKey, systemImage: String) -> some View {
        Label {
            Text(text)
                .font(.hotMess(.body))
        } icon: {
            Image(systemName: systemImage)
                .foregroundStyle(.secondary)
        }
    }

    private func agree() async {
        isAccepting = true
        didFail = false
        do {
            try await accept()
        } catch {
            didFail = true
        }
        isAccepting = false
    }
}

#Preview {
    ChatTermsPrompt {}
}
