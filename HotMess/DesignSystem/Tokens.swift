//
//  Tokens.swift
//  HotMess
//

import SwiftUI
import UIKit

// The design system's tokens (tokens.json) that the app draws with directly.
// Colours use the Hot Mess theme's light and dark values. `hotMessAccent`
// itself lives in Theme.swift because it follows the audience's branding.

// MARK: - Colours

extension Color {
    /// `accent-soft`: a tinted fill for selected choices and accent badges.
    static var hotMessAccentSoft: Color { .dynamic(light: 0xFDE6F1, dark: 0x3B1A2C) }

    /// `accent-ink`: accent-coloured text on surfaces and on `accent-soft`,
    /// like a host's RoleTag and a rich message's overline.
    static var hotMessAccentInk: Color { .dynamic(light: 0xA01F61, dark: 0xFF93C4) }

    /// `control-fill`: the grey filled control, like a staff RoleTag.
    static var hotMessControlFill: Color { .dynamic(light: 0xEFE4EA, dark: 0x3D3239) }

    /// Text and icons on `hotMessAccent` fills (`on-accent`). White on the
    /// light accent; dark on the dark accent, where white is only 2.4:1.
    static var hotMessOnAccent: Color { .dynamic(light: 0xFFFFFF, dark: 0x3A0A22) }

    /// `warning`: icons on `hotMessWarningSoft`.
    static var hotMessWarning: Color { .dynamic(light: 0x8A5300, dark: 0xF2B84B) }

    /// `warning-soft`: the background of a warning strip.
    static var hotMessWarningSoft: Color { .dynamic(light: 0xFDF1D9, dark: 0x34270E) }

    /// `presence-online`: connected to a chat room now.
    static var hotMessPresenceOnline: Color { .dynamic(light: 0x1F9D55, dark: 0x2FBF5B) }

    /// `presence-push`: not in chat, but gets push notifications.
    static var hotMessPresencePush: Color { .dynamic(light: 0xF5B400, dark: 0xF5B400) }

    /// `presence-push-edge`: keeps the yellow ring visible on light surfaces.
    static var hotMessPresencePushEdge: Color { .dynamic(light: 0x8A5300, dark: 0xF5B400) }

    /// `surface-sunken`: a well that reads as set into the page, like ChatPeek.
    static var hotMessSurfaceSunken: Color { .dynamic(light: 0xFAF4F7, dark: 0x201A1F) }

    /// `glass`: the dark fill of a pill over a photo, laid over
    /// `.ultraThinMaterial`. The same in every theme.
    static var hotMessGlass: Color { Color(red: 28 / 255, green: 20 / 255, blue: 26 / 255, opacity: 0.55) }

    /// `photo-ink`: dark text over a bright photo. The same in every theme.
    static var hotMessPhotoInk: Color { Color(red: 0x24 / 255, green: 0x16 / 255, blue: 0x1D / 255) }

    /// `door-admit`: Door mode's full-screen "let them in". The same in every theme.
    static var hotMessDoorAdmit: Color { Color(red: 0x1F / 255, green: 0x9D / 255, blue: 0x55 / 255) }

    /// `door-re-entry`: Door mode's "coming back in", under dark text. The same in every theme.
    static var hotMessDoorReEntry: Color { Color(red: 0xF5 / 255, green: 0xB4 / 255, blue: 0x00 / 255) }

    /// `door-refuse`: Door mode's "don't let them in". The same in every theme.
    static var hotMessDoorRefuse: Color { Color(red: 0xC6 / 255, green: 0x28 / 255, blue: 0x28 / 255) }

    /// The white ring around avatars that sit on photos (`opacity-ring`).
    static var hotMessAvatarRing: Color { Color.white.opacity(HotMessOpacity.ring) }

    /// A colour that resolves per light or dark appearance from 0xRRGGBB values.
    static func dynamic(light: UInt32, dark: UInt32) -> Color {
        Color(uiColor: UIColor { traits in
            let rgb = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(
                red: CGFloat((rgb >> 16) & 0xFF) / 255,
                green: CGFloat((rgb >> 8) & 0xFF) / 255,
                blue: CGFloat(rgb & 0xFF) / 255,
                alpha: 1
            )
        })
    }
}

// MARK: - Radius

/// Corner radii (`radius-*`).
enum HotMessRadius {
    /// `radius-sm`: tiny tags, icons, a chat bubble's tail corner.
    static let sm: CGFloat = 4
    /// `radius-md`: buttons, notices, the event date tile.
    static let md: CGFloat = 6
    /// `radius-lg`: cards, menus and small artwork.
    static let lg: CGFloat = 8
    /// `radius-bubble`: chat bubbles.
    static let bubble: CGFloat = 16

    /// `radius-photo`: photo cards and DetailSection groups. 26 on iOS 26,
    /// matching the system's own corners; 12 before.
    static var photo: CGFloat {
        if #available(iOS 26, *) {
            return 26
        }
        return 12
    }
}

// MARK: - Opacity

/// Shared opacities (`opacity-*`).
enum HotMessOpacity {
    /// `opacity-busy-1`: NightCalendar level 1, as accent opacity.
    static let busy1: Double = 0.25
    /// `opacity-busy-2`: NightCalendar level 2, as accent opacity.
    static let busy2: Double = 0.6
    /// `opacity-past`: past nights in the calendar.
    static let past: Double = 0.35
    /// `opacity-ring`: the white ring around avatars on photos.
    static let ring: Double = 0.9
}

// MARK: - Motion

/// Motion: short and functional, no bounce.
enum HotMessMotion {
    /// 150ms ease-out, for toggles and tone or state changes.
    static var quick: Animation { .easeOut(duration: 0.15) }
}
