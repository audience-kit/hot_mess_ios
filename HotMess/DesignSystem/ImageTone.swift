//
//  ImageTone.swift
//  HotMess
//

import CoreGraphics
import SwiftUI

/// How a hero banner's text and bars are drawn over its photo.
struct HeroTone: Equatable, Sendable {
    enum Text: Equatable, Sendable {
        case light
        case dark
    }

    /// The colour of the title and metadata.
    var text: Text
    /// Opacity of the gradient behind the text: black under light text, white under dark.
    var scrim: Double
    /// The navigation bar's colour scheme over the photo; `.dark` draws a white status bar.
    var bar: ColorScheme
    /// Opacity of a fade under the status bar, for photos where neither status bar style reads.
    var barScrim: Double

    /// White text on a dark placeholder: right for most nightlife photos, and for the
    /// accent gradient shown when there is no photo.
    static let placeholder = HeroTone(text: .light, scrim: 0, bar: .dark, barScrim: 0)

    var textColor: Color { text == .light ? .white : ImageTone.ink }
    var scrimColor: Color { text == .light ? .black : .white }
    var barScrimColor: Color { bar == .dark ? .black : .white }
}

/// Reads how bright a photo is behind a hero's text and status bar, and picks a
/// text colour and the smallest scrim that keeps it readable.
///
/// Each area is shrunk to 64 pixels wide and judged by its brightest 5% rather
/// than its average, so one spotlight right behind a letter still counts. Light
/// text wins whenever it reaches the target; dark text only when the photo is
/// bright and even enough to need no scrim. A busy photo (city lights, murals,
/// crowds) always gets light text over at least `busyScrim`: contrast against
/// the brightest pixels alone doesn't account for letters crossing a pattern.
enum ImageTone {
    /// The `photo-ink` token, #24161d, used for dark hero text.
    static var ink: Color { .hotMessPhotoInk }
    static let inkLuminance = 0.0103

    /// Past this the photo is mostly hidden, so the scrim stops here.
    static let maxScrim = 0.75

    /// The least scrim behind text on a busy photo.
    static let busyScrim = 0.45
    /// A text band whose brightest and darkest pixels differ by this much is busy.
    static let busyContrast = 3.0

    /// Decides the tone for an image drawn aspect-fill into a view of `viewSize`.
    ///
    /// `top` and `band` are in the view's points: the status bar and toolbar area,
    /// and the area behind the hero's text.
    static func analyze(
        _ image: CGImage,
        viewSize: CGSize,
        top: CGRect,
        band: CGRect,
        target: Double = 4.5,
        scrimFloor: Double = 0
    ) -> HeroTone? {
        let imageSize = CGSize(width: image.width, height: image.height)
        guard
            let topLuminances = luminances(image, in: imageRect(for: top, imageSize: imageSize, viewSize: viewSize)),
            let bandLuminances = luminances(image, in: imageRect(for: band, imageSize: imageSize, viewSize: viewSize))
        else { return nil }

        return decide(top: topLuminances, band: bandLuminances, target: target, scrimFloor: scrimFloor)
    }

    /// The pure decision, given relative luminances (0…1) sampled from each area.
    static func decide(top: [Double], band: [Double], target: Double = 4.5, scrimFloor: Double = 0) -> HeroTone {
        let band = band.sorted()
        let darkest = percentile(band, 0.1)
        let brightest = percentile(band, 0.95)
        let busy = contrast(brightest, darkest) >= busyContrast

        let text: HeroTone.Text
        var scrim: Double
        if busy {
            text = .light
            scrim = max(busyScrim, scrimFor(brightest, target: target))
        } else if contrast(1, brightest) >= target {
            text = .light
            scrim = 0
        } else if contrast(darkest, inkLuminance) >= target {
            text = .dark
            scrim = 0
        } else {
            text = .light
            scrim = scrimFor(brightest, target: target)
        }
        scrim = min(max(scrim, scrimFloor), maxScrim)

        let top = top.sorted()
        let white = contrast(1, percentile(top, 0.75))
        let black = contrast(percentile(top, 0.25), 0)

        return HeroTone(
            text: text,
            scrim: scrim,
            bar: white >= black ? .dark : .light,
            barScrim: max(white, black) < 3 ? 0.3 : 0
        )
    }

    /// A black scrim at opacity a scales luminance by (1 - a); this solves for the
    /// brightest pixel landing exactly on the target against white.
    static func scrimFor(_ brightest: Double, target: Double) -> Double {
        brightest <= 0 ? 0 : 1 - (1.05 / target - 0.05) / brightest
    }

    /// WCAG relative luminance of an 8-bit sRGB colour.
    static func luminance(red: UInt8, green: UInt8, blue: UInt8) -> Double {
        func linear(_ channel: UInt8) -> Double {
            let value = Double(channel) / 255
            return value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
    }

    static func contrast(_ first: Double, _ second: Double) -> Double {
        (max(first, second) + 0.05) / (min(first, second) + 0.05)
    }

    // MARK: - Sampling

    /// Maps a rect in the view to the pixels of an image drawn aspect-fill and
    /// centred in it, clipped to the image.
    static func imageRect(for rect: CGRect, imageSize: CGSize, viewSize: CGSize) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0, viewSize.width > 0, viewSize.height > 0 else { return .null }

        let scale = max(viewSize.width / imageSize.width, viewSize.height / imageSize.height)
        let originX = (viewSize.width - imageSize.width * scale) / 2
        let originY = (viewSize.height - imageSize.height * scale) / 2

        return CGRect(
            x: (rect.minX - originX) / scale,
            y: (rect.minY - originY) / scale,
            width: rect.width / scale,
            height: rect.height / scale
        )
        .intersection(CGRect(origin: .zero, size: imageSize))
        .integral
    }

    /// The luminance of each pixel of `rect`, shrunk to `columns` wide.
    static func luminances(_ image: CGImage, in rect: CGRect, columns: Int = 64) -> [Double]? {
        guard
            !rect.isNull, rect.width >= 1, rect.height >= 1,
            let cropped = image.cropping(to: rect),
            let space = CGColorSpace(name: CGColorSpace.sRGB)
        else { return nil }

        let rows = max(4, Int((Double(columns) * rect.height / rect.width).rounded()))
        var pixels = [UInt8](repeating: 0, count: columns * rows * 4)

        let drawn = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(
                data: buffer.baseAddress,
                width: columns,
                height: rows,
                bitsPerComponent: 8,
                bytesPerRow: columns * 4,
                space: space,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return false }

            context.interpolationQuality = .medium
            context.draw(cropped, in: CGRect(x: 0, y: 0, width: columns, height: rows))
            return true
        }
        guard drawn else { return nil }

        return stride(from: 0, to: pixels.count, by: 4).map { index in
            luminance(red: pixels[index], green: pixels[index + 1], blue: pixels[index + 2])
        }
    }

    private static func percentile(_ sorted: [Double], _ fraction: Double) -> Double {
        guard !sorted.isEmpty else { return 0 }
        return sorted[min(sorted.count - 1, Int(fraction * Double(sorted.count)))]
    }
}

extension View {
    /// A soft shadow under light text on a photo, so letter edges hold where the
    /// scrim fades out. Dark text sits on an even, bright photo and needs none.
    func photoTextShadow(_ tone: HeroTone) -> some View {
        shadow(color: .black.opacity(tone.text == .light ? 0.5 : 0), radius: 3, x: 0, y: 1)
    }
}

/// Remembers each photo's tone so going back to a screen doesn't flicker
/// between styles while the image is re-read.
@MainActor
enum HeroToneCache {
    private static var tones: [String: HeroTone] = [:]

    static func tone(for key: String) -> HeroTone? { tones[key] }

    static func store(_ tone: HeroTone, for key: String) {
        if tones.count > 200 { tones.removeAll() }
        tones[key] = tone
    }
}
