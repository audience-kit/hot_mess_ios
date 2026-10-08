# Photo-backed event and person rows

> Exported on 2026-10-08 from the design sketch artifact https://claude.ai/artifact/QMurtTnFVNfibNv7DCXoDC (drafted 2026-10-07; the interactive mockups are omitted). Built; featured events got the taller 180pt card. The shared spec is PhotoCard in audience-kit api/doc/design-system/components/PhotoCard.md.

Events and people get the same treatment as the approved venue rows: a rounded photo card with the text written over it, and the text color and scrim picked per row by the same brightness check. Events use their cover photo. People use a blurred copy of their profile picture behind a sharp round avatar.

## How it works

### Event rows

- **Same card as venues:** 132pt tall, radius 26, 12pt gap, 16pt side margin, with the cover photo filling the card.
- **Date badge:** month over day on dark glass in the top-left, so it reads on any cover without its own check.
- **RSVP pill:** Going or Interested on dark glass in the top-right. Nothing shows when you haven't answered.
- **Text:** the name, then "venue · time". With no venue yet it says "To be announced". The brightness check picks white text, dark text, or white over a scrim.
- **No cover:** the pink accent gradient with white text, same as venues.

### Person rows

- **Shorter card:** 84pt tall with the same radius, gap and margins, so a list of people scans faster than a list of events.
- **Two layers of the same picture:** the profile picture enlarged and heavily blurred fills the card, and a sharp 56pt round avatar sits on top at the left.
- **Why blur:** profile pictures are small square faces, so stretching one across a wide card crops off the head and shows pixels. Blurring hides both and still gives each row its own colour.
- **Text:** name and role sit to the right of the avatar. The blurred background is close to flat, so any scrim the check needs is one flat layer over the whole card instead of a gradient.
- **No picture:** initials in a darker pink circle on the accent gradient.

### Before I build it

**Should featured events stay bigger?** Today featured events get a 140pt cover above a normal row. With every event now a photo card, I could give featured ones a taller 180pt card so they still stand out, or drop the difference and use 132pt for all. I recommend the taller card for featured events.
