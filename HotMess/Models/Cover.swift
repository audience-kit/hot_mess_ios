//
//  Cover.swift
//  HotMess
//

import Foundation

/// An amount of money as the API sends it: `Money { cents currency }`.
struct Money: Codable, Hashable, Sendable {
    let cents: Int
    /// An ISO 4217 code in lower case, e.g. `usd`.
    let currency: String

    init(cents: Int, currency: String = "usd") {
        self.cents = cents
        self.currency = currency
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        cents = try container.decode(Int.self, forKey: .cents)
        currency = try container.decodeIfPresent(String.self, forKey: .currency) ?? "usd"
    }

    /// The amount in the currency's units, for Apple Pay.
    var amount: Decimal { Decimal(cents) / 100 }

    /// "$11.12", or "$10" for whole amounts.
    var formatted: String { CoverFormat.price(cents: cents, currency: currency) }
}

/// What it costs to get into a venue on a night. The app shows `total`, the
/// all-in price, and takes it in the app when `payable`; otherwise it's paid
/// at the door.
struct CoverCharge: Decodable, Hashable, Sendable {
    /// The cover the venue receives.
    let amount: Money
    /// The service fee on top of `amount`.
    let fee: Money
    /// What the buyer pays, all in.
    let total: Money
    /// The night it is for, `yyyy-MM-dd`. A night runs 6am to 6am.
    let night: String
    /// When the cover starts, `HH:MM` local time (the API's `TimeOfDay`).
    let from: String?
    /// When it ends, `HH:MM` local time.
    let until: String?
    /// Whether it can be paid in the app.
    let payable: Bool

    enum CodingKeys: String, CodingKey {
        case amount, fee, total, night, from, until, payable
    }

    init(
        amount: Money,
        fee: Money = Money(cents: 0),
        total: Money,
        night: String,
        from: String? = nil,
        until: String? = nil,
        payable: Bool
    ) {
        self.amount = amount
        self.fee = fee
        self.total = total
        self.night = night
        self.from = from
        self.until = until
        self.payable = payable
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        amount = try container.decode(Money.self, forKey: .amount)
        total = try container.decode(Money.self, forKey: .total)
        fee = try container.decodeIfPresent(Money.self, forKey: .fee)
            ?? Money(cents: total.cents - amount.cents, currency: total.currency)
        night = try container.decode(String.self, forKey: .night)
        from = try container.decodeIfPresent(String.self, forKey: .from)
        until = try container.decodeIfPresent(String.self, forKey: .until)
        payable = try container.decodeIfPresent(Bool.self, forKey: .payable) ?? false
    }

    var price: String { total.formatted }

    /// "Cover $11.12 tonight · from 9 PM", or with the night instead of
    /// "tonight" for another night.
    func summary(isTonight: Bool) -> String {
        let cover = isTonight
            ? String(localized: "Cover \(price) tonight")
            : String(localized: "Cover \(price) · \(CoverFormat.night(night))")

        guard let start = from.flatMap(CoverFormat.time) else { return cover }
        return String(localized: "\(cover) · from \(start)")
    }

    /// A demo cover charge shown for venues in review or test mode.
    static func reviewDemo(night: String = "tonight") -> CoverCharge {
        CoverCharge(
            amount: Money(cents: 1000),
            fee: Money(cents: 0),
            total: Money(cents: 1000),
            night: night,
            from: "21:00",
            until: "02:00",
            payable: true
        )
    }
}

/// A venue's or an event's `tickets` mixin, read for the `cover` mixin the
/// cover module nests inside it: `tickets { cover { … } }`. Either is left out
/// where the audience doesn't have its module, so callers decode both with
/// `decodeIfPresent`.
struct TicketsMixin: Decodable, Hashable, Sendable {
    let cover: CoverMixin?
}

/// A venue's or an event's `cover` mixin, as the documents alias it: the
/// night's charge and, on a venue, the user's pass for tonight.
struct CoverMixin: Decodable, Hashable, Sendable {
    let coverCharge: CoverCharge?
    let viewerAdmission: Admission?

    enum CodingKeys: String, CodingKey {
        case coverCharge = "cover_charge"
        case viewerAdmission = "viewer_admission"
    }

    init(coverCharge: CoverCharge? = nil, viewerAdmission: Admission? = nil) {
        self.coverCharge = coverCharge
        self.viewerAdmission = viewerAdmission
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        coverCharge = try container.decodeIfPresent(CoverCharge.self, forKey: .coverCharge)
        viewerAdmission = try container.decodeIfPresent(Admission.self, forKey: .viewerAdmission)
    }
}

/// Where a cover payment stands.
enum AdmissionStatus: String, Decodable, Hashable, Sendable {
    case pending = "PENDING"
    case paid = "PAID"
    case failed = "FAILED"
    case canceled = "CANCELED"
    case refunded = "REFUNDED"
    case disputed = "DISPUTED"
    /// A status a newer API added.
    case unknown

    init(from decoder: any Decoder) throws {
        self = Self(rawValue: try decoder.singleValueContainer().decode(String.self)) ?? .unknown
    }

    var title: String {
        switch self {
        case .pending: String(localized: "Payment pending")
        case .paid: String(localized: "Paid")
        case .failed: String(localized: "Payment failed")
        case .canceled: String(localized: "Canceled")
        case .refunded: String(localized: "Refunded")
        case .disputed: String(localized: "Disputed")
        case .unknown: String(localized: "Unavailable")
        }
    }
}

/// Someone's cover for one night at a venue, and their pass.
struct Admission: Decodable, Hashable, Sendable, Identifiable {
    /// The API's ID, kept as sent: the pass code signs it character for character.
    let id: String
    var status: AdmissionStatus
    /// `yyyy-MM-dd`.
    let night: String
    /// What the buyer paid, all in.
    let total: Money
    /// Paid, not scanned in, and the night isn't over.
    var isRefundable: Bool
    /// The Base64 key the pass QR code is made with. Only the buyer gets it.
    let passSecret: String?
    let scanCount: Int
    let checkedInAt: Date?
    /// The buyer, as the API's `Profile { id name avatarUrl }`.
    let profile: Profile?
    let venueID: UUID?
    let venueName: String
    let venuePhotoURL: URL?
    let eventName: String?

    var isPaid: Bool { status == .paid }

    var price: String { total.formatted }

    /// "Fri, Oct 9".
    var nightTitle: String { CoverFormat.night(night) }

    enum CodingKeys: String, CodingKey {
        case id, status, night, total, profile, venue, event
        case isRefundable = "is_refundable"
        case passSecret = "pass_secret"
        case scanCount = "scan_count"
        case checkedInAt = "checked_in_at"
    }

    private enum PlaceKeys: String, CodingKey {
        case id, name
        case photoURL = "photo_url"
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(String.self, forKey: .id)
        status = try container.decode(AdmissionStatus.self, forKey: .status)
        night = try container.decode(String.self, forKey: .night)
        total = try container.decode(Money.self, forKey: .total)
        isRefundable = try container.decodeIfPresent(Bool.self, forKey: .isRefundable) ?? false
        passSecret = try container.decodeIfPresent(String.self, forKey: .passSecret)
        scanCount = try container.decodeIfPresent(Int.self, forKey: .scanCount) ?? 0
        checkedInAt = try? container.decodeIfPresent(Date.self, forKey: .checkedInAt)
        // A document that didn't select the buyer reads as none.
        profile = try? container.decodeIfPresent(Profile.self, forKey: .profile)

        if (try? container.decodeNil(forKey: .venue)) == false {
            let venue = try container.nestedContainer(keyedBy: PlaceKeys.self, forKey: .venue)
            venueID = try venue.decodeIfPresent(String.self, forKey: .id).flatMap(RecordID.uuid)
            venueName = try venue.decodeIfPresent(String.self, forKey: .name) ?? ""
            venuePhotoURL = try venue.decodeURLIfPresent(forKey: .photoURL)
        } else {
            venueID = nil
            venueName = ""
            venuePhotoURL = nil
        }

        if (try? container.decodeNil(forKey: .event)) == false {
            let event = try container.nestedContainer(keyedBy: PlaceKeys.self, forKey: .event)
            eventName = try event.decodeIfPresent(String.self, forKey: .name)
        } else {
            eventName = nil
        }
    }

    init(
        id: String,
        status: AdmissionStatus,
        night: String,
        total: Money,
        isRefundable: Bool = false,
        passSecret: String? = nil,
        scanCount: Int = 0,
        checkedInAt: Date? = nil,
        profile: Profile? = nil,
        venueID: UUID? = nil,
        venueName: String = "",
        venuePhotoURL: URL? = nil,
        eventName: String? = nil
    ) {
        self.id = id
        self.status = status
        self.night = night
        self.total = total
        self.isRefundable = isRefundable
        self.passSecret = passSecret
        self.scanCount = scanCount
        self.checkedInAt = checkedInAt
        self.profile = profile
        self.venueID = venueID
        self.venueName = venueName
        self.venuePhotoURL = venuePhotoURL
        self.eventName = eventName
    }
}

/// What `buyCover` returns: the pending pass and what the venue's payment
/// provider needs. Stripe venues pay with Stripe's payment sheet on the
/// venue's account; Square venues with Square's In-App Payments SDK.
struct CoverPurchase: Decodable, Sendable {
    /// Who takes the venue's cover.
    enum Provider: String, Decodable, Sendable {
        case stripe = "STRIPE"
        case square = "SQUARE"
        /// A provider a newer API added.
        case unknown

        init(from decoder: any Decoder) throws {
            self = Self(rawValue: try decoder.singleValueContainer().decode(String.self)) ?? .unknown
        }
    }

    let admission: Admission
    let provider: Provider
    /// Stripe: for the payment sheet; `nil` once it's paid.
    let paymentIntentClientSecret: String?
    /// Stripe: the audience's publishable key.
    let publishableKey: String?
    /// Stripe: the venue's connected account (a direct charge).
    let stripeAccountID: String?
    /// Square: the audience's application ID, for the In-App Payments SDK.
    let squareApplicationID: String?
    /// Square: the venue's location that gets paid.
    let squareLocationID: String?

    var isSquare: Bool { provider == .square }

    enum CodingKeys: String, CodingKey {
        case admission, provider
        case paymentIntentClientSecret = "payment_intent_client_secret"
        case publishableKey = "publishable_key"
        case stripeAccountID = "stripe_account_id"
        case squareApplicationID = "square_application_id"
        case squareLocationID = "square_location_id"
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        admission = try container.decode(Admission.self, forKey: .admission)
        // Every venue took cover through Stripe before Square came along.
        provider = try container.decodeIfPresent(Provider.self, forKey: .provider) ?? .stripe
        paymentIntentClientSecret = try container.decodeIfPresent(String.self, forKey: .paymentIntentClientSecret)
        publishableKey = try container.decodeIfPresent(String.self, forKey: .publishableKey)
        stripeAccountID = try container.decodeIfPresent(String.self, forKey: .stripeAccountID)
        squareApplicationID = try container.decodeIfPresent(String.self, forKey: .squareApplicationID)
        squareLocationID = try container.decodeIfPresent(String.self, forKey: .squareLocationID)
    }

    /// What the app does next to take this payment.
    var nextStep: CoverPaymentStep {
        switch provider {
        case .stripe:
            // Paid already (another device, or a payment that finished after
            // the sheet closed): no client secret, straight to the pass.
            guard let clientSecret = paymentIntentClientSecret.nonBlank else { return .showPass }
            guard let publishableKey = publishableKey.nonBlank,
                  let accountID = stripeAccountID.nonBlank
            else { return .unavailable }
            return .stripe(clientSecret: clientSecret, publishableKey: publishableKey, accountID: accountID)
        case .square:
            guard !admission.isPaid else { return .showPass }
            guard let applicationID = squareApplicationID.nonBlank else { return .unavailable }
            return .square(applicationID: applicationID)
        case .unknown:
            return .unavailable
        }
    }
}

/// The next step in paying a cover, from what `buyCover` returned.
enum CoverPaymentStep: Hashable, Sendable {
    /// Nothing left to pay.
    case showPass
    /// Stripe's payment sheet, on the venue's connected account.
    case stripe(clientSecret: String, publishableKey: String, accountID: String)
    /// Square's In-App Payments SDK makes a payment token for `payCover`.
    case square(applicationID: String)
    /// The API didn't send what the app needs to take the payment.
    case unavailable
}

/// How a Square venue's cover can be paid on this device.
enum SquarePaymentMethod: Hashable, Sendable {
    case applePay
    case card

    /// Apple Pay first when Square can take it here (or in review mode) and the build has a
    /// merchant ID; a card always.
    static func available(canUseApplePay: Bool, merchantID: String?, isReview: Bool = false) -> [SquarePaymentMethod] {
        (canUseApplePay || isReview) && merchantID.nonBlank != nil ? [.applePay, .card] : [.card]
    }
}

private extension Optional where Wrapped == String {
    /// `nil` for a missing or blank value.
    var nonBlank: String? {
        guard let value = self?.trimmingCharacters(in: .whitespaces), !value.isEmpty else { return nil }
        return value
    }
}

// MARK: - Formatting

enum CoverFormat {
    /// "$11.12", or "$10" for whole amounts.
    static func price(cents: Int, currency: String) -> String {
        (Decimal(cents) / 100).formatted(
            .currency(code: currency.uppercased())
                .precision(.fractionLength(cents % 100 == 0 ? 0 : 2))
        )
    }

    /// "21:00" as "9 PM", "21:30" as "9:30 PM", in the device's style.
    static func time(_ hhmm: String) -> String? {
        let parts = hhmm.split(separator: ":").compactMap { Int($0) }
        guard parts.count >= 2,
              let date = Calendar.current.date(bySettingHour: parts[0], minute: parts[1], second: 0, of: Date())
        else { return nil }

        let style: Date.FormatStyle = parts[1] == 0 ? .dateTime.hour() : .dateTime.hour().minute()
        return date.formatted(style)
    }

    /// "2026-10-09" as "Fri, Oct 9". Nights are calendar dates, so they're
    /// read and written in UTC to keep the day from shifting.
    static func night(_ iso: String) -> String {
        guard let date = nightDate(iso) else { return iso }

        var style = Date.FormatStyle.dateTime.weekday(.abbreviated).month(.abbreviated).day()
        style.timeZone = .gmt
        return date.formatted(style)
    }

    static func nightDate(_ iso: String) -> Date? {
        try? Date(iso, strategy: Date.ISO8601FormatStyle(timeZone: .gmt).year().month().day())
    }
}
