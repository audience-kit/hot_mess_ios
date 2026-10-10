//
//  CoverTests.swift
//  HotMessTests
//

import Foundation
import Testing

@testable import HotMess

private func decode<Value: Decodable>(_ type: Value.Type, from json: String) throws -> Value {
    try JSONDecoder.hotMess.decode(type, from: Data(json.utf8))
}

@Suite("Cover pass codes")
struct CoverPassTests {
    static let admissionID = "7d9f2c1e-3b4a-4e5f-8a6b-1c2d3e4f5a6b"
    static let secret = "c2VjcmV0LWtleS1mb3ItaG90LW1lc3MtY292ZXI="
    static let start = Date(timeIntervalSince1970: 1_791_331_200)

    /// Computed with the API's own recipe (app/services/cover_pass.rb):
    ///
    ///     ruby -ropenssl -rbase64 -e 'k = Base64.strict_decode64(SECRET); w = 1791331200 / 30
    ///       puts Base64.urlsafe_encode64(OpenSSL::HMAC.digest("SHA256", k, "#{ID}.#{w}"), padding: false)[0, 16]'
    @Test("Matches the API's code for the same pass and time")
    func matchesTheAPI() {
        #expect(CoverPass.window(at: Self.start) == 59_711_040)
        #expect(
            CoverPass.code(admissionID: Self.admissionID, secret: Self.secret, at: Self.start)
                == "HMC1.7d9f2c1e-3b4a-4e5f-8a6b-1c2d3e4f5a6b.59711040.HOStwur5mLjF7zvb"
        )
    }

    @Test("Holds for the window, then changes, with URL-safe signatures")
    func changesEveryThirtySeconds() {
        #expect(
            CoverPass.code(admissionID: Self.admissionID, secret: Self.secret, at: Self.start.addingTimeInterval(29.9))
                == "HMC1.7d9f2c1e-3b4a-4e5f-8a6b-1c2d3e4f5a6b.59711040.HOStwur5mLjF7zvb"
        )
        // This window's signature has a "-", which plain Base64 would write as "+".
        #expect(
            CoverPass.code(admissionID: Self.admissionID, secret: Self.secret, at: Self.start.addingTimeInterval(30))
                == "HMC1.7d9f2c1e-3b4a-4e5f-8a6b-1c2d3e4f5a6b.59711041.p2tYO-g5T45lRFzN"
        )
        #expect(CoverPass.secondsRemaining(at: Self.start) == 30)
        #expect(CoverPass.secondsRemaining(at: Self.start.addingTimeInterval(12)) == 18)
    }

    @Test("Makes nothing from a secret that isn't Base64")
    func badSecret() {
        #expect(CoverPass.code(admissionID: Self.admissionID, secret: "not base64!", at: Self.start) == nil)
    }

    @Test("Only paid passes with a secret have a code")
    func admissionCode() {
        let paid = Admission(id: Self.admissionID, status: .paid, night: "2026-10-09", totalCents: 1112, passSecret: Self.secret)
        #expect(paid.passCode(at: Self.start)?.hasSuffix(".HOStwur5mLjF7zvb") == true)

        let refunded = Admission(id: Self.admissionID, status: .refunded, night: "2026-10-09", totalCents: 1112, passSecret: Self.secret)
        #expect(refunded.passCode(at: Self.start) == nil)
    }
}

@Suite("Cover decoding")
struct CoverDecodingTests {
    static let admission = """
    {
      "id": "7d9f2c1e-3b4a-4e5f-8a6b-1c2d3e4f5a6b",
      "status": "PAID",
      "night": "2026-10-09",
      "total_cents": 1112,
      "currency": "usd",
      "is_refundable": true,
      "pass_secret": "c2VjcmV0LWtleS1mb3ItaG90LW1lc3MtY292ZXI=",
      "scan_count": 0,
      "checked_in_at": null,
      "user_name": "Rick Mark",
      "user_photo_url": "https://cdn.hotmess.social/users/rick.jpg",
      "venue": { "id": "8B4F1B60-9A5D-4D0E-9B3F-2C6B3E5D8A11", "name": "The Stud", "photo_url": null },
      "event": { "id": "e-1", "name": "Club Some Thing" }
    }
    """

    @Test("Reads a pass, keeping its ID as sent")
    func admission() throws {
        let admission = try decode(Admission.self, from: Self.admission)

        #expect(admission.id == "7d9f2c1e-3b4a-4e5f-8a6b-1c2d3e4f5a6b")
        #expect(admission.isPaid)
        #expect(admission.isRefundable)
        #expect(admission.venueName == "The Stud")
        #expect(admission.venueID == UUID(uuidString: "8B4F1B60-9A5D-4D0E-9B3F-2C6B3E5D8A11"))
        #expect(admission.eventName == "Club Some Thing")
        #expect(admission.userName == "Rick Mark")
    }

    @Test("A status from a newer API doesn't break the pass")
    func unknownStatus() throws {
        let admission = try decode(Admission.self, from: Self.admission.replacingOccurrences(of: "\"PAID\"", with: "\"ON_HOLD\""))
        #expect(admission.status == .unknown)
        #expect(!admission.isPaid)
    }

    @Test("Reads a venue's cover and the user's pass on Now")
    func nowCover() throws {
        let json = """
        {
          "title": "The Stud",
          "venue": {
            "id": "8B4F1B60-9A5D-4D0E-9B3F-2C6B3E5D8A11",
            "name": "The Stud",
            "cover_charge": {
              "amount_cents": 1000, "total_cents": 1112, "currency": "usd",
              "night": "2026-10-09", "from": "21:00", "payable": true
            },
            "viewer_admission": \(Self.admission)
          }
        }
        """
        let now = try decode(Now.self, from: json)

        #expect(now.coverCharge?.totalCents == 1112)
        #expect(now.coverCharge?.payable == true)
        #expect(now.viewerAdmission?.isPaid == true)
    }
}

@Suite("Paying cover")
struct CoverPaymentTests {
    static let pending = CoverDecodingTests.admission.replacingOccurrences(of: "\"PAID\"", with: "\"PENDING\"")

    private func decodePurchase(_ fields: String, admission: String = CoverPaymentTests.pending) throws -> CoverPurchase {
        try decode(CoverPurchase.self, from: "{ \"admission\": \(admission), \(fields) }")
    }

    @Test("Stripe venues pay with the payment sheet on the venue's account")
    func stripe() throws {
        let purchase = try decodePurchase("""
        "provider": "STRIPE", "payment_intent_client_secret": "pi_1_secret_2",
        "publishable_key": "pk_live_1", "stripe_account_id": "acct_1",
        "square_application_id": null, "square_location_id": null
        """)

        #expect(!purchase.isSquare)
        #expect(purchase.nextStep == .stripe(clientSecret: "pi_1_secret_2", publishableKey: "pk_live_1", accountID: "acct_1"))
    }

    @Test("A Stripe payment with no client secret is paid already")
    func stripePaid() throws {
        let purchase = try decodePurchase("""
        "provider": "STRIPE", "payment_intent_client_secret": null,
        "publishable_key": "pk_live_1", "stripe_account_id": "acct_1"
        """, admission: CoverDecodingTests.admission)

        #expect(purchase.nextStep == .showPass)
    }

    @Test("An API from before Square still means Stripe")
    func noProvider() throws {
        let purchase = try decodePurchase("""
        "payment_intent_client_secret": "pi_1_secret_2", "publishable_key": "pk_live_1", "stripe_account_id": "acct_1"
        """)

        #expect(purchase.provider == .stripe)
        #expect(purchase.nextStep == .stripe(clientSecret: "pi_1_secret_2", publishableKey: "pk_live_1", accountID: "acct_1"))
    }

    @Test("Stripe without its keys can't be paid in the app")
    func stripeMissingKeys() throws {
        let purchase = try decodePurchase("""
        "provider": "STRIPE", "payment_intent_client_secret": "pi_1_secret_2",
        "publishable_key": null, "stripe_account_id": "acct_1"
        """)

        #expect(purchase.nextStep == .unavailable)
    }

    @Test("Square venues pay with Square's SDK and the audience's application")
    func square() throws {
        let purchase = try decodePurchase("""
        "provider": "SQUARE", "payment_intent_client_secret": null,
        "publishable_key": null, "stripe_account_id": null,
        "square_application_id": "sq0idp-abc", "square_location_id": "L123"
        """)

        #expect(purchase.isSquare)
        #expect(purchase.squareLocationID == "L123")
        #expect(purchase.nextStep == .square(applicationID: "sq0idp-abc"))
    }

    @Test("A paid Square pass goes straight to the pass")
    func squarePaid() throws {
        let purchase = try decodePurchase("""
        "provider": "SQUARE", "square_application_id": "sq0idp-abc", "square_location_id": "L123"
        """, admission: CoverDecodingTests.admission)

        #expect(purchase.nextStep == .showPass)
    }

    @Test("Square without an application ID, or a provider from a newer API, can't be paid in the app")
    func unavailable() throws {
        #expect(try decodePurchase("\"provider\": \"SQUARE\", \"square_application_id\": \" \"").nextStep == .unavailable)

        let newer = try decodePurchase("\"provider\": \"ADYEN\"")
        #expect(newer.provider == .unknown)
        #expect(newer.nextStep == .unavailable)
    }

    @Test("Offers Apple Pay through Square only when it works here and the build has a merchant ID")
    func squareMethods() {
        #expect(SquarePaymentMethod.available(canUseApplePay: true, merchantID: "merchant.social.hotmess") == [.applePay, .card])
        #expect(SquarePaymentMethod.available(canUseApplePay: false, merchantID: "merchant.social.hotmess") == [.card])
        #expect(SquarePaymentMethod.available(canUseApplePay: true, merchantID: nil) == [.card])
        #expect(SquarePaymentMethod.available(canUseApplePay: true, merchantID: "") == [.card])
    }

    @Test("Apple Pay charges the all-in price in currency units")
    func totalAmount() {
        let admission = Admission(id: "a", status: .pending, night: "2026-10-09", totalCents: 1112)
        #expect(admission.totalAmount == Decimal(string: "11.12"))
    }
}

@Suite("Cover formatting")
struct CoverFormattingTests {
    @Test("Shows cents only when there are some")
    func price() {
        #expect(CoverFormat.price(cents: 1112, currency: "usd").contains("11.12"))
        #expect(!CoverFormat.price(cents: 1000, currency: "usd").contains("10.00"))
    }

    @Test("Reads nights as calendar dates")
    func night() throws {
        let date = try #require(CoverFormat.nightDate("2026-10-09"))
        #expect(date == Date(timeIntervalSince1970: 1_791_504_000))
        #expect(CoverFormat.time("21:00") != nil)
        #expect(CoverFormat.time("late") == nil)
    }

    @Test("Says tonight, or the night, and when it starts")
    func summary() {
        let cover = CoverCharge(amountCents: 1000, totalCents: 1112, night: "2026-10-09", from: "21:00", payable: true)

        #expect(cover.summary(isTonight: true).hasPrefix("Cover \(cover.price) tonight · from "))
        #expect(cover.summary(isTonight: false).hasPrefix("Cover \(cover.price) · "))

        let noStart = CoverCharge(amountCents: 1000, totalCents: 1000, night: "2026-10-09", payable: false)
        #expect(noStart.summary(isTonight: true) == "Cover \(noStart.price) tonight")
    }

    @Test("Only tonight's event cover can be paid")
    func eventTonight() throws {
        let tonight = CoverCharge(amountCents: 1000, totalCents: 1112, night: "2026-10-09", payable: true)
        let friday = CoverCharge(amountCents: 1500, totalCents: 1650, night: "2026-10-10", payable: true)
        let event = Event(id: UUID(), name: "Club Some Thing", startDate: .now)

        #expect(EventDetail(event: event, coverCharge: tonight, venueCoverTonight: tonight).isCoverTonight)
        #expect(!EventDetail(event: event, coverCharge: friday, venueCoverTonight: tonight).isCoverTonight)
        #expect(!EventDetail(event: event, coverCharge: friday).isCoverTonight)
    }
}
