//
//  BugReport.swift
//  HotMess
//

import Foundation

/// What `POST /v1/bug_reports` takes: what the person wrote, how to reach
/// them, and the app's own diagnostics when they agree to send them.
struct BugReportRequest: Encodable, Equatable, Sendable {
    var app = "ios"
    var description: String
    var email: String?
    var screen: String?
    var version: String
    var build: String
    var osVersion: String
    var device: String
    /// Names the audience when no one is signed in.
    var host: String?
    var diagnostics: Diagnostics?

    struct Diagnostics: Encodable, Equatable, Sendable {
        var signedIn: Bool
        var environment: String
        var locale: String?
        var recentErrors: [ErrorReporter.Entry]

        enum CodingKeys: String, CodingKey {
            case signedIn = "signed_in"
            case environment, locale
            case recentErrors = "recent_errors"
        }
    }

    enum CodingKeys: String, CodingKey {
        case app, description, email, screen, version, build, device, host, diagnostics
        case osVersion = "os_version"
    }
}

struct BugReportResponse: Decodable, Sendable {
    let id: String
}
