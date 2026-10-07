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
