//
//  Log.swift
//  HotMess
//

import Foundation
import os

/// Unified logging categories, replacing the app's scattered `NSLog` and
/// `print` calls.
enum Log {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "social.hotmess.HotMess"

    static let session = Logger(subsystem: subsystem, category: "session")
    static let network = Logger(subsystem: subsystem, category: "network")
    static let location = Logger(subsystem: subsystem, category: "location")
    static let realtime = Logger(subsystem: subsystem, category: "realtime")
    static let app = Logger(subsystem: subsystem, category: "app")
}
