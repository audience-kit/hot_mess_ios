//
//  HeroHeader.swift
//  HotMess
//

import Kingfisher
import SwiftUI

enum HeroMetrics {
    /// The photo's height below the status and navigation bars.
    static let bodyHeight: CGFloat = 256
}

/// A cover photo that runs edge to edge and up under the status bar, with its
/// title drawn over it in whichever colour the photo can carry.
///
/// Put it first in a `ScrollView` that ignores the top safe area, and pass that
/// safe area's height as `topInset`. The photo stretches when pulled down.
/// `tone` reports what was decided so the screen can style its bars to match.
struct HeroHeader<Content: View>: View {
    let url: URL?
    let topInset: CGFloat
    @Binding var tone: HeroTone
    @ViewBuilder var content: Content

    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    @State private var image: UIImage?
    @State private var size: CGSize = .zero
    @State private var textFrame: CGRect = .zero

    private static var space: String { "hero" }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer(minLength: topInset + 16)

            content
                .foregroundStyle(tone.textColor)
                .onGeometryChange(for: CGRect.self) { $0.frame(in: .named(Self.space)) } action: { textFrame = $0 }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
                .animation(.easeOut(duration: 0.15), value: tone)
        }
        .frame(maxWidth: .infinity, minHeight: topInset + HeroMetrics.bodyHeight, alignment: .bottomLeading)
        .coordinateSpace(.named(Self.space))
        .onGeometryChange(for: CGSize.self) { $0.size } action: { size = $0 }
        .background {
            GeometryReader { proxy in
                let pull = max(0, proxy.frame(in: .scrollView).minY)
                photo
                    .frame(width: proxy.size.width, height: proxy.size.height + pull)
                    .clipped()
                    .overlay { scrims }
                    .offset(y: -pull)
            }
        }
        .task(id: url) { await loadImage() }
        .onChange(of: analysisKey, initial: true) { analyze() }
    }

    // MARK: - Layers

    @ViewBuilder
    private var photo: some View {
        if let url {
            // No fade: the scrim and text are drawn at once, so a fading photo
            // read as only the part behind the text having loaded.
            KFImage(url)
                .cancelOnDisappear(true)
                .placeholder { Color(red: 0.16, green: 0.12, blue: 0.15) }
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else {
            // The light accent always carries white text (on-accent).
            LinearGradient(
                colors: [Color.hotMessAccent, Color.hotMessAccent.mix(with: .black, by: 0.25)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .environment(\.colorScheme, .light)
        }
    }

    private var scrims: some View {
        VStack(spacing: 0) {
            LinearGradient(
                colors: [tone.barScrimColor.opacity(tone.barScrim), tone.barScrimColor.opacity(0)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: topInset + 40)

            Spacer(minLength: 0)

            LinearGradient(
                stops: [
                    .init(color: tone.scrimColor.opacity(tone.scrim), location: 0),
                    .init(color: tone.scrimColor.opacity(tone.scrim), location: bandFraction),
                    .init(color: tone.scrimColor.opacity(0), location: 1),
                ],
                startPoint: .bottom,
                endPoint: .top
            )
            .frame(height: bandHeight + 90)
        }
        .allowsHitTesting(false)
        .animation(.easeOut(duration: 0.15), value: tone)
    }

    // MARK: - Analysis

    private var bandHeight: CGFloat { max(0, size.height - textFrame.minY + 8) }
    private var bandFraction: CGFloat { bandHeight / max(1, bandHeight + 90) }

    private var increasedContrast: Bool { colorSchemeContrast == .increased }
    private var target: Double { increasedContrast ? 7 : 4.5 }
    private var scrimFloor: Double { increasedContrast || reduceTransparency ? 0.3 : 0 }

    private var cacheKey: String? {
        url.map { "\($0.absoluteString)|\(target)|\(scrimFloor)" }
    }

    private struct AnalysisKey: Equatable {
        var hasImage: Bool
        var size: CGSize
        var textFrame: CGRect
        var target: Double
        var scrimFloor: Double
    }

    private var analysisKey: AnalysisKey {
        AnalysisKey(hasImage: image != nil, size: size, textFrame: textFrame, target: target, scrimFloor: scrimFloor)
    }

    private func loadImage() async {
        image = nil
        guard let url else { return }
        if let key = cacheKey, let cached = HeroToneCache.tone(for: key) {
            tone = cached
        }
        image = try? await KingfisherManager.shared.retrieveImage(with: url).image
    }

    private func analyze() {
        guard url != nil else {
            tone = .placeholder
            return
        }
        guard
            let cgImage = image?.cgImage,
            size.width > 0, size.height > 0, textFrame.height > 0
        else { return }

        let top = CGRect(x: 0, y: 0, width: size.width, height: topInset)
        let band = CGRect(x: 16, y: textFrame.minY - 8, width: size.width - 32, height: bandHeight)

        guard let decided = ImageTone.analyze(
            cgImage,
            viewSize: size,
            top: top,
            band: band,
            target: target,
            scrimFloor: scrimFloor
        ) else { return }

        tone = decided
        if let key = cacheKey { HeroToneCache.store(decided, for: key) }
    }
}

extension View {
    /// Styles the navigation bar for a screen that opens on a `HeroHeader`: clear
    /// with the status bar matching the photo, then a material bar with `title`
    /// once the hero has scrolled away.
    func heroNavigationBar(title: String, tone: HeroTone, collapsed: Bool) -> some View {
        navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(title)
                        .font(.hotMess(.headline, semibold: true))
                        .lineLimit(1)
                        .opacity(collapsed ? 1 : 0)
                        .accessibilityHidden(!collapsed)
                }
            }
            // A visible but clear background is what lets the colour scheme reach
            // the status bar while the photo shows through.
            .toolbarBackground(collapsed ? AnyShapeStyle(Material.bar) : AnyShapeStyle(Color.clear), for: .navigationBar)
            .toolbarBackgroundVisibility(.visible, for: .navigationBar)
            .toolbarColorScheme(collapsed ? nil : tone.bar, for: .navigationBar)
            .modifier(HeroScrollEdge(hidden: !collapsed))
            .animation(.easeOut(duration: 0.15), value: collapsed)
    }

    /// Tracks whether a hero at the top of this scroll view has scrolled under the bars.
    func trackingHeroCollapse(_ collapsed: Binding<Bool>) -> some View {
        onScrollGeometryChange(for: Bool.self) { geometry in
            geometry.contentOffset.y + geometry.contentInsets.top > HeroMetrics.bodyHeight - 8
        } action: { _, isCollapsed in
            collapsed.wrappedValue = isCollapsed
        }
    }
}

/// iOS 26 blurs and fades scroll content under the navigation bar, which cut a
/// sharp line across the hero photo where the effect ended. The photo is the
/// bar's background while the hero shows, so the effect is off until it scrolls away.
private struct HeroScrollEdge: ViewModifier {
    let hidden: Bool

    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content.scrollEdgeEffectHidden(hidden, for: .top)
        } else {
            content
        }
    }
}
