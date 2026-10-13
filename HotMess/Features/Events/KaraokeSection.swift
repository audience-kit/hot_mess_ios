import SwiftUI

struct KaraokeSection: View {
    let karaoke: KaraokeNight
    var body: some View {
        DetailSection(String(localized: "Karaoke")) {
            Label(String(localized: "Karaoke night"), systemImage: "music.mic")
            if let provider = karaoke.providerName { Text(provider).foregroundStyle(.secondary) }
            if let url = karaoke.joinURL {
                Link(destination: url) { Label(String(localized: "Join karaoke"), systemImage: "music.note.list") }
                    .accessibilityIdentifier("karaoke.join")
                if let code = karaoke.sessionCode { Text(String(localized: "Session: \(code)")).font(.caption).foregroundStyle(.secondary) }
            } else {
                Text(String(localized: "Ask the host how to join the karaoke session.")).foregroundStyle(.secondary)
            }
        }
    }
}
