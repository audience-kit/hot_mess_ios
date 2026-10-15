//
//  EULAView.swift
//  HotMess
//

import SwiftUI

/// End User License Agreement (EULA) and Community Guidelines display, presented
/// to users before registering or logging in (App Store guideline 1.2).
struct EULAView: View {
    @Environment(\.dismiss) private var dismiss
    var onAccept: (() -> Void)?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header

                    Divider()

                    zeroToleranceSection

                    reportingSection

                    blockingSection

                    moderationSection

                    ejectionSection

                    legalLinksSection

                    if let onAccept {
                        Button {
                            onAccept()
                            dismiss()
                        } label: {
                            Text(String(localized: "I Agree to Terms & Safety Guidelines"))
                                .font(.hotMess(.headline, semibold: true))
                                .frame(maxWidth: .infinity, minHeight: 48)
                        }
                        .buttonStyle(.borderedProminent)
                        .padding(.top, 12)
                        .accessibilityIdentifier("eula.bottomAccept")
                    }
                }
                .padding(24)
                .frame(maxWidth: 600)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .navigationTitle(String(localized: "Terms of Use (EULA)"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Close")) {
                        dismiss()
                    }
                    .accessibilityIdentifier("eula.close")
                }
                if let onAccept {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(String(localized: "I Agree")) {
                            onAccept()
                            dismiss()
                        }
                        .fontWeight(.semibold)
                    }
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(String(localized: "Community Guidelines & Safety"), systemImage: "shield.checkered")
                .font(.hotMess(.title2, semibold: true))
                .foregroundStyle(Color.hotMessAccentInk)

            Text("Last updated: October 2026")
                .font(.hotMess(.caption))
                .foregroundStyle(.secondary)
        }
    }

    private var zeroToleranceSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("1. Zero Tolerance Policy")
                .font(.hotMess(.headline, semibold: true))

            Text("Hot Mess strictly enforces a zero-tolerance policy against objectionable, inappropriate, or abusive content and behavior. There is no tolerance for:")
                .font(.hotMess(.subheadline))
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 6) {
                bullet("Harassment, bullying, stalking, threats, or hate speech.")
                bullet("Nudity, sexually explicit or pornographic content.")
                bullet("Defamation, invasion of privacy, or posting personal data without consent.")
                bullet("Spam, scams, impersonation, or deceptive commercial activity.")
                bullet("Encouragement of self-harm, violence, or unlawful acts.")
            }
            .padding(.leading, 8)
        }
    }

    private var reportingSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("2. Flagging Objectionable Content")
                .font(.hotMess(.headline, semibold: true))

            Text("All users have an immediate mechanism to flag objectionable content:")
                .font(.hotMess(.subheadline))
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 6) {
                bullet("In Chat: Press and hold any message to open the moderation menu and select Report.")
                bullet("On Profiles: Tap the options menu (•••) on any profile to report that user.")
                bullet("Anywhere: Use 'Report a Problem' in Settings to send reports directly to our team.")
            }
            .padding(.leading, 8)
        }
    }

    private var blockingSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("3. Blocking Abusive Users")
                .font(.hotMess(.headline, semibold: true))

            Text("You can block any user at any time. When you block a user:")
                .font(.hotMess(.subheadline))
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 6) {
                bullet("Their messages, presence, and profile are instantly removed from your feed and chat.")
                bullet("The developer is notified immediately of the abusive user report for review.")
                bullet("The blocked user is not notified that they have been blocked.")
                bullet("You can review and manage your blocked users list anytime in Settings > Blocked People.")
            }
            .padding(.leading, 8)
        }
    }

    private var moderationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("4. 24-Hour Developer Action Guarantee")
                .font(.hotMess(.headline, semibold: true))

            Text("Our moderation staff reviews all flagged content and reports. The developer must and will act on all objectionable content reports within 24 hours by removing the offending content and ejecting / terminating the user who provided it.")
                .font(.hotMess(.subheadline))
                .foregroundStyle(.secondary)
        }
    }

    private var ejectionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("5. User Ejection & Account Termination")
                .font(.hotMess(.headline, semibold: true))

            Text("Violating these terms will result in immediate ejection from the community, deletion of offending content, and permanent banning from the Hot Mess platform.")
                .font(.hotMess(.subheadline))
                .foregroundStyle(.secondary)
        }
    }

    private var legalLinksSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Full Agreements")
                .font(.hotMess(.headline, semibold: true))

            HStack(spacing: 16) {
                Link(String(localized: "Full Terms of Use"), destination: LegalLinks.terms)
                    .font(.hotMess(.subheadline, semibold: true))

                Text("·")
                    .foregroundStyle(.secondary)

                Link(String(localized: "Privacy Policy"), destination: LegalLinks.privacy)
                    .font(.hotMess(.subheadline, semibold: true))
            }
        }
        .padding(.top, 8)
    }

    private func bullet(_ text: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
                .foregroundStyle(Color.hotMessAccentInk)
            Text(text)
                .font(.hotMess(.subheadline))
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    EULAView()
}
