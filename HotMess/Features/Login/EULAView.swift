//
//  EULAView.swift
//  HotMess
//

import SwiftUI

/// End User License Agreement (EULA) and Community Guidelines display, presented
/// to users before registering or logging in.
struct EULAView: View {
    @Environment(\.dismiss) private var dismiss
    var onAccept: (() -> Void)?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header

                    Divider()

                    creatorsSection

                    zeroToleranceSection

                    reportingSection

                    blockingSection

                    moderationSection

                    appealsSection

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

    private var creatorsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("1. Content Creators: Venues & People")
                .font(.hotMess(.headline, semibold: true))

            Text("Venues (clubs, bars, event organizers) and People (performers, DJs, hosts, and artists) are verified content creators who curate and publish event listings, music tracks, specials, announcements, and rich media through our dedicated creator applications, Velvet and Backstage. All creator content and community interactions must adhere to our safety standards.")
                .font(.hotMess(.subheadline))
                .foregroundStyle(.secondary)
        }
    }

    private var zeroToleranceSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("2. Zero Tolerance Policy")
                .font(.hotMess(.headline, semibold: true))

            Text("Hot Mess strictly enforces a zero-tolerance policy against objectionable, inappropriate, or abusive content and behavior from any content creator or user. There is no tolerance for:")
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
            Text("3. Flagging Objectionable Content")
                .font(.hotMess(.headline, semibold: true))

            Text("All users have an immediate mechanism to flag objectionable content:")
                .font(.hotMess(.subheadline))
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 6) {
                bullet("In Chat: Press and hold any message to open the moderation menu and select Report.")
                bullet("On Creator Profiles: Tap the options menu (•••) on any Venue or Performer profile to report that creator.")
                bullet("Anywhere: Use 'Report a Problem' in Settings to send reports directly to our team.")
            }
            .padding(.leading, 8)
        }
    }

    private var blockingSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("4. Blocking Abusive Users")
                .font(.hotMess(.headline, semibold: true))

            Text("You can block any user or creator at any time. When you block a user:")
                .font(.hotMess(.subheadline))
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 6) {
                bullet("Their messages, presence, and profile are instantly removed from your feed and chat.")
                bullet("Our moderation team is notified immediately of the report for review.")
                bullet("The blocked user is not notified that they have been blocked.")
                bullet("You can review and manage your blocked users list anytime in Settings > Blocked People.")
            }
            .padding(.leading, 8)
        }
    }

    private var moderationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("5. Swift Action on Reports (Within 24 Hours)")
                .font(.hotMess(.headline, semibold: true))

            Text("We act swiftly on every report. Our safety team reviews all flagged content, creator reports, and blocks within 24 hours, promptly removing offending content and ejecting abusive users from the community.")
                .font(.hotMess(.subheadline))
                .foregroundStyle(.secondary)
        }
    }

    private var appealsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("6. Appeals & Due Process")
                .font(.hotMess(.headline, semibold: true))

            Text("We believe in fair moderation with a strong bias toward a thorough and thoughtful appeal process. If you believe your content or account was flagged, restricted, or removed in error, you have a direct path to appeal:")
                .font(.hotMess(.subheadline))
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 6) {
                bullet("Submit an appeal anytime via 'Report a Problem' in Settings or by contacting support.")
                bullet("Every appeal is given a fresh, human review with an open mind to correcting mistakes.")
                bullet("Content or accounts determined to have been penalized in error are swiftly reinstated.")
            }
            .padding(.leading, 8)
        }
    }

    private var ejectionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("7. Creator & User Ejection")
                .font(.hotMess(.headline, semibold: true))

            Text("Confirmed violations of our community safety guidelines will result in swift ejection from the community, revocation of Velvet and Backstage creator publishing access, deletion of offending content, and permanent banning from the Hot Mess platform.")
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
