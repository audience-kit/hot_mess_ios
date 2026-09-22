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
        .clipShape(.circle)
        .overlay {
            Circle().strokeBorder(.separator, lineWidth: 0.5)
        }
    }

    private var fallback: some View {
        ZStack {
            Rectangle().fill(.quaternary)

            if let initials, !initials.isEmpty {
                Text(initials)
                    .font(.system(size: size * 0.38, weight: .semibold))
                    .foregroundStyle(.secondary)
            } else {
                Image(systemName: "person.fill")
                    .font(.system(size: size * 0.45))
                    .foregroundStyle(.tertiary)
            }
        }
    }
}
