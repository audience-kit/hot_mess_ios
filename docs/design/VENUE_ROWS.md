# Photo-backed venue rows

> Exported on 2026-10-08 from the design sketch artifact https://claude.ai/artifact/HvuiSBFcqhortkx6RZR5vm (drafted 2026-10-07; the interactive mockups are omitted). Built as photo cards (the "cards" layout); the shared spec is PhotoCard in audience-kit api/doc/design-system/components/PhotoCard.md.

Each venue row is its own photo, with the name and details written over it. The text color and scrim are decided per row by the same brightness check as the hero banner, so a dark club and a sunny patio can sit next to each other and both read.

## How each row works

### Readability

- **Per-row check:** the area behind the name and details is sampled after the photo loads. White text wins if it reaches 4.5:1. Dark text is used only when the photo is bright enough to need no scrim. Anything busier gets white text over the lightest dark scrim that reaches 4.5:1.
- **Distance pill:** it sits on its own dark glass, so it reads on any photo without its own check.
- **No photo:** the row uses the pink accent gradient with white text, like the hero.
- **Scrolling a long list:** results are cached by photo URL, so rows don't flicker as they scroll back into view.

### Where the row is used

- **Venues tab:** the full list under the map.
- **Now:** nearby venues, "You're at", and "Where your friends are" (with the friend faces in the corner).
- **Event screen:** the Venue section, as a single row.
- **Dynamic Type:** at large text sizes the row grows taller and the name wraps to two lines. The scrim grows with it.

### Before I build it

- **Cards or strips?** Cards keep the rounded grouped look of the rest of the app. Strips fit more venues on screen and feel more like a photo feed. I recommend cards.
- Building it would reuse the hero's brightness check as a row-sized view, and replace **VenueRow** and **FriendVenueRow** everywhere they appear.
