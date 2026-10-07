//
//  RSVPPicker.swift
//  HotMess
//

import SwiftUI

/// The design system's RSVP picker: Going, Interested and Not going side by
/// side, each an icon over its word. The chosen one sits on `accent-soft` with
/// `accent-ink` text in the label weight; the others are `ink-muted`. The same
/// component is `RsvpPicker` on Android.
///
/// Replaces `RSVPTableViewCell`, which reached straight into `DataService`,
/// mutated the event in place and mis-spelled one of its own states.
struct RSVPPicker: View {
    let selection: RSVP
    let onSelect: (RSVP) -> Void

    var body: some View {
        HStack(spacing: 8) {
            ForEach(RSVP.selectable, id: \.self) { rsvp in
                let selected = rsvp == selection
                Button {
                    onSelect(rsvp)
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: rsvp.systemImage)
                            .font(.title2)
                        Text(rsvp.title)
                            .font(.hotMess(.footnote, weight: selected ? .semibold : .regular))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .padding(.vertical, 8)
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .foregroundStyle(selected ? Color.hotMessAccentInk : .secondary)
                .background(
                    selected ? Color.hotMessAccentSoft : .clear,
                    in: .rect(cornerRadius: HotMessRadius.md)
                )
                .accessibilityAddTraits(selected ? [.isSelected, .isButton] : .isButton)
            }
        }
        .padding(.vertical, 4)
        .sensoryFeedback(.selection, trigger: selection)
    }
}

/// Your RSVP as a pill over an event's photo, shown only for Going and
/// Interested so a card never shouts "Not going".
struct RSVPBadge: View {
    let rsvp: RSVP

    var body: some View {
        if rsvp == .attending || rsvp == .maybe {
            GlassPill {
                Label(rsvp.title, systemImage: rsvp.systemImage)
                    .font(.hotMess(.footnote, semibold: true))
            }
        }
    }
}

#Preview {
    @Previewable @State var selection = RSVP.maybe
    VStack(spacing: 24) {
        DetailSection("Your RSVP") {
            RSVPPicker(selection: selection) { selection = $0 }
        }
        RSVPBadge(rsvp: selection)
            .padding()
            .background(.black)
    }
}
