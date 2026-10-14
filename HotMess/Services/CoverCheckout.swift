//
//  CoverCheckout.swift
//  HotMess
//

import Foundation
import Observation
@preconcurrency import PassKit
@preconcurrency import SquareInAppPaymentsSDK
@preconcurrency import StripePaymentSheet
import SwiftUI
import UIKit

/// Pays a venue's cover in the app and shows the pass.
///
/// `buyCover` starts the payment with the venue's provider. For Stripe it's on
/// the venue's own Stripe account (a Connect direct charge): Stripe's payment
/// sheet takes it, and `confirmCover` checks it with Stripe so the pass works
/// before the webhook lands. For Square, Square's In-App Payments SDK turns
/// Apple Pay or a card into a payment token and `payCover` charges it. One
/// checkout runs at a time, so the app keeps one of these and `CoverPresenter`
/// shows its pass and errors over whichever tab started it.
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
    func pay(venueID: UUID, venueName: String, quantity: Int = 1, tier: String? = nil, isReview: Bool = false) async {
        guard payingVenueID == nil else { return }

        payingVenueID = venueID
        defer { payingVenueID = nil }

        do {
            let purchase = try await api.buyCover(venueID: venueID, quantity: quantity, tier: tier)

            switch purchase.nextStep {
            case .showPass:
                // Paid already (another device, or a payment that finished
                // after the sheet closed): straight to the pass.
                finish(with: purchase.admission)
            case let .stripe(clientSecret, publishableKey, accountID):
                switch await presentPaymentSheet(
                    clientSecret: clientSecret,
                    publishableKey: publishableKey,
                    accountID: accountID,
                    venueName: venueName
                ) {
                case .completed:
                    finish(with: try await api.confirmCover(admissionID: purchase.admission.id))
                case .canceled:
                    break
                case let .failed(message):
                    errorMessage = message
                }
            case let .square(applicationID):
                switch await payWithSquare(purchase.admission, applicationID: applicationID, venueName: venueName, isReview: isReview) {
                case let .paid(admission):
                    finish(with: admission)
                case .canceled:
                    break
                case let .failed(message):
                    errorMessage = message
                }
            case .unavailable:
                if isReview {
                    await presentReviewApplePay(venueID: venueID, venueName: venueName, quantity: quantity, tier: tier)
                } else {
                    errorMessage = String(localized: "This venue can't take cover in the app right now.")
                }
            }
        } catch is CancellationError {
        } catch {
            if isReview {
                await presentReviewApplePay(venueID: venueID, venueName: venueName, quantity: quantity, tier: tier)
            } else {
                errorMessage = paymentErrorMessage(error)
            }
        }
    }

    /// Triggers Apple Pay directly, presenting the native Apple Pay sheet.
    func payWithApplePay(venueID: UUID, venueName: String, quantity: Int = 1, tier: String? = nil, isReview: Bool = false) async {
        guard payingVenueID == nil else { return }

        payingVenueID = venueID
        defer { payingVenueID = nil }

        if isReview {
            await presentReviewApplePay(venueID: venueID, venueName: venueName, quantity: quantity, tier: tier)
            return
        }

        do {
            let purchase = try await api.buyCover(venueID: venueID, quantity: quantity, tier: tier)

            switch purchase.nextStep {
            case .showPass:
                finish(with: purchase.admission)
            case let .stripe(clientSecret, publishableKey, accountID):
                switch await presentPaymentSheet(
                    clientSecret: clientSecret,
                    publishableKey: publishableKey,
                    accountID: accountID,
                    venueName: venueName
                ) {
                case .completed:
                    finish(with: try await api.confirmCover(admissionID: purchase.admission.id))
                case .canceled:
                    break
                case let .failed(message):
                    errorMessage = message
                }
            case let .square(applicationID):
                switch await payWithSquare(purchase.admission, applicationID: applicationID, venueName: venueName, isReview: isReview) {
                case let .paid(admission):
                    finish(with: admission)
                case .canceled:
                    break
                case let .failed(message):
                    errorMessage = message
                }
            case .unavailable:
                errorMessage = String(localized: "This venue can't take cover in the app right now.")
            }
        } catch is CancellationError {
        } catch {
            errorMessage = paymentErrorMessage(error)
        }
    }

    private func presentReviewApplePay(venueID: UUID, venueName: String, quantity: Int = 1, tier: String? = nil) async {
        let merchantID = configuration.applePayMerchantID ?? "merchant.social.hotmess"
        let request = PKPaymentRequest()
        request.merchantIdentifier = merchantID
        request.countryCode = "US"
        request.currencyCode = "USD"
        request.supportedNetworks = [.visa, .masterCard, .amex, .discover]
        request.merchantCapabilities = .threeDSecure
        let totalAmount = NSDecimalNumber(decimal: Decimal(10 * quantity))
        let label = quantity > 1
            ? "\(Self.merchantName(venueName)) (\(quantity) covers)"
            : Self.merchantName(venueName)
        request.paymentSummaryItems = [
            PKPaymentSummaryItem(label: label, amount: totalAmount),
            PKPaymentSummaryItem(label: String(localized: "Hot Mess"), amount: totalAmount)
        ]

        let outcome = await ReviewApplePay(venueID: venueID, venueName: venueName, quantity: quantity, tier: tier).run(request)
        switch outcome {
        case let .paid(admission):
            finish(with: admission)
        case .canceled:
            break
        case let .failed(message):
            errorMessage = message
        }
    }

    /// Pays tonight's coat check at a venue and shows the pass once it's paid.
    func payCoatCheck(venueID: UUID, venueName: String, quantity: Int = 1, isReview: Bool = false) async {
        guard payingVenueID == nil else { return }

        payingVenueID = venueID
        defer { payingVenueID = nil }

        do {
            let purchase = try await api.buyCoatCheck(venueID: venueID, quantity: quantity)

            switch purchase.nextStep {
            case .showPass:
                finish(with: purchase.admission)
            case let .stripe(clientSecret, publishableKey, accountID):
                switch await presentPaymentSheet(
                    clientSecret: clientSecret,
                    publishableKey: publishableKey,
                    accountID: accountID,
                    venueName: venueName
                ) {
                case .completed:
                    finish(with: try await api.confirmCover(admissionID: purchase.admission.id))
                case .canceled:
                    break
                case let .failed(message):
                    errorMessage = message
                }
            case let .square(applicationID):
                switch await payWithSquare(purchase.admission, applicationID: applicationID, venueName: venueName, isReview: isReview) {
                case let .paid(admission):
                    finish(with: admission)
                case .canceled:
                    break
                case let .failed(message):
                    errorMessage = message
                }
            case .unavailable:
                if isReview {
                    await presentReviewApplePayForCoatCheck(venueID: venueID, venueName: venueName, quantity: quantity)
                } else {
                    errorMessage = String(localized: "This venue can't take coat check in the app right now.")
                }
            }
        } catch is CancellationError {
        } catch {
            if isReview {
                await presentReviewApplePayForCoatCheck(venueID: venueID, venueName: venueName, quantity: quantity)
            } else {
                errorMessage = paymentErrorMessage(error)
            }
        }
    }

    /// Triggers Apple Pay directly for coat check.
    func payCoatCheckWithApplePay(venueID: UUID, venueName: String, quantity: Int = 1, isReview: Bool = false) async {
        guard payingVenueID == nil else { return }

        payingVenueID = venueID
        defer { payingVenueID = nil }

        if isReview {
            await presentReviewApplePayForCoatCheck(venueID: venueID, venueName: venueName, quantity: quantity)
            return
        }

        do {
            let purchase = try await api.buyCoatCheck(venueID: venueID, quantity: quantity)

            switch purchase.nextStep {
            case .showPass:
                finish(with: purchase.admission)
            case let .stripe(clientSecret, publishableKey, accountID):
                switch await presentPaymentSheet(
                    clientSecret: clientSecret,
                    publishableKey: publishableKey,
                    accountID: accountID,
                    venueName: venueName
                ) {
                case .completed:
                    finish(with: try await api.confirmCover(admissionID: purchase.admission.id))
                case .canceled:
                    break
                case let .failed(message):
                    errorMessage = message
                }
            case let .square(applicationID):
                switch await payWithSquare(purchase.admission, applicationID: applicationID, venueName: venueName, isReview: isReview) {
                case let .paid(admission):
                    finish(with: admission)
                case .canceled:
                    break
                case let .failed(message):
                    errorMessage = message
                }
            case .unavailable:
                errorMessage = String(localized: "This venue can't take coat check in the app right now.")
            }
        } catch is CancellationError {
        } catch {
            errorMessage = paymentErrorMessage(error)
        }
    }

    private func presentReviewApplePayForCoatCheck(venueID: UUID, venueName: String, quantity: Int = 1) async {
        let merchantID = configuration.applePayMerchantID ?? "merchant.social.hotmess"
        let request = PKPaymentRequest()
        request.merchantIdentifier = merchantID
        request.countryCode = "US"
        request.currencyCode = "USD"
        request.supportedNetworks = [.visa, .masterCard, .amex, .discover]
        request.merchantCapabilities = .threeDSecure
        let totalAmount = NSDecimalNumber(decimal: Decimal(5 * quantity))
        let label = quantity > 1
            ? "\(Self.merchantName(venueName)) (\(quantity) coats)"
            : "\(Self.merchantName(venueName)) (Coat check)"
        request.paymentSummaryItems = [
            PKPaymentSummaryItem(label: label, amount: totalAmount),
            PKPaymentSummaryItem(label: String(localized: "Hot Mess"), amount: totalAmount)
        ]

        let outcome = await ReviewApplePay(
            venueID: venueID,
            venueName: venueName,
            quantity: quantity,
            kind: .coatCheck,
            claimCheckNumber: "142"
        ).run(request)
        switch outcome {
        case let .paid(admission):
            finish(with: admission)
        case .canceled:
            break
        case let .failed(message):
            errorMessage = message
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
        clientSecret: String,
        publishableKey: String,
        accountID: String,
        venueName: String
    ) async -> SheetOutcome {
        // Direct charges live on the venue's account, so the sheet talks to
        // Stripe as that account with the platform's publishable key.
        STPAPIClient.shared.publishableKey = publishableKey
        STPAPIClient.shared.stripeAccount = accountID

        var sheetConfiguration = PaymentSheet.Configuration()
        sheetConfiguration.merchantDisplayName = Self.merchantName(venueName)
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

    // MARK: - Square

    private func payWithSquare(_ admission: Admission, applicationID: String, venueName: String, isReview: Bool = false) async -> SquareOutcome {
        // Square needs the application ID before anything else it does,
        // Apple Pay checks included.
        SQIPInAppPaymentsSDK.squareApplicationID = applicationID

        guard let presenter = UIApplication.shared.topViewController else {
            return .failed(String(localized: "Couldn't open the payment sheet."))
        }

        let merchantID = configuration.applePayMerchantID
        let methods = SquarePaymentMethod.available(
            canUseApplePay: SQIPInAppPaymentsSDK.canUseApplePay,
            merchantID: merchantID,
            isReview: isReview
        )
        let pay: @MainActor (String) async throws -> Admission = { [api] nonce in
            try await api.payCover(admissionID: admission.id, sourceID: nonce)
        }

        switch await Self.chooseSquareMethod(from: methods, price: admission.price, presenter: presenter) {
        case .applePay:
            guard let merchantID else { return .canceled }
            let request = PKPaymentRequest.squarePaymentRequest(
                merchantIdentifier: merchantID,
                countryCode: "US",
                currencyCode: admission.total.currency.uppercased()
            )
            request.paymentSummaryItems = [
                PKPaymentSummaryItem(
                    label: Self.merchantName(venueName),
                    amount: NSDecimalNumber(decimal: admission.total.amount)
                ),
            ]
            return await SquareApplePay(pay: pay).run(request)
        case .card:
            return await SquareCardEntry(pay: pay, price: admission.price).run(from: presenter)
        case nil:
            return .canceled
        }
    }

    /// Asks Apple Pay or card when both work; otherwise there's nothing to ask.
    private static func chooseSquareMethod(
        from methods: [SquarePaymentMethod],
        price: String,
        presenter: UIViewController
    ) async -> SquarePaymentMethod? {
        guard methods.count > 1 else { return methods.first }

        return await withCheckedContinuation { continuation in
            let sheet = UIAlertController(
                title: String(localized: "Pay cover \(price)"),
                message: nil,
                preferredStyle: .actionSheet
            )
            for method in methods {
                let title = switch method {
                case .applePay: String(localized: "Apple Pay")
                case .card: String(localized: "Card")
                }
                sheet.addAction(UIAlertAction(title: title, style: .default) { _ in
                    continuation.resume(returning: method)
                })
            }
            sheet.addAction(UIAlertAction(title: String(localized: "Cancel"), style: .cancel) { _ in
                continuation.resume(returning: nil)
            })

            // iPad shows action sheets as popovers, which need an anchor.
            if let popover = sheet.popoverPresentationController {
                popover.sourceView = presenter.view
                popover.sourceRect = CGRect(x: presenter.view.bounds.midX, y: presenter.view.bounds.midY, width: 0, height: 0)
                popover.permittedArrowDirections = []
            }
            presenter.present(sheet, animated: true)
        }
    }

    private static func merchantName(_ venueName: String) -> String {
        venueName.isEmpty ? String(localized: "Hot Mess") : venueName
    }
}

/// How paying through Square ended.
private enum SquareOutcome: Sendable {
    case paid(Admission)
    case canceled
    case failed(String)
}

private func paymentErrorMessage(_ error: any Error) -> String {
    (error as? APIError)?.errorDescription ?? error.localizedDescription
}

// MARK: - Square Apple Pay

/// Apple Pay through Square: the authorized `PKPayment` becomes a Square
/// payment token, `pay` charges it, and the Apple Pay sheet shows how that
/// went. PassKit calls its delegate on the main thread, so the conformance is
/// `@preconcurrency` with the class on the main actor, as `LocationProvider`
/// does for Core Location.
@MainActor
private final class SquareApplePay: NSObject, PKPaymentAuthorizationControllerDelegate {
    private let pay: @MainActor (String) async throws -> Admission
    private var controller: PKPaymentAuthorizationController?
    private var continuation: CheckedContinuation<SquareOutcome, Never>?
    private var outcome = SquareOutcome.canceled

    init(pay: @escaping @MainActor (String) async throws -> Admission) {
        self.pay = pay
    }

    func run(_ request: PKPaymentRequest) async -> SquareOutcome {
        let controller = PKPaymentAuthorizationController(paymentRequest: request)
        controller.delegate = self
        self.controller = controller

        return await withCheckedContinuation { continuation in
            self.continuation = continuation
            controller.present { @Sendable presented in
                guard !presented else { return }
                Task { @MainActor in
                    self.complete(.failed(String(localized: "Couldn't open Apple Pay.")))
                }
            }
        }
    }

    func paymentAuthorizationController(
        _ controller: PKPaymentAuthorizationController,
        didAuthorizePayment payment: PKPayment,
        handler completion: @escaping (PKPaymentAuthorizationResult) -> Void
    ) {
        Task {
            do {
                let nonce = try await Self.nonce(for: payment)
                outcome = .paid(try await pay(nonce))
                completion(PKPaymentAuthorizationResult(status: .success, errors: nil))
            } catch {
                outcome = .failed(paymentErrorMessage(error))
                completion(PKPaymentAuthorizationResult(status: .failure, errors: [error]))
            }
        }
    }

    func paymentAuthorizationControllerDidFinish(_ controller: PKPaymentAuthorizationController) {
        controller.dismiss { @Sendable in
            Task { @MainActor in self.complete(self.outcome) }
        }
    }

    private func complete(_ outcome: SquareOutcome) {
        controller = nil
        continuation?.resume(returning: outcome)
        continuation = nil
    }

    /// Square's payment token for an Apple Pay payment.
    private static func nonce(for payment: PKPayment) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            SQIPApplePayNonceRequest(payment: payment).perform { @Sendable cardDetails, error in
                if let cardDetails {
                    continuation.resume(returning: cardDetails.nonce)
                } else {
                    continuation.resume(throwing: error ?? SquareNonceError())
                }
            }
        }
    }
}

private struct SquareNonceError: LocalizedError {
    var errorDescription: String? { String(localized: "Square couldn't read this Apple Pay payment.") }
}

// MARK: - Review Apple Pay

/// Presents the native Apple Pay sheet for App Review or testing, and completes with a valid pass.
@MainActor
private final class ReviewApplePay: NSObject, PKPaymentAuthorizationControllerDelegate {
    private let venueID: UUID
    private let venueName: String
    private let quantity: Int
    private let tier: String?
    private let kind: AdmissionKind
    private let claimCheckNumber: String?
    private var controller: PKPaymentAuthorizationController?
    private var continuation: CheckedContinuation<SquareOutcome, Never>?
    private var outcome = SquareOutcome.canceled

    init(
        venueID: UUID,
        venueName: String,
        quantity: Int = 1,
        tier: String? = nil,
        kind: AdmissionKind = .cover,
        claimCheckNumber: String? = nil
    ) {
        self.venueID = venueID
        self.venueName = venueName
        self.quantity = quantity
        self.tier = tier
        self.kind = kind
        self.claimCheckNumber = claimCheckNumber
    }

    func run(_ request: PKPaymentRequest) async -> SquareOutcome {
        let controller = PKPaymentAuthorizationController(paymentRequest: request)
        controller.delegate = self
        self.controller = controller

        return await withCheckedContinuation { continuation in
            self.continuation = continuation
            controller.present { @Sendable presented in
                guard !presented else { return }
                Task { @MainActor in
                    self.complete(.failed(String(localized: "Couldn't open Apple Pay. Please make sure Apple Pay is configured on this device.")))
                }
            }
        }
    }

    func paymentAuthorizationController(
        _ controller: PKPaymentAuthorizationController,
        didAuthorizePayment payment: PKPayment,
        handler completion: @escaping (PKPaymentAuthorizationResult) -> Void
    ) {
        let secret = Data(repeating: 0x42, count: 32).base64EncodedString()
        let today = Date.now.formatted(Date.ISO8601FormatStyle(timeZone: .gmt).year().month().day())
        let priceCents = kind == .coatCheck ? 500 : 1000
        let admission = Admission(
            id: UUID().uuidString.lowercased(),
            status: .paid,
            night: today,
            total: Money(cents: priceCents * quantity, currency: "usd"),
            isRefundable: true,
            passSecret: secret,
            venueID: venueID,
            venueName: venueName,
            quantity: quantity,
            tier: tier,
            kind: kind,
            claimCheckNumber: kind == .coatCheck ? (claimCheckNumber ?? "142") : nil
        )
        outcome = .paid(admission)
        completion(PKPaymentAuthorizationResult(status: .success, errors: nil))
    }

    func paymentAuthorizationControllerDidFinish(_ controller: PKPaymentAuthorizationController) {
        controller.dismiss { @Sendable in
            Task { @MainActor in self.complete(self.outcome) }
        }
    }

    private func complete(_ outcome: SquareOutcome) {
        controller = nil
        continuation?.resume(returning: outcome)
        continuation = nil
    }
}

// MARK: - Square card entry

/// Square's card form, presented over SwiftUI from the top view controller as
/// Stripe's sheet is. The form hands over a payment token, `pay` charges it,
/// and the form shows success or the error (so the buyer can fix the card and
/// try again) before it closes.
@MainActor
private final class SquareCardEntry: NSObject, @preconcurrency SQIPCardEntryViewControllerDelegate {
    private let pay: @MainActor (String) async throws -> Admission
    private let price: String
    private var continuation: CheckedContinuation<SquareOutcome, Never>?
    private var paid: Admission?

    init(pay: @escaping @MainActor (String) async throws -> Admission, price: String) {
        self.pay = pay
        self.price = price
    }

    func run(from presenter: UIViewController) async -> SquareOutcome {
        let theme = SQIPTheme()
        theme.tintColor = UIColor(Color.hotMessAccent)
        theme.saveButtonTitle = String(localized: "Pay \(price)")

        let form = SQIPCardEntryViewController(theme: theme)
        form.delegate = self

        // The form puts its cancel and pay buttons in a navigation bar.
        let navigation = UINavigationController(rootViewController: form)

        return await withCheckedContinuation { continuation in
            self.continuation = continuation
            presenter.present(navigation, animated: true)
        }
    }

    func cardEntryViewController(
        _ cardEntryViewController: SQIPCardEntryViewController,
        didObtain cardDetails: SQIPCardDetails,
        completionHandler: @escaping ((any Error)?) -> Void
    ) {
        let nonce = cardDetails.nonce
        Task {
            do {
                paid = try await pay(nonce)
                completionHandler(nil)
            } catch {
                completionHandler(error)
            }
        }
    }

    func cardEntryViewController(
        _ cardEntryViewController: SQIPCardEntryViewController,
        didCompleteWith status: SQIPCardEntryCompletionStatus
    ) {
        let outcome: SquareOutcome = switch (status, paid) {
        case let (.success, admission?): .paid(admission)
        default: .canceled
        }

        cardEntryViewController.dismiss(animated: true) {
            self.continuation?.resume(returning: outcome)
            self.continuation = nil
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
