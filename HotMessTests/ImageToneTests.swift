//
//  ImageToneTests.swift
//  HotMessTests
//

import CoreGraphics
import SwiftUI
import Testing

@testable import HotMess

/// A solid or two-colour test image, drawn top-left origin like the photos it stands in for.
private func image(width: Int = 64, height: Int = 64, fill: (Int, Int) -> UInt8) throws -> CGImage {
    var pixels = [UInt8](repeating: 255, count: width * height * 4)
    for y in 0 ..< height {
        for x in 0 ..< width {
            let value = fill(x, y)
            let index = (y * width + x) * 4
            pixels[index] = value
            pixels[index + 1] = value
            pixels[index + 2] = value
        }
    }
    let space = try #require(CGColorSpace(name: CGColorSpace.sRGB))
    let provider = try #require(CGDataProvider(data: Data(pixels) as CFData))
    return try #require(CGImage(
        width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: width * 4,
        space: space, bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue),
        provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent
    ))
}

@Suite("Hero tone")
struct ImageToneTests {
    private let size = CGSize(width: 64, height: 64)
    private let top = CGRect(x: 0, y: 0, width: 64, height: 16)
    private let band = CGRect(x: 0, y: 40, width: 64, height: 24)

    @Test("A dark photo gets white text and a white status bar, with no scrim")
    func darkPhoto() throws {
        let tone = try #require(ImageTone.analyze(try image { _, _ in 20 }, viewSize: size, top: top, band: band))

        #expect(tone.text == .light)
        #expect(tone.scrim == 0)
        #expect(tone.bar == .dark)
    }

    @Test("A bright photo gets dark text and a dark status bar, with no scrim")
    func brightPhoto() throws {
        let tone = try #require(ImageTone.analyze(try image { _, _ in 240 }, viewSize: size, top: top, band: band))

        #expect(tone.text == .dark)
        #expect(tone.scrim == 0)
        #expect(tone.bar == .light)
    }

    @Test("Bright sky over a dark street reads each area on its own")
    func splitPhoto() throws {
        let tone = try #require(ImageTone.analyze(try image { _, y in y < 32 ? 245 : 15 }, viewSize: size, top: top, band: band))

        #expect(tone.bar == .light)
        #expect(tone.text == .light)
        #expect(tone.scrim == 0)
    }

    @Test("A busy photo keeps white text and gets just enough dark scrim")
    func busyPhoto() throws {
        // Black and white stripes: neither text colour reads without help.
        let tone = try #require(ImageTone.analyze(try image { x, _ in (x / 8) % 2 == 0 ? 0 : 255 }, viewSize: size, top: top, band: band))

        #expect(tone.text == .light)
        #expect(tone.scrim > 0.7)
        #expect(tone.scrim <= ImageTone.maxScrim)
    }

    @Test("City lights at night get white text over at least the busy scrim")
    func cityLights() throws {
        // A dark skyline with a few small bright windows: dark enough on average to
        // pass 4.5:1, but letters crossing the lights still need a scrim.
        let tone = try #require(ImageTone.analyze(
            try image { x, y in x % 5 == 0 && y % 3 == 0 ? 250 : 25 },
            viewSize: size, top: top, band: band
        ))

        #expect(tone.text == .light)
        #expect(tone.scrim >= ImageTone.busyScrim)
    }

    @Test("The scrim brings white text to exactly the target")
    func scrimMeetsTarget() {
        // At 0.2 neither white (4.2:1) nor the dark ink (4.1:1) reaches 4.5:1 unaided;
        // a mid-grey would already pass with dark ink and get no scrim.
        let tone = ImageTone.decide(top: [0], band: Array(repeating: 0.2, count: 100))
        let darkened = 0.2 * (1 - tone.scrim)

        #expect(tone.text == .light)
        #expect(abs(ImageTone.contrast(1, darkened) - 4.5) < 0.001)
    }

    @Test("Increase Contrast raises the target and keeps a scrim floor")
    func increasedContrast() {
        let normal = ImageTone.decide(top: [0], band: Array(repeating: 0.12, count: 100))
        let increased = ImageTone.decide(top: [0], band: Array(repeating: 0.12, count: 100), target: 7, scrimFloor: 0.3)

        #expect(normal.scrim == 0)
        #expect(increased.text == .light)
        #expect(increased.scrim >= 0.3)
        #expect(ImageTone.contrast(1, 0.12 * (1 - increased.scrim)) >= 7)
    }

    @Test("Sampling follows the aspect-fill crop")
    func aspectFillCrop() {
        // A 200×100 image filling a 100×100 view loses 50 pixels each side.
        let rect = ImageTone.imageRect(
            for: CGRect(x: 0, y: 0, width: 100, height: 100),
            imageSize: CGSize(width: 200, height: 100),
            viewSize: CGSize(width: 100, height: 100)
        )

        #expect(rect == CGRect(x: 50, y: 0, width: 100, height: 100))
    }

    @Test("Luminance matches the WCAG formula at the ends and for the ink token")
    func luminance() {
        #expect(ImageTone.luminance(red: 0, green: 0, blue: 0) == 0)
        #expect(abs(ImageTone.luminance(red: 255, green: 255, blue: 255) - 1) < 0.0001)
        #expect(abs(ImageTone.luminance(red: 0x24, green: 0x16, blue: 0x1D) - ImageTone.inkLuminance) < 0.0005)
    }
}
