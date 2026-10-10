//
//  Cover.swift
//  HotMess
//

import Foundation

/// What it costs to get into a venue on a night. The app shows `totalCents`,
/// the all-in price, and takes it in the app when `payable`; otherwise it's
/// paid at the door.
struct CoverCharge: Decodable, Hashable, Sendable {
    /// The cover the venue receives, in cents.
    let amountCents: Int
    /// What the buyer pays, all in, in cents.
    let totalCents: Int
    /// An ISO 4217 code in lower case, e.g. `usd`.
    let currency: String
    /// The night it is for, `yyyy-MM-dd`. A night runs 6am to 6am.
    let night: String
    /// When the cover starts, `HH:MM` local time.
    let from: String?
    /// Whether it can be paid in the app.
    let payable: Bool

    enum CodingKeys: String, CodingKey {
        case currency, night, from, payable
        case amountCents = "amount_cents"
        case totalCents = "total_cents"
    }

    init(
        amountCents: Int,
        totalCents: Int,
        currency: String = "usd",
        night: String,
        from: String? = nil,
        payable: Bool
    ) {
        self.amountCents = amountCents
        self.totalCents = totalCents
        self.currency = currency
        self.night = night
        self.from = from
        self.payable = payable
    }

    var price: String { CoverFormat.price(cents: totalCents, currency: currency) }

    /// "Cover $11.12 tonight · from 9 PM", or with the night instead of
    /// "tonight" for another night.
    func summary(isTonight: Bool) -> String {
        let cover = isTonight
            ? String(localized: "Cover \(price) tonight")
            : String(localized: "Cover \(price) · \(CoverFormat.night(night))")

        guard let start = from.flatMap(CoverFormat.time) else { return cover }
        return String(localized: "\(cover) · from \(start)")
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
    /// What the buyer paid, in cents.
    let totalCents: Int
    let currency: String
    /// Paid, not scanned in, and the night isn't over.
    var isRefundable: Bool
    /// The Base64 key the pass QR code is made with. Only the buyer gets it.
    let passSecret: String?
    let scanCount: Int
    let checkedInAt: Date?
    let userName: String?
    let userPhotoURL: URL?
    let venueID: UUID?
    let venueName: String
    let venuePhotoURL: URL?
    let eventName: String?

    var isPaid: Bool { status == .paid }

    var price: String { CoverFormat.price(cents: totalCents, currency: currency) }

    /// What the buyer pays, in the currency's units, for Apple Pay.
    var totalAmount: Decimal { Decimal(totalCents) / 100 }

    /// "Fri, Oct 9".
    var nightTitle: String { CoverFormat.night(night) }

    enum CodingKeys: String, CodingKey {
        case id, status, night, currency, venue, event
        case totalCents = "total_cents"
        case isRefundable = "is_refundable"
        case passSecret = "pass_secret"
        case scanCount = "scan_count"
        case checkedInAt = "checked_in_at"
        case userName = "user_name"
        case userPhotoURL = "user_photo_url"
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
        totalCents = try container.decode(Int.self, forKey: .totalCents)
        currency = try container.decodeIfPresent(String.self, forKey: .currency) ?? "usd"
        isRefundable = try container.decodeIfPresent(Bool.self, forKey: .isRefundable) ?? false
        passSecret = try container.decodeIfPresent(String.self, forKey: .passSecret)
        scanCount = try container.decodeIfPresent(Int.self, forKey: .scanCount) ?? 0
        checkedInAt = try? container.decodeIfPresent(Date.self, forKey: .checkedInAt)
        userName = try container.decodeIfPresent(String.self, forKey: .userName)
        userPhotoURL = try container.decodeURLIfPresent(forKey: .userPhotoURL)

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
        totalCents: Int,
        currency: String = "usd",
        isRefundable: Bool = false,
        passSecret: String? = nil,
        scanCount: Int = 0,
        checkedInAt: Date? = nil,
        userName: String? = nil,
        userPhotoURL: URL? = nil,
        venueID: UUID? = nil,
        venueName: String = "",
        venuePhotoURL: URL? = nil,
        eventName: String? = nil
    ) {
        self.id = id
        self.status = status
        self.night = night
        self.totalCents = totalCents
        self.currency = currency
        self.isRefundable = isRefundable
        self.passSecret = passSecret
        self.scanCount = scanCount
        self.checkedInAt = checkedInAt
        self.userName = userName
        self.userPhotoURL = userPhotoURL
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

    /// Apple Pay first when Square can take it here and the build has a
    /// merchant ID; a card always.
    static func available(canUseApplePay: Bool, merchantID: String?) -> [SquarePaymentMethod] {
        canUseApplePay && merchantID.nonBlank != nil ? [.applePay, .card] : [.card]
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
