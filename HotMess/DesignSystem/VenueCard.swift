//
//  VenueCard.swift
//  HotMess
//

import Kingfisher
import SwiftUI

enum CardMetrics {
    static let photoHeight: CGFloat = 132
    static let spacing: CGFloat = 12

    static var cornerRadius: CGFloat {
        if #available(iOS 26, *) {
            return 26
        }
        return 12
    }
}

/// A venue drawn as its own photo, with the name and details written over it in
/// whichever colour that photo can carry, like a small hero.
///
/// `pill` sits top right on dark glass (a distance, a friend count) and
/// `corner` sits top left (friend faces). With no photo the card is the accent
/// gradient with white text.
struct VenueCard<Corner: View>: View {
    let venue: Venue
    var detail: String?
    var pill: String?
    @ViewBuilder var corner: Corner

    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    @State private var tone = HeroTone.placeholder
    @State private var image: UIImage?
    @State private var size: CGSize = .zero
    @State private var textFrame: CGRect = .zero

    private static var space: String { "venueCard" }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(venue.name)
                .font(.hotMess(.title3, semibold: true))
                .lineLimit(2)

            Text(detail ?? venue.summary)
                .font(.hotMess(.subheadline, semibold: true))
                .lineLimit(2)
        }
        .foregroundStyle(tone.textColor)
        .animation(.easeOut(duration: 0.15), value: tone)
        .onGeometryChange(for: CGRect.self) { $0.frame(in: .named(Self.space)) } action: { textFrame = $0 }
        .padding(.horizontal, 18)
        .padding(.top, 52)
        .padding(.bottom, 14)
        .frame(maxWidth: .infinity, minHeight: CardMetrics.photoHeight, alignment: .bottomLeading)
        .coordinateSpace(.named(Self.space))
        .onGeometryChange(for: CGSize.self) { $0.size } action: { size = $0 }
        .background {
            photo
                .overlay { scrim }
                .clipped()
        }
        .overlay(alignment: .topLeading) {
            corner.padding(12)
        }
        .overlay(alignment: .topTrailing) {
            if let pill {
                Text(pill)
                    .font(.hotMess(.footnote, semibold: true))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color(red: 0.11, green: 0.08, blue: 0.10).opacity(0.55), in: .capsule)
                    .background(.ultraThinMaterial, in: .capsule)
                    .environment(\.colorScheme, .dark)
                    .padding(12)
            }
        }
        .clipShape(.rect(cornerRadius: CardMetrics.cornerRadius))
        .contentShape(.rect(cornerRadius: CardMetrics.cornerRadius))
        .accessibilityElement(children: .combine)
        .task(id: venue.photoURL) { await loadImage() }
        .onChange(of: analysisKey, initial: true) { analyze() }
    }

    // MARK: - Layers

    @ViewBuilder
    private var photo: some View {
        if let url = venue.photoURL {
            // No fade, for the same reason as the hero: the scrim and text are
            // drawn at once.
            KFImage(url)
                .cancelOnDisappear(true)
                .placeholder { Color(red: 0.16, green: 0.12, blue: 0.15) }
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else {
            LinearGradient(
                colors: [Color.hotMessAccent, Color.hotMessAccent.mix(with: .black, by: 0.25)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .environment(\.colorScheme, .light)
        }
    }

    private var scrim: some View {
        LinearGradient(
            stops: [
                .init(color: tone.scrimColor.opacity(tone.scrim), location: 0),
                .init(color: tone.scrimColor.opacity(tone.scrim), location: bandFraction),
                .init(color: tone.scrimColor.opacity(0), location: 1),
            ],
            startPoint: .bottom,
            endPoint: .top
        )
        .frame(height: min(size.height, bandHeight + 40))
        .frame(maxHeight: .infinity, alignment: .bottom)
        .allowsHitTesting(false)
        .animation(.easeOut(duration: 0.15), value: tone)
    }

    // MARK: - Analysis

    private var bandHeight: CGFloat { max(0, size.height - textFrame.minY + 8) }
    private var bandFraction: CGFloat { bandHeight / max(1, min(size.height, bandHeight + 40)) }

    private var increasedContrast: Bool { colorSchemeContrast == .increased }
    private var target: Double { increasedContrast ? 7 : 4.5 }
    private var scrimFloor: Double { increasedContrast || reduceTransparency ? 0.3 : 0 }

    private var cacheKey: String? {
        venue.photoURL.map { "card|\($0.absoluteString)|\(target)|\(scrimFloor)" }
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
        guard let url = venue.photoURL else { return }
        if let key = cacheKey, let cached = HeroToneCache.tone(for: key) {
            tone = cached
        }
        image = try? await KingfisherManager.shared.retrieveImage(with: url).image
    }

    private func analyze() {
        guard venue.photoURL != nil else {
            tone = .placeholder
            return
        }
        guard
            let cgImage = image?.cgImage,
            size.width > 0, size.height > 0, textFrame.height > 0
        else { return }

        // A card has no status bar, so the band stands in for the top area too.
        let band = CGRect(x: 14, y: max(0, textFrame.minY - 8), width: size.width - 28, height: bandHeight)
        guard let decided = ImageTone.analyze(
            cgImage,
            viewSize: size,
            top: band,
            band: band,
            target: target,
            scrimFloor: scrimFloor
        ) else { return }

        tone = decided
        if let key = cacheKey { HeroToneCache.store(decided, for: key) }
    }
}

extension VenueCard where Corner == EmptyView {
    init(venue: Venue, detail: String? = nil, pill: String?) {
        self.init(venue: venue, detail: detail, pill: pill) { EmptyView() }
    }

    /// The card for a venue list: its summary, and how far away it is.
    init(venue: Venue) {
        self.init(
            venue: venue,
            pill: venue.distance.map { DistanceFormat.string(fromMetres: $0) }
        )
    }
}

/// Overlapping friend photos, for the corner of a `VenueCard`.
struct FriendFaces: View {
    let friends: [Friend]
    var limit = 4

    @Environment(AppModel.self) private var model

    var body: some View {
        HStack(spacing: -7) {
            ForEach(friends.prefix(limit)) { friend in
                Avatar(
                    url: model.configuration.avatarURL(forUserID: friend.id),
                    initials: friend.name.initialsForDisplay,
                    size: 26
                )
                .overlay { Circle().strokeBorder(.white.opacity(0.9), lineWidth: 2) }
            }
        }
        .accessibilityHidden(true)
    }
}

/// A titled stack of cards for screens that scroll in a `ScrollView`. Unlike
/// `DetailSection` the rows bring their own background. A section with no rows
/// draws nothing, header included.
struct CardSection<Content: View>: View {
    let title: String?
    let content: Content

    init(_ title: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        Group(subviews: content) { rows in
            if !rows.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    if let title {
                        Text(title)
                            .font(.hotMess(.subheadline, semibold: true))
                            .foregroundStyle(.secondary)
                            .accessibilityAddTraits(.isHeader)
                            .padding(.horizontal, 20)
                    }

                    LazyVStack(spacing: CardMetrics.spacing) {
                        ForEach(rows) { $0 }
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }
}

/// A `VenueCard` that opens the venue.
struct VenueCardLink<Card: View>: View {
    let venue: Venue
    @ViewBuilder var card: Card

    var body: some View {
        NavigationLink(value: AppRoute.venue(venue.id)) {
            card
        }
        .buttonStyle(.plain)
    }
}

extension VenueCardLink where Card == VenueCard<EmptyView> {
    init(venue: Venue) {
        self.init(venue: venue) { VenueCard(venue: venue) }
    }
}
