//
//  RemoteImage.swift
//  HotMess
//

import Kingfisher
import SwiftUI

/// A cached remote image with a consistent placeholder.
///
/// Every image in the old app was a `UIImageView` plus a `kf.setImage` call
/// with a force-unwrapped URL; a missing cover photo took the screen down.
struct RemoteImage: View {
    let url: URL?
    var contentMode: SwiftUI.ContentMode = .fill

    var body: some View {
        Group {
            if let url {
                KFImage(url)
                    .cancelOnDisappear(true)
                    .fade(duration: 0.2)
                    .placeholder { placeholder }
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else {
                placeholder
            }
        }
        .clipped()
    }

    private var placeholder: some View {
        Rectangle()
            .fill(.quaternary)
            .overlay {
                Image(systemName: "photo")
                    .imageScale(.large)
                    .foregroundStyle(.tertiary)
            }
    }
}

/// A circular avatar that falls back to initials.
struct Avatar: View {
    let url: URL?
    var initials: String?
    var size: CGFloat = 44
    /// Whether the person can be reached now. `nil` (the default) draws no dot.
    var presence: PresenceState? = nil
    /// The ring between the presence dot and the photo: the surface behind the avatar.
    var presenceRing: Color = Color(.secondarySystemGroupedBackground)
    /// A place, not a person (a post as the venue): a `radius-md` rounded
    /// square, so places never look like people.
    var isPlace = false

    var body: some View {
        Group {
            if let url {
                KFImage(url)
                    .cancelOnDisappear(true)
                    .placeholder { fallback }
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                fallback
            }
        }
        .frame(width: size, height: size)
        .clipShape(isPlace ? AnyShape(Self.placeShape) : AnyShape(Circle()))
        .overlay {
            if isPlace {
                Self.placeShape.strokeBorder(.separator, lineWidth: 0.5)
            } else {
                Circle().strokeBorder(.separator, lineWidth: 0.5)
            }
        }
        .overlay(alignment: .bottomTrailing) {
            if let presence {
                // The dot's 2pt ring sits 1pt outside the avatar's edge.
                PresenceDot(state: presence, size: size >= 40 ? 12 : 10, ringColor: presenceRing)
                    .offset(x: 1, y: 1)
            }
        }
    }

    private static var placeShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: HotMessRadius.md, style: .continuous)
    }

    private var fallback: some View {
        ZStack {
            Rectangle().fill(.quaternary)

            if let initials, !initials.isEmpty {
                Text(initials)
                    .font(.hotMess(fixedSize: size * 0.38, semibold: true))
                    .foregroundStyle(.secondary)
            } else {
                Image(systemName: isPlace ? "building.2.fill" : "person.fill")
                    .font(.system(size: size * 0.45))
                    .foregroundStyle(.tertiary)
            }
        }
    }
}
