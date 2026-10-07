//
//  Rows.swift
//  HotMess
//

import SwiftUI

struct TrackRow: View {
    let track: Track

    var body: some View {
        HStack(spacing: 12) {
            RemoteImage(url: track.artworkURL)
                .frame(width: 64, height: 64)
                .clipShape(.rect(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 6) {
                Text(track.title)
                    .font(.hotMess(.headline, semibold: true))
                    .lineLimit(2)

                if let waveformURL = track.waveformURL {
                    RemoteImage(url: waveformURL, contentMode: .fit)
                        .frame(height: 28)
                        .opacity(0.7)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

/// A label-and-value row, replacing the repeated `textLabel`/`detailTextLabel`
/// cell configuration scattered through the old table view controllers.
struct InfoRow: View {
    let title: String
    let value: String?
    var systemImage: String?

    var body: some View {
        LabeledContent {
            if let value {
                Text(value)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.trailing)
            }
        } label: {
            if let systemImage {
                Label(title, systemImage: systemImage)
            } else {
                Text(title)
            }
        }
    }
}

/// A person's or venue's link elsewhere, with the network's glyph. Opens the
/// link when it has a URL.
struct SocialLinkRow: View {
    let link: SocialLink

    var body: some View {
        if let url = link.url {
            Link(destination: url) {
                HStack(spacing: 12) {
                    icon
                    Text(verbatim: link.label)
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.footnote)
                        .foregroundStyle(.tertiary)
                }
            }
        } else {
            HStack(spacing: 12) {
                icon
                Text(verbatim: link.label)
            }
        }
    }

    @ViewBuilder
    private var icon: some View {
        if let assetName = link.assetName {
            Image(assetName)
                .resizable()
                .scaledToFit()
                .frame(width: 24, height: 24)
                .clipShape(.rect(cornerRadius: 4))
        } else {
            Image(systemName: link.systemImage)
                .frame(width: 24, height: 24)
                .foregroundStyle(.secondary)
        }
    }
}
