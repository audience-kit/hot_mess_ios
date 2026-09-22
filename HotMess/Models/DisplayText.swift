//
//  DisplayText.swift
//  HotMess
//

import Foundation

extension String {
    /// Up to two initials, for an avatar placeholder.
    ///
    /// The original built this with `String(describing:)` on an optional
    /// `Character` and rendered `Optional("R")` on screen.
    var initialsForDisplay: String {
        split(separator: " ")
            .prefix(2)
            .compactMap(\.first)
            .map(String.init)
            .joined()
            .uppercased()
    }

    /// The first word of a name.
    var firstNameForDisplay: String {
        split(separator: " ").first.map(String.init) ?? self
    }
}
