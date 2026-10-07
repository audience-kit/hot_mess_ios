//
//  PhotoCard.swift
//  HotMess
//

import Kingfisher
import SwiftUI

enum CardMetrics {
    static let photoHeight: CGFloat = 132
    static let featuredHeight: CGFloat = 180
    static let personHeight: CGFloat = 84
    static let spacing: CGFloat = 12

    /// `radius-photo`.
    static var cornerRadius: CGFloat { HotMessRadius.photo }
}

/// A rounded card filled by a photo, with its text written over it in whichever
/// colour the photo can carry, like a small hero.
///
/// The area behind `content` is read with the hero's brightness check: white
/// text when it reaches the target, dark text only when the photo needs no
/// scrim, otherwise white text over the lightest scrim that does. `leading` and
/// `trailing` sit in the top corners and bring their own backgrounds. With no
/// photo the card is the accent gradient with white text.
struct PhotoCard<Content: View, Leading: View, Trailing: View>: View {
    let url: URL?
    var minHeight: CGFloat = CardMetrics.photoHeight
    /// Space kept clear above the text for the corner badges.
    var topClearance: CGFloat = 52
    /// Blurs the photo, for pictures too small or square to fill the card sharply.
    var blur: CGFloat = 0
    var alignment: Alignment = .bottomLeading
    /// `radius-photo`, or `radius-bubble` for an event shared in chat.
    var cornerRadius: CGFloat = CardMetrics.cornerRadius
    @ViewBuilder var content: Content
    @ViewBuilder var leading: Leading
    @ViewBuilder var trailing: Trailing

    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    @State private var tone = HeroTone.placeholder
    @State private var image: UIImage?
    @State private var size: CGSize = .zero
    @State private var textFrame: CGRect = .zero

    private static var space: String { "photoCard" }

    var body: some View {
        content
            .foregroundStyle(tone.textColor)
            .photoTextShadow(tone)
            .animation(HotMessMotion.quick, value: tone)
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .named(Self.space)) } action: { textFrame = $0 }
            .padding(.horizontal, 18)
            .padding(.top, topClearance)
            .padding(.bottom, 14)
            .frame(maxWidth: .infinity, minHeight: minHeight, alignment: alignment)
            .coordinateSpace(.named(Self.space))
            .onGeometryChange(for: CGSize.self) { $0.size } action: { size = $0 }
            .background {
                photo
                    .overlay { scrim }
                    .clipped()
            }
            .overlay(alignment: .topLeading) {
                leading.padding(12)
            }
            .overlay(alignment: .topTrailing) {
                trailing.padding(12)
            }
            .clipShape(.rect(cornerRadius: cornerRadius))
            .contentShape(.rect(cornerRadius: cornerRadius))
            .accessibilityElement(children: .combine)
            .task(id: url) { await loadImage() }
            .onChange(of: analysisKey, initial: true) { analyze() }
    }

    // MARK: - Layers

    @ViewBuilder
    private var photo: some View {
        if let url {
            // No fade, for the same reason as the hero: the scrim and text are
            // drawn at once.
            KFImage(url)
                .cancelOnDisappear(true)
                .placeholder { Color.hotMessPhotoPlaceholder }
                .resizable()
                .aspectRatio(contentMode: .fill)
                .blur(radius: blur, opaque: true)
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
        .frame(height: scrimHeight)
        .frame(maxHeight: .infinity, alignment: .bottom)
        .allowsHitTesting(false)
        .animation(HotMessMotion.quick, value: tone)
    }

    // MARK: - Analysis

    private var bandHeight: CGFloat { max(0, size.height - textFrame.minY + 8) }
    private var scrimHeight: CGFloat { min(size.height, bandHeight + 40) }
    private var bandFraction: CGFloat { min(1, bandHeight / max(1, scrimHeight)) }

    private var increasedContrast: Bool { colorSchemeContrast == .increased }
    private var target: Double { increasedContrast ? 7 : 4.5 }
    private var scrimFloor: Double { increasedContrast || reduceTransparency ? ImageTone.accessibleScrimFloor : 0 }

    private var cacheKey: String? {
        url.map { "card|\(minHeight)|\(blur)|\($0.absoluteString)|\(target)|\(scrimFloor)" }
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

        // A card has no status bar, so the band stands in for the top area too.
        // A blurred photo is judged unblurred, which can only overestimate the
        // brightest pixels, so the scrim errs on the dark side.
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

// MARK: - Badges

/// A small label on dark glass, for a card's top corners. It reads on any
/// photo, so it needs no brightness check of its own.
struct GlassPill<PillContent: View>: View {
    var padding = EdgeInsets(top: 5, leading: 10, bottom: 5, trailing: 10)
    var shape: AnyShape = AnyShape(Capsule())
    @ViewBuilder var content: PillContent

    var body: some View {
        content
            .foregroundStyle(.white)
            .padding(padding)
            .background(Color.hotMessGlass, in: shape)
            .background(.ultraThinMaterial, in: shape)
            .environment(\.colorScheme, .dark)
    }
}

extension GlassPill where PillContent == Text {
    init(_ text: String) {
        self.init {
            Text(text)
                .font(.hotMess(.footnote, semibold: true))
                .monospacedDigit()
        }
    }
}

/// Overlapping friend photos, for the corner of a `VenueCard`.
struct FriendFaces: View {
    let friends: [Friend]
    var limit = 4

    @Environment(AppModel.self) private var model

    var body: some View {
        HStack(spacing: -7) {
            ForEach(Array(friends.prefix(limit).enumerated()), id: \.element.id) { index, friend in
                Avatar(
                    url: model.configuration.avatarURL(forUserID: friend.id),
                    initials: friend.name.initialsForDisplay,
                    size: 26
                )
                .overlay { Circle().strokeBorder(Color.hotMessAvatarRing, lineWidth: 2) }
                // Drawn over the ring, which would otherwise cover half of it.
                .overlay(alignment: .bottomTrailing) {
                    if let presence = friend.presence {
                        PresenceDot(state: presence, size: 8, ringColor: Color.hotMessAvatarRing)
                            .offset(x: 1, y: 1)
                    }
                }
                // Each face over the next, so its presence dot isn't hidden.
                .zIndex(Double(limit - index))
            }
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Venues

/// A venue as a photo card: its name and summary over its photo, with a pill
/// top right (a distance, a friend count) and `corner` top left (friend faces).
struct VenueCard<Corner: View>: View {
    let venue: Venue
    var detail: String?
    var pill: String?
    @ViewBuilder var corner: Corner

    var body: some View {
        PhotoCard(url: venue.photoURL) {
            VStack(alignment: .leading, spacing: 2) {
                Text(venue.name)
                    .font(.hotMess(.title3, semibold: true))
                    .lineLimit(2)

                Text(detail ?? venue.summary)
                    .font(.hotMess(.subheadline, semibold: true))
                    .lineLimit(2)
            }
        } leading: {
            corner
        } trailing: {
            if let pill {
                GlassPill(pill)
            }
        }
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

// MARK: - Events

/// An event as a photo card over its cover: the date top left, your RSVP top
/// right, and the name with when and where at the bottom. Featured events are taller.
struct EventCard: View {
    let event: Event

    var body: some View {
        PhotoCard(
            url: event.coverURL,
            minHeight: event.isFeatured ? CardMetrics.featuredHeight : CardMetrics.photoHeight,
            topClearance: 68
        ) {
            VStack(alignment: .leading, spacing: 2) {
                Text(event.name)
                    .font(.hotMess(event.isFeatured ? .title2 : .title3, semibold: true))
                    .lineLimit(2)

                Text(event.subtitle)
                    .font(.hotMess(.subheadline, semibold: true))
                    .lineLimit(1)
            }
        } leading: {
            GlassPill(padding: EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8), shape: AnyShape(RoundedRectangle(cornerRadius: HotMessRadius.md))) {
                VStack(spacing: 0) {
                    Text(event.startDate.formatted(.dateTime.month(.abbreviated)).uppercased())
                        .font(.hotMess(.caption2, semibold: true))
                    Text(event.startDate.formatted(.dateTime.day()))
                        .font(.hotMess(.title3, semibold: true))
                        .monospacedDigit()
                }
                .frame(minWidth: 30)
            }
            .accessibilityLabel(event.startDate.formatted(date: .abbreviated, time: .omitted))
        } trailing: {
            if event.rsvp == .attending || event.rsvp == .maybe {
                GlassPill {
                    Label(event.rsvp.title, systemImage: event.rsvp.systemImage)
                        .font(.hotMess(.footnote, semibold: true))
                }
            }
        }
    }
}

/// An `EventCard` that opens the event.
struct EventCardLink: View {
    let event: Event

    var body: some View {
        NavigationLink(value: AppRoute.event(event.id)) {
            EventCard(event: event)
        }
        .buttonStyle(.plain)
    }
}

/// An event shared in a chat room (RichMessage "event"): a card for the
/// event, an optional caption, and "See event". The room sends only the
/// event's name and start, so the card wears the accent rather than a photo.
/// Tapping the card or the button opens the event.
struct SharedEventMessage: View {
    let event: SharedEvent
    let caption: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            NavigationLink(value: AppRoute.event(event.id)) {
                card
            }
            .buttonStyle(.plain)

            if let caption {
                Text(caption)
                    .font(.hotMess(.subheadline))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 4)
                    .textSelection(.enabled)
            }

            NavigationLink(value: AppRoute.event(event.id)) {
                Text("See event")
                    .font(.hotMess(.subheadline, semibold: true))
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .tint(Color.hotMessAccentInk)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var name: String {
        event.name.flatMap { $0.isEmpty ? nil : $0 } ?? String(localized: "An event")
    }

    private var card: some View {
        PhotoCard(
            url: nil,
            minHeight: 112,
            topClearance: event.startAt == nil ? 14 : 64,
            cornerRadius: ChatMetrics.bubbleRadius
        ) {
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.hotMess(.title3, semibold: true))
                    .lineLimit(2)

                if let startAt = event.startAt {
                    Text(startAt.formatted(.dateTime.weekday(.wide).hour().minute()))
                        .font(.hotMess(.subheadline, semibold: true))
                        .lineLimit(1)
                }
            }
        } leading: {
            if let startAt = event.startAt {
                GlassPill(padding: EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8), shape: AnyShape(RoundedRectangle(cornerRadius: HotMessRadius.md))) {
                    VStack(spacing: 0) {
                        Text(startAt.formatted(.dateTime.month(.abbreviated)).uppercased())
                            .font(.hotMess(.caption2, semibold: true))
                        Text(startAt.formatted(.dateTime.day()))
                            .font(.hotMess(.title3, semibold: true))
                            .monospacedDigit()
                    }
                    .frame(minWidth: 30)
                }
                .accessibilityLabel(startAt.formatted(date: .abbreviated, time: .omitted))
            }
        } trailing: {
            EmptyView()
        }
    }
}

// MARK: - People

/// A person as a shorter card: their picture enlarged and blurred behind a sharp
/// round avatar, with their name and role (or `detail`) beside it, and `friends`
/// with them top right. Profile pictures are small square faces, so filling a
/// wide card with one sharply would crop the head and show the pixels.
struct PersonCard: View {
    let person: Person
    var detail: String?
    var friends: [Friend] = []

    var body: some View {
        PhotoCard(
            url: person.pictureURL,
            minHeight: CardMetrics.personHeight,
            topClearance: 14,
            blur: 24,
            alignment: .leading
        ) {
            HStack(spacing: 14) {
                Avatar(url: person.pictureURL, initials: person.name.initialsForDisplay, size: 56)
                    .overlay { Circle().strokeBorder(Color.hotMessAvatarRing, lineWidth: 2) }

                VStack(alignment: .leading, spacing: 2) {
                    Text(person.name)
                        .font(.hotMess(.headline, semibold: true))
                        .lineLimit(2)

                    if let line = detail ?? person.role, !line.isEmpty {
                        Text(line)
                            .font(.hotMess(.subheadline, semibold: true))
                            .lineLimit(1)
                    }
                }
            }
            .padding(.trailing, friends.isEmpty ? 0 : 64)
        } leading: {
            EmptyView()
        } trailing: {
            if !friends.isEmpty {
                FriendFaces(friends: friends, limit: 3)
            }
        }
        .accessibilityValue(friendsSummary)
    }

    private var friendsSummary: String {
        guard !friends.isEmpty else { return "" }
        let names = friends.map(\.name).formatted(.list(type: .and))
        return String(localized: "With \(names)")
    }
}

/// A `PersonCard` that opens the person.
struct PersonCardLink: View {
    let person: Person
    var detail: String?
    var friends: [Friend] = []

    var body: some View {
        NavigationLink(value: AppRoute.person(person.id)) {
            PersonCard(person: person, detail: detail, friends: friends)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Sections

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
