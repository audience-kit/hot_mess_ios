//
//  Theme.swift
//  HotMess
//

import SwiftUI
import UIKit

extension Color {
    /// The audience's accent: the AudienceKit branding `accent` token, falling
    /// back to the `hot_mess` preset. Resolves light and dark per trait.
    static var hotMessAccent: Color {
        Color(uiColor: UIColor { traits in
            UIColor(BrandPalette.shared.accent(dark: traits.userInterfaceStyle == .dark))
        })
    }
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

    /// Proxima Nova at a fixed size that ignores Dynamic Type, for text that
    /// must fit a fixed shape, like an avatar's initials.
    static func hotMess(fixedSize size: CGFloat, semibold: Bool = false) -> Font {
        .custom(semibold ? "ProximaNova-Semibold" : "ProximaNova-Regular", fixedSize: size)
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
