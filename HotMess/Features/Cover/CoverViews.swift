//
//  CoverViews.swift
//  HotMess
//

import SwiftUI

extension View {
    /// Shows the pass `CoverCheckout` presents, and its payment errors. Attach
    /// once, above the tabs, so any screen can pay cover or open a pass.
    func coverPresenter() -> some View {
        modifier(CoverPresenter())
    }
}

private struct CoverPresenter: ViewModifier {
    @Environment(AppModel.self) private var model

    func body(content: Content) -> some View {
        @Bindable var checkout = model.checkout

        content
            .fullScreenCover(item: $checkout.presentedPass) { pass in
                PassScreen(admission: pass)
                    .environment(model)
            }
            .alert(
                String(localized: "Cover"),
                isPresented: Binding(
                    get: { checkout.errorMessage != nil },
                    set: { if !$0 { checkout.errorMessage = nil } }
                )
            ) {
                Button(String(localized: "OK"), role: .cancel) {}
            } message: {
                Text(checkout.errorMessage ?? "")
            }
    }
}

/// A venue's or event's cover: the price, and a way to pay it, show the pass,
/// or a note that it's paid at the door.
struct CoverSection: View {
    let coverCharge: CoverCharge?
    /// Whether the cover is tonight's, the only one that can be paid now.
    let isTonight: Bool
    /// The user's cover tonight at the venue.
    let admission: Admission?
    let venueID: UUID?
    let venueName: String

    var body: some View {
        DetailSection(String(localized: "Cover")) {
            if let coverCharge {
                Label(coverCharge.summary(isTonight: isTonight), systemImage: "ticket")
                    .font(.hotMess(.body))
            }

            if let admission, admission.isPaid {
                ShowPassButton(admission: admission)
            } else if isTonight, let coverCharge {
                if coverCharge.payable, let venueID {
                    PayCoverButton(venueID: venueID, venueName: venueName)
                } else if !coverCharge.payable {
                    Text("Pay at the door")
                        .font(.hotMess(.subheadline))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

/// Starts paying tonight's cover at a venue.
struct PayCoverButton: View {
    let venueID: UUID
    let venueName: String
    var title = String(localized: "Pay cover")

    @Environment(AppModel.self) private var model

    var body: some View {
        Button {
            Task { await model.checkout.pay(venueID: venueID, venueName: venueName) }
        } label: {
            HStack(spacing: 8) {
                if model.checkout.isPaying(for: venueID) {
                    ProgressView()
                        .tint(Color.hotMessOnAccent)
                }
                Text(title)
                    .font(.hotMess(.headline, semibold: true))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
        }
        .buttonStyle(.borderedProminent)
        .tint(Color.hotMessAccent)
        .foregroundStyle(Color.hotMessOnAccent)
        .disabled(model.checkout.isBusy)
        .accessibilityIdentifier("cover.pay")
    }
}

/// Opens a paid pass.
struct ShowPassButton: View {
    let admission: Admission

    @Environment(AppModel.self) private var model

    var body: some View {
        Button {
            model.checkout.show(admission)
        } label: {
            Label(String(localized: "Show pass"), systemImage: "qrcode")
                .font(.hotMess(.headline, semibold: true))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
        }
        .buttonStyle(.borderedProminent)
        .tint(Color.hotMessAccent)
        .foregroundStyle(Color.hotMessOnAccent)
        .accessibilityIdentifier("cover.showPass")
    }
}

/// Now, at a venue whose cover can be paid in the app and isn't yet.
struct SkipTheLineCard: View {
    let venue: Venue
    let coverCharge: CoverCharge

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(String(localized: "Skip the line, pay cover"), systemImage: "bolt.fill")
                .font(.hotMess(.headline, semibold: true))
                .foregroundStyle(Color.hotMessAccent)

            Text(coverCharge.summary(isTonight: true))
                .font(.hotMess(.subheadline))
                .foregroundStyle(.secondary)

            PayCoverButton(
                venueID: venue.id,
                venueName: venue.name,
                title: String(localized: "Pay \(coverCharge.price)")
            )
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.hotMessAccentSoft, in: .rect(cornerRadius: CardMetrics.cornerRadius))
        .padding(.horizontal, 16)
    }
}

/// Now, with a paid pass for the venue: the live code up front, opening the
/// full pass.
struct TonightPassCard: View {
    let admission: Admission

    @Environment(AppModel.self) private var model

    var body: some View {
        Button {
            model.checkout.show(admission)
        } label: {
            VStack(spacing: 0) {
                LiveBand()
                    .frame(height: 6)

                HStack(spacing: 16) {
                    PassCode(admission: admission)
                        .frame(width: 96, height: 96)
                        .padding(6)
                        .background(.white, in: .rect(cornerRadius: HotMessRadius.lg))

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Your pass")
                            .font(.hotMess(.footnote, semibold: true))
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)

                        Text(admission.venueName)
                            .font(.hotMess(.title3, semibold: true))
                            .lineLimit(2)

                        Text(String(localized: "Paid \(admission.price) · \(admission.nightTitle)"))
                            .font(.hotMess(.subheadline))
                            .foregroundStyle(.secondary)

                        HStack(spacing: 4) {
                            Text("Show at the door")
                            Image(systemName: "chevron.right")
                                .font(.footnote.weight(.semibold))
                        }
                        .font(.hotMess(.subheadline, semibold: true))
                        .foregroundStyle(Color.hotMessAccent)
                        .padding(.top, 2)
                    }

                    Spacer(minLength: 0)
                }
                .padding(16)
            }
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(.rect(cornerRadius: CardMetrics.cornerRadius))
            .contentShape(.rect(cornerRadius: CardMetrics.cornerRadius))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(localized: "Your pass for \(admission.venueName), \(admission.nightTitle)"))
        .accessibilityHint(String(localized: "Opens the pass to show at the door."))
        .accessibilityIdentifier("cover.tonightPass")
    }
}
