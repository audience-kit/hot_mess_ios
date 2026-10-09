//
//  Tokens.swift
//  HotMess
//

import AudienceKit
import AudienceKitUI
import SwiftUI
import UIKit

// The design system's tokens that the app draws with directly. Values come
// from the SDK's generated `DesignTokens` (admin/src/design/tokens.json), so
// don't copy them here. Colours use the Hot Mess theme's light and dark
// values. `hotMessAccent` itself lives in Theme.swift because it follows the
// audience's branding.

// MARK: - Colours

extension Color {
    /// `accent-soft`: a tinted fill for selected choices and accent badges.
    static var hotMessAccentSoft: Color { .token(\.accentSoft) }

    /// `accent-ink`: accent-coloured text on surfaces and on `accent-soft`,
    /// like a host's RoleTag and a rich message's overline.
    static var hotMessAccentInk: Color { .token(\.accentInk) }

    /// `control-fill`: the grey filled control, like a staff RoleTag.
    static var hotMessControlFill: Color { .token(\.controlFill) }

    /// Text and icons on `hotMessAccent` fills (`on-accent`). White on the
    /// light accent; dark on the dark accent, where white is only 2.4:1.
    static var hotMessOnAccent: Color { .token(\.onAccent) }

    /// `warning`: icons on `hotMessWarningSoft`.
    static var hotMessWarning: Color { .token(\.warning) }

    /// `warning-soft`: the background of a warning strip.
    static var hotMessWarningSoft: Color { .token(\.warningSoft) }

    /// `presence-online`: connected to a chat room now.
    static var hotMessPresenceOnline: Color { .token(\.presenceOnline) }

    /// `presence-push`: not in chat, but gets push notifications.
    static var hotMessPresencePush: Color { .token(\.presencePush) }

    /// `presence-push-edge`: keeps the yellow ring visible on light surfaces.
    static var hotMessPresencePushEdge: Color { .token(\.presencePushEdge) }

    /// `surface-sunken`: a well that reads as set into the page, like ChatPeek.
    static var hotMessSurfaceSunken: Color { .token(\.surfaceSunken) }

    /// `glass`: the dark fill of a pill over a photo, laid over
    /// `.ultraThinMaterial`. The same in every theme.
    static var hotMessGlass: Color { Color(DesignTokens.hotMess.glass) }

    /// `photo-placeholder`: hero and photo card fill while the image loads.
    /// The same in every theme.
    static var hotMessPhotoPlaceholder: Color { Color(DesignTokens.hotMess.photoPlaceholder) }

    /// `photo-ink`: dark text over a bright photo. The same in every theme.
    static var hotMessPhotoInk: Color { Color(DesignTokens.hotMess.photoInk) }

    /// `door-admit`: Door mode's full-screen "let them in". The same in every theme.
    static var hotMessDoorAdmit: Color { Color(red: 0x1F / 255, green: 0x9D / 255, blue: 0x55 / 255) }

    /// `door-re-entry`: Door mode's "coming back in", under dark text. The same in every theme.
    static var hotMessDoorReEntry: Color { Color(red: 0xF5 / 255, green: 0xB4 / 255, blue: 0x00 / 255) }

    /// `door-refuse`: Door mode's "don't let them in". The same in every theme.
    static var hotMessDoorRefuse: Color { Color(red: 0xC6 / 255, green: 0x28 / 255, blue: 0x28 / 255) }

    /// The white ring around avatars that sit on photos (`opacity-ring`).
    static var hotMessAvatarRing: Color { Color.white.opacity(HotMessOpacity.ring) }

    /// A Hot Mess colour token, resolving per light or dark appearance.
    static func token(_ token: KeyPath<DesignTokens.Colors, RGBAColor>) -> Color {
        Color(uiColor: UIColor { traits in
            let theme = traits.userInterfaceStyle == .dark ? DesignTokens.hotMessDark : DesignTokens.hotMess
            return UIColor(theme[keyPath: token])
        })
    }

    /// A token that's the same in every appearance.
    init(_ color: RGBAColor) {
        self.init(red: color.red, green: color.green, blue: color.blue, opacity: color.alpha)
    }
}

// MARK: - Radius

/// Corner radii (`radius-*`).
enum HotMessRadius {
    /// `radius-sm`: tiny tags, icons, a chat bubble's tail corner.
    static let sm = CGFloat(DesignTokens.Radius.sm)
    /// `radius-md`: buttons, notices, the event date tile.
    static let md = CGFloat(DesignTokens.Radius.md)
    /// `radius-lg`: cards, menus and small artwork.
    static let lg = CGFloat(DesignTokens.Radius.lg)
    /// `radius-bubble`: chat bubbles.
    static let bubble = CGFloat(DesignTokens.Radius.bubble)

    /// `radius-photo`: photo cards and DetailSection groups. 26 on iOS 26,
    /// matching the system's own corners; 12 before.
    static var photo: CGFloat {
        if #available(iOS 26, *) {
            return CGFloat(DesignTokens.Radius.photo)
        }
        return 12
    }
}

// MARK: - Opacity

/// Shared opacities (`opacity-*`).
enum HotMessOpacity {
    /// `opacity-busy-1`: NightCalendar level 1, as accent opacity.
    static let busy1 = DesignTokens.Opacity.busy1
    /// `opacity-busy-2`: NightCalendar level 2, as accent opacity.
    static let busy2 = DesignTokens.Opacity.busy2
    /// `opacity-past`: past nights in the calendar.
    static let past = DesignTokens.Opacity.past
    /// `opacity-ring`: the white ring around avatars on photos.
    static let ring = DesignTokens.Opacity.ring
}

// MARK: - Motion

/// Motion: short and functional, no bounce.
enum HotMessMotion {
    /// 150ms ease-out, for toggles and tone or state changes.
    static var quick: Animation { .easeOut(duration: 0.15) }
}
