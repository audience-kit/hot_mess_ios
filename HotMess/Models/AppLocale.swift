//
//  AppLocale.swift
//  HotMess
//

import Foundation

/// A city or neighbourhood the app serves content for.
///
/// Named `AppLocale` rather than `Locale`: the original model shadowed
/// `Foundation.Locale` app-wide, which is why several files had to spell out
/// `Foundation.Locale` to format anything.
struct AppLocale: Codable, Hashable, Sendable, Identifiable {
    let id: UUID
    let name: String
}
