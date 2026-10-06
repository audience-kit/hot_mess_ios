#!/usr/bin/env python3
"""Renders the Hot Mess app icons into HotMess/Assets.xcassets.

The mark is the silhouette from the original Hot Mess icon (silhouette-mask.png,
extracted from the 2017 1024px icon), recoloured with the AudienceKit
`hot_mess` theme from audience-kit/admin/src/design/tokens.json:

  accent        #b8236f (light)   #ff7ab6 (dark)
  surface       #1a1519 (hot_mess_dark)

Each set is one 1024x1024 universal icon with light, dark and tinted
appearances, opaque with square corners (iOS applies the mask).

  python3 Design/AppIcon/make_app_icon.py          # from the repository root

Requires Pillow.
"""

from __future__ import annotations

import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
ASSETS = ROOT / "HotMess" / "Assets.xcassets"
FONT = ROOT / "HotMess" / "Resources" / "ProximaNova-SemiBold.otf"
SIZE = 1024

ACCENT_TOP = (0xD6, 0x3A, 0x8A)  # accent, lifted
ACCENT = (0xB8, 0x23, 0x6F)  # hot_mess accent
ACCENT_DEEP = (0x6E, 0x10, 0x40)  # accent, deepened
ACCENT_DARK_MODE = (0xFF, 0x7A, 0xB6)  # hot_mess_dark accent
INK = (0x1A, 0x15, 0x19)  # hot_mess_dark surface
INK_RAISED = (0x27, 0x20, 0x26)  # hot_mess_dark surface-raised

# Build configurations -> icon set and the ribbon that marks non-production builds.
ICON_SETS = {
    "AppIcon": None,
    "AppIconStaging": "STAGING",
    "AppIconDevelopment": "DEV",
}


def lerp(a, b, t):
    return tuple(round(x + (y - x) * t) for x, y in zip(a, b))


def gradient(stops):
    """A vertical gradient through (position, colour) stops."""
    image = Image.new("RGB", (SIZE, SIZE))
    draw = ImageDraw.Draw(image)
    for y in range(SIZE):
        t = y / (SIZE - 1)
        for (p0, c0), (p1, c1) in zip(stops, stops[1:]):
            if p0 <= t <= p1:
                draw.line([(0, y), (SIZE, y)], fill=lerp(c0, c1, (t - p0) / (p1 - p0)))
                break
    return image


def silhouette():
    mask = Image.open(HERE / "silhouette-mask.png").convert("L")
    return mask.resize((SIZE, SIZE), Image.LANCZOS) if mask.size != (SIZE, SIZE) else mask


def compose(background, figure, mask):
    background.paste(figure, (0, 0), mask)
    return background


def ribbon(image, label, fill, text):
    """A band across the bottom naming the build, so test builds are easy to tell apart."""
    draw = ImageDraw.Draw(image)
    top = SIZE - 210
    draw.rectangle([(0, top), (SIZE, SIZE)], fill=fill)
    font = ImageFont.truetype(str(FONT), 120)
    box = draw.textbbox((0, 0), label, font=font)
    width, height = box[2] - box[0], box[3] - box[1]
    draw.text(((SIZE - width) / 2 - box[0], top + (210 - height) / 2 - box[1] - 20), label, font=font, fill=text)
    return image


def render(label):
    mask = silhouette()

    light = compose(
        gradient([(0, ACCENT_TOP), (0.55, ACCENT), (1, ACCENT_DEEP)]),
        Image.new("RGB", (SIZE, SIZE), INK),
        mask,
    )
    dark = compose(
        gradient([(0, INK_RAISED), (1, INK)]),
        gradient([(0, ACCENT_DARK_MODE), (1, ACCENT)]),
        mask,
    )
    # Tinted icons are greyscale; iOS tints them by luminance.
    tinted = compose(
        Image.new("RGB", (SIZE, SIZE), (0, 0, 0)),
        gradient([(0, (0xFF, 0xFF, 0xFF)), (1, (0x9A, 0x9A, 0x9A))]),
        mask,
    )

    if label:
        ribbon(light, label, INK, (0xFF, 0xFF, 0xFF))
        ribbon(dark, label, ACCENT_DARK_MODE, INK)
        ribbon(tinted, label, (0xFF, 0xFF, 0xFF), (0, 0, 0))

    return light, dark, tinted


def contents(name):
    def image(filename, appearance=None):
        entry = {"filename": filename, "idiom": "universal", "platform": "ios", "size": "1024x1024"}
        if appearance:
            entry["appearances"] = [{"appearance": "luminosity", "value": appearance}]
        return entry

    return {
        "images": [
            image(f"{name}.png"),
            image(f"{name}-dark.png", "dark"),
            image(f"{name}-tinted.png", "tinted"),
        ],
        "info": {"author": "xcode", "version": 1},
    }


def main():
    for name, label in ICON_SETS.items():
        folder = ASSETS / f"{name}.appiconset"
        folder.mkdir(exist_ok=True)
        for old in folder.iterdir():
            old.unlink()

        light, dark, tinted = render(label)
        light.save(folder / f"{name}.png", optimize=True)
        dark.save(folder / f"{name}-dark.png", optimize=True)
        tinted.save(folder / f"{name}-tinted.png", optimize=True)
        (folder / "Contents.json").write_text(json.dumps(contents(name), indent=2) + "\n")
        print(f"wrote {folder.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
