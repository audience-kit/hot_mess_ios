//
//  Theme.swift
//  HotMess
//

import SwiftUI

extension Color {
    /// The brand red the old PaintCode `StyleKit` drew by hand.
    static let hotMessAccent = Color(red: 0.649, green: 0.002, blue: 0.002)
}

extension Font {
    /// Proxima Nova, sized relative to a Dynamic Type style so the app scales
    /// with the user's text-size setting — the storyboards used fixed points.
    ///
    /// If the bundled font fails to register, SwiftUI falls back to the system
    /// face rather than failing to draw.
    static func hotMess(_ style: Font.TextStyle, semibold: Bool = false) -> Font {
        .custom(
            semibold ? "ProximaNova-Semibold" : "ProximaNova-Regular",
            size: baseSize(for: style),
            relativeTo: style
        )
    }

    private static func baseSize(for style: Font.TextStyle) -> CGFloat {
        switch style {
        case .largeTitle: 34
        case .title: 28
        case .title2: 22
        case .title3: 20
        case .headline: 17
        case .subheadline: 15
        case .body: 17
        case .callout: 16
        case .footnote: 13
        case .caption: 12
        case .caption2: 11
        @unknown default: 17
        }
    }
}

/// Formats a distance in metres for display.
///
/// Replaces `DistanceFormatter`, which hard-coded imperial units and then
/// labelled miles `"m"` — so "0.5 miles" rendered as "0.5 m".
enum DistanceFormat {
    static func string(fromMetres metres: Double) -> String {
        Measurement(value: metres, unit: UnitLength.meters)
            .formatted(
                .measurement(
                    width: .abbreviated,
                    usage: .road,
                    numberFormatStyle: .number.precision(.fractionLength(0 ... 1))
                )
            )
    }
}
