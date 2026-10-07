//
//  CoverPass.swift
//  HotMess
//

import CryptoKit
import Foundation

/// The QR code on a cover pass, made on the phone from the pass's secret so
/// it works with no signal (the API's `CoverPass`):
///
///     HMC1.<admission id>.<window>.<signature>
///
/// `window` is the Unix time divided by 30 and `signature` is the first 16
/// characters of the unpadded URL-safe Base64 HMAC-SHA256 of
/// `"<admission id>.<window>"`, keyed with the Base64-decoded secret. A
/// screenshot stops scanning within a minute or so; the door allows a couple
/// of windows either side for clock drift.
enum CoverPass {
    static let prefix = "HMC1"
    /// Seconds each code lasts.
    static let windowLength = 30

    /// The window a moment falls in.
    static func window(at date: Date) -> Int {
        Int((date.timeIntervalSince1970 / Double(windowLength)).rounded(.down))
    }

    /// The code to show at `date`, or `nil` when the secret isn't Base64.
    static func code(admissionID: String, secret: String, at date: Date = .now) -> String? {
        guard let key = Data(base64Encoded: secret) else { return nil }

        let current = window(at: date)
        let signed = signature(admissionID: admissionID, window: current, key: key)
        return [prefix, admissionID, String(current), signed].joined(separator: ".")
    }

    /// Seconds until the code shown at `date` changes.
    static func secondsRemaining(at date: Date = .now) -> Int {
        windowLength - Int(date.timeIntervalSince1970.rounded(.down)) % windowLength
    }

    static func signature(admissionID: String, window: Int, key: Data) -> String {
        let mac = HMAC<SHA256>.authenticationCode(
            for: Data("\(admissionID).\(window)".utf8),
            using: SymmetricKey(data: key)
        )

        let base64 = Data(mac).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        return String(base64.prefix(16))
    }
}

extension Admission {
    /// The pass's QR code at `date`, when this is a paid pass the user owns.
    func passCode(at date: Date = .now) -> String? {
        guard isPaid, let passSecret else { return nil }
        return CoverPass.code(admissionID: id, secret: passSecret, at: date)
    }
}
