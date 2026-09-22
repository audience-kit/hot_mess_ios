//
//  Rows.swift
//  HotMess
//

import SwiftUI

/// A date badge in the brand's month-over-day style.
struct DateBadge: View {
    let date: Date

    var body: some View {
        VStack(spacing: 0) {
            Text(date.formatted(.dateTime.month(.abbreviated)).uppercased())
                .font(.hotMess(.caption2, semibold: true))
                .foregroundStyle(Color.hotMessAccent)

            Text(date.formatted(.dateTime.day()))
                .font(.hotMess(.title2, semibold: true))
                .foregroundStyle(.primary)
        }
        .frame(width: 44)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(date.formatted(date: .abbreviated, time: .omitted))
    }
}

struct EventRow: View {
    let event: Event

    var body: some View {
        HStack(spacing: 12) {
            DateBadge(date: event.startDate)

            VStack(alignment: .leading, spacing: 2) {
                Text(event.name)
                    .font(.hotMess(.headline, semibold: true))
                    .lineLimit(2)

                Text(event.subtitle)
                    .font(.hotMess(.subheadline))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            if event.rsvp != .unsure {
                Image(systemName: event.rsvp.systemImage)
                    .foregroundStyle(Color.hotMessAccent)
                    .accessibilityLabel(event.rsvp.title)
            }
        }
        .padding(.vertical, 4)
    }
}

/// The taller treatment used for events the API flags as featured.
struct FeaturedEventRow: View {
    let event: Event

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            RemoteImage(url: event.coverURL)
                .frame(height: 140)
                .clipShape(.rect(cornerRadius: 12))

            EventRow(event: event)
                .padding(.top, 8)
        }
        .padding(.vertical, 4)
    }
}

struct VenueRow: View {
    let venue: Venue

    var body: some View {
        HStack(spacing: 12) {
            RemoteImage(url: venue.photoURL)
                .frame(width: 56, height: 56)
                .clipShape(.rect(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 2) {
                Text(venue.name)
                    .font(.hotMess(.headline, semibold: true))
                    .lineLimit(1)

                Text(venue.summary)
                    .font(.hotMess(.subheadline))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 8)

            if let distance = venue.distance {
                Text(DistanceFormat.string(fromMetres: distance))
                    .font(.hotMess(.caption))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
        .padding(.vertical, 4)
    }
}

struct PersonRow: View {
    let person: Person

    var body: some View {
        HStack(spacing: 12) {
            Avatar(url: person.pictureURL, initials: person.name.initialsForDisplay)

            VStack(alignment: .leading, spacing: 2) {
                Text(person.name)
                    .font(.hotMess(.headline, semibold: true))

                if let role = person.role, !role.isEmpty {
                    Text(role)
                        .font(.hotMess(.subheadline))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

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
