# Full-bleed hero banner

> Exported on 2026-10-08 from the design sketch artifact https://claude.ai/artifact/3A2GQZYQSJ1gm6n3FsH5cX (drafted 2026-10-07; the interactive mockups are omitted). Built as HeroHeader and ImageTone in DesignSystem; the shared spec is in audience-kit api/doc/design-system/components/HeroHeader.md and PhotoCard.md.

The cover photo runs to both edges and up under the status bar on the Venue, Event and Person screens. The app reads the photo's brightness where the text sits and picks white or dark text, adding a gradient scrim only when neither color is readable on its own.

## How the brightness is read

1.  **Wait for the decoded image**Kingfisher hands back the image; nothing is read from the network twice.

2.  **Crop to what is actually on screen**The hero is aspect-fill, so the sides or top of the photo may be cut off. Sampling uses the visible crop, not the whole file.

3.  **Read two areas separately**The top area (status bar and the back and share buttons, 108pt) and the title area (behind the title block plus 8pt). A sunset sky over a dark street needs dark status icons and a white title at the same time.

4.  **Shrink each area to 32 pixels wide**One CGContext draw averages neighbours for us. About 300 pixels per area, well under a millisecond.

5.  **Convert each pixel to relative luminance**Linearised sRGB, the WCAG formula, so the numbers are the same ones a contrast checker uses.

6.  **Judge by the worst 10%, not the average**An average hides one bright spotlight right behind a letter. White text is tested against the 90th-percentile brightest pixel, dark text against the 10th-percentile darkest.

7.  **Pick the text color, then the scrim**If white reaches 4.5:1 it wins. Otherwise, if dark text reaches 4.5:1 it wins. Otherwise add the smallest scrim that gets one of them to 4.5:1.

8.  **Cache the answer**Keyed by image URL and hero size, so going back to a venue never flickers between styles.

### The math

L(px) = 0.2126·R + 0.7152·G + 0.0722·B (linear sRGB) white = 1.05 / (L₉₀ + 0.05) ≥ 4.5 → white text dark = (L₁₀ + 0.05) / (0.0103 + 0.05) ≥ 4.5 → dark text scrim = 1 − 0.183 / L₉₀ black, under white text = (0.221 − L₁₀) / (1 − L₁₀) white, under dark text

0.0103 is the luminance of the Hot Mess `ink` token \#24161d. 0.183 and 0.221 are the luminances at which white and ink text land exactly on 4.5:1. The smaller scrim wins, with a 0.1 bias toward white text because it reads as "photo caption" on nightlife shots. The scrim is capped at 75%.

### Sketch of the Swift side

``` code
// DesignSystem/ImageTone.swift (proposed)
struct HeroTone: Hashable {
    enum Text { case light, dark }
    var text: Text          // title + metadata
    var scrim: Double       // 0…0.75
    var statusBar: ColorScheme
}

enum ImageTone {
    static func analyze(_ image: CGImage,
                        top: CGRect, band: CGRect,
                        target: Double = 4.5) -> HeroTone {
        let topL  = luminances(image, in: top)   // 32×N
        let bandL = luminances(image, in: band)
        return decide(top: topL, band: bandL, target)
    }
}
```

## Fallbacks and edge cases

### When there is no usable photo

- **No cover photo:** a Hot Mess accent gradient (accent to accent-strong) with white text. On-accent is already checked at 4.5:1 by the design system.
- **While loading:** a dark neutral placeholder with white text, which matches most nightlife photos. If the result is dark text, it crossfades in 150ms. A cached result skips this.
- **Image fails to decode:** treated as no cover photo.
- **Very busy photo:** the scrim is capped at 75%. Past that the photo is mostly hidden, so we keep the cap and accept 4.5:1 for the title only.

### Accessibility and scrolling

- **Increase Contrast:** the target goes to 7:1 and the scrim never drops below 30%. Try the toggle above.
- **Reduce Transparency:** the back and share buttons lose their glass, so the scrim floor is 30% there too.
- **Large text sizes:** the title wraps to three lines at most and the hero grows to fit. The band is measured after layout, so the scrim grows with it.
- **iOS 18:** toolbar buttons are not Liquid Glass there, so they get a material circle behind them. On iOS 26 the glass already adapts to what is behind it.
- **Scrolling:** the photo stretches when you pull down (no parallax). Once it scrolls away, the bar fills with material, the inline title fades in and the status bar goes back to the system style.

## What building it would change

- A new **HeroHeader** view in DesignSystem: photo, scrim, a text slot, and the tone passed down so the status bar and buttons follow it.
- A new **ImageTone** analyser with the decision above, cached in memory by URL, and unit tests on synthetic light, dark, split and busy images.
- **VenueScreen, EventScreen and PersonScreen** move from an inset List to a ScrollView with the same grouped cards, because an inset List cannot run a row edge to edge or under the status bar.
- The current 200pt rounded photo row and the Person header with the overlapping avatar are replaced. Hero height is 300pt plus the status bar.
- Later, if wanted: the API computes the tone and an average color when a photo is uploaded, so the placeholder matches before the image arrives.
