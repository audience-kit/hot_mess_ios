//
//  CoverCheckout.swift
//  HotMess
//

import Foundation
import Observation
@preconcurrency import StripePaymentSheet
import UIKit

/// Pays a venue's cover in the app and shows the pass.
///
/// `buyCover` starts the payment on the venue's own Stripe account (a Connect
/// direct charge), Stripe's payment sheet takes it, and `confirmCover` checks
/// it with Stripe so the pass works before the webhook lands. One checkout
/// runs at a time, so the app keeps one of these and `CoverPresenter` shows
/// its pass and errors over whichever tab started it.
@MainActor
@Observable
final class CoverCheckout {
    /// The venue being paid for, while a payment is in flight.
    private(set) var payingVenueID: UUID?
    /// The pass on screen.
    var presentedPass: Admission?
    var errorMessage: String?
    /// Goes up whenever a pass is bought or refunded, so screens showing
    /// covers can reload.
    private(set) var revision = 0

    /// Where Stripe sends people back after a bank redirect.
    static let returnURL = "hotmess://stripe-redirect"

    private let api: HotMessAPI
    private let configuration: AppConfiguration

    init(api: HotMessAPI, configuration: AppConfiguration) {
        self.api = api
        self.configuration = configuration
    }

    /// Whether any payment is in flight.
    var isBusy: Bool { payingVenueID != nil }

    func isPaying(for venueID: UUID) -> Bool { payingVenueID == venueID }

    /// Pays tonight's cover at a venue and shows the pass once it's paid.
    func pay(venueID: UUID, venueName: String) async {
        guard payingVenueID == nil else { return }

        payingVenueID = venueID
        defer { payingVenueID = nil }

        do {
            let purchase = try await api.buyCover(venueID: venueID)

            // Paid already (another device, or a payment that finished after
            // the sheet closed): straight to the pass.
            guard let clientSecret = purchase.paymentIntentClientSecret else {
                finish(with: purchase.admission)
                return
            }

            switch await presentPaymentSheet(for: purchase, clientSecret: clientSecret, venueName: venueName) {
            case .completed:
                finish(with: try await api.confirmCover(admissionID: purchase.admission.id))
            case .canceled:
                break
            case let .failed(message):
                errorMessage = message
            }
        } catch is CancellationError {
        } catch {
            errorMessage = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
    }

    func show(_ admission: Admission) {
        presentedPass = admission
    }

    /// Refunds a pass and returns it as the API now has it.
    func refund(_ admission: Admission) async throws -> Admission {
        let refunded = try await api.refundAdmission(admission.id)
        revision += 1
        return refunded
    }

    private func finish(with admission: Admission) {
        revision += 1

        if admission.isPaid {
            presentedPass = admission
        } else {
            errorMessage = String(localized: "Your payment is still going through. Your pass shows up in Me once it has.")
        }
    }

    // MARK: - Stripe

    private enum SheetOutcome: Sendable {
        case completed
        case canceled
        case failed(String)
    }

    private func presentPaymentSheet(
        for purchase: CoverPurchase,
        clientSecret: String,
        venueName: String
    ) async -> SheetOutcome {
        // Direct charges live on the venue's account, so the sheet talks to
        // Stripe as that account with the platform's publishable key.
        STPAPIClient.shared.publishableKey = purchase.publishableKey
        STPAPIClient.shared.stripeAccount = purchase.stripeAccountID

        var sheetConfiguration = PaymentSheet.Configuration()
        sheetConfiguration.merchantDisplayName = venueName.isEmpty ? String(localized: "Hot Mess") : venueName
        sheetConfiguration.returnURL = Self.returnURL
        sheetConfiguration.allowsDelayedPaymentMethods = false
        if let merchantID = configuration.applePayMerchantID {
            sheetConfiguration.applePay = PaymentSheet.ApplePayConfiguration(
                merchantId: merchantID,
                merchantCountryCode: "US"
            )
        }

        let sheet = PaymentSheet(paymentIntentClientSecret: clientSecret, configuration: sheetConfiguration)

        guard let presenter = UIApplication.shared.topViewController else {
            return .failed(String(localized: "Couldn't open the payment sheet."))
        }

        return await withCheckedContinuation { continuation in
            sheet.present(from: presenter) { result in
                switch result {
                case .completed:
                    continuation.resume(returning: .completed)
                case .canceled:
                    continuation.resume(returning: .canceled)
                case let .failed(error):
                    continuation.resume(returning: .failed(error.localizedDescription))
                }
            }
        }
    }
}

extension UIApplication {
    /// The view controller on top in the foreground scene, to present UIKit
    /// sheets such as Stripe's over SwiftUI.
    var topViewController: UIViewController? {
        let scenes = connectedScenes.compactMap { $0 as? UIWindowScene }
        let scene = scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
        var top = scene?.keyWindow?.rootViewController

        while let presented = top?.presentedViewController, !presented.isBeingDismissed {
            top = presented
        }
        return top
    }
}
