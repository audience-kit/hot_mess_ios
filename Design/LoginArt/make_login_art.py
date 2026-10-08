#!/usr/bin/env python3
"""Renders the login background and the launch screen mark into HotMess/Assets.xcassets.

Both use the 2017 app icon silhouette (Design/AppIcon/silhouette-mask.png) and the
AudienceKit `hot_mess` theme, so the launch screen, the login screen and the
icon read as one piece:

  LoginBackground  1290x2796 portrait. The silhouette rises from the bottom
                   edge against the accent gradient, with a soft glow behind
                   the head, and the bottom third fades to ink, where the
                   sign-in button sits.
  LaunchMark       The light app icon as a rounded tile, 180pt at @3x, shown
                   centred on the ink LaunchBackground colour.

  python3 Design/LoginArt/make_login_art.py        # from the repository root

Requires Pillow.
"""

from __future__ import annotations

import json
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[2]
ASSETS = ROOT / "HotMess" / "Assets.xcassets"
MASK = ROOT / "Design" / "AppIcon" / "silhouette-mask.png"
ICON = ASSETS / "AppIcon.appiconset" / "AppIcon.png"

ACCENT_TOP = (0xD6, 0x3A, 0x8A)
ACCENT = (0xB8, 0x23, 0x6F)
ACCENT_DEEP = (0x6E, 0x10, 0x40)
ACCENT_GLOW = (0xFF, 0x7A, 0xB6)
INK = (0x1A, 0x15, 0x19)

WIDTH, HEIGHT = 1290, 2796  # iPhone 6.9" at @3x; scaledToFill covers every other screen


def lerp(a, b, t):
    return tuple(round(x + (y - x) * t) for x, y in zip(a, b))


def gradient(size, stops):
    width, height = size
    image = Image.new("RGB", size)
    draw = ImageDraw.Draw(image)
    for y in range(height):
        t = y / (height - 1)
        for (p0, c0), (p1, c1) in zip(stops, stops[1:]):
            if p0 <= t <= p1:
                draw.line([(0, y), (width, y)], fill=lerp(c0, c1, (t - p0) / (p1 - p0)))
                break
    return image


def glow(size, centre, radius, colour, strength):
    """A blurred disc of light, screened onto the background."""
    layer = Image.new("RGB", size, (0, 0, 0))
    draw = ImageDraw.Draw(layer)
    x, y = centre
    draw.ellipse([x - radius, y - radius, x + radius, y + radius], fill=lerp((0, 0, 0), colour, strength))
    return layer.filter(ImageFilter.GaussianBlur(radius * 0.6))


def login_background():
    size = (WIDTH, HEIGHT)
    image = gradient(size, [(0, ACCENT_TOP), (0.45, ACCENT), (1, ACCENT_DEEP)])

    # As on the icon, the figure is cut off at the bottom edge; scaled up so its
    # shoulders run off both sides.
    figure_width = round(WIDTH * 1.55)
    mask = Image.open(MASK).convert("L").resize((figure_width, figure_width), Image.LANCZOS)
    left = (WIDTH - figure_width) // 2
    top = HEIGHT - figure_width

    image = ImageChops.screen(image, glow(size, (WIDTH // 2, top + round(figure_width * 0.36)), WIDTH * 0.5,
                                          ACCENT_GLOW, 0.5))
    image.paste(Image.new("RGB", mask.size, INK), (left, top), mask)

    # Fade the bottom third to ink, so the button and footnote sit on one colour.
    fade = gradient(size, [(0, (0, 0, 0)), (0.62, (0, 0, 0)), (0.82, (255, 255, 255)), (1, (255, 255, 255))])
    return Image.composite(Image.new("RGB", size, INK), image, fade.convert("L"))


def launch_mark():
    """The light app icon with iOS-like rounded corners, at 540px (180pt @3x)."""
    side = 540
    icon = Image.open(ICON).convert("RGB").resize((side, side), Image.LANCZOS)
    corners = Image.new("L", (side * 4, side * 4), 0)
    ImageDraw.Draw(corners).rounded_rectangle([(0, 0), (side * 4 - 1, side * 4 - 1)], radius=round(side * 4 * 0.2237),
                                              fill=255)
    tile = Image.new("RGBA", (side, side))
    tile.paste(icon, (0, 0), corners.resize((side, side), Image.LANCZOS))
    return tile


def write_imageset(name, image, scale=None):
    folder = ASSETS / f"{name}.imageset"
    folder.mkdir(exist_ok=True)
    for old in folder.iterdir():
        old.unlink()
    filename = f"{name}.png" if scale is None else f"{name}@{scale}x.png"
    image.save(folder / filename, optimize=True)
    entry = {"filename": filename, "idiom": "universal"}
    if scale is not None:
        entry["scale"] = f"{scale}x"
    (folder / "Contents.json").write_text(json.dumps({"images": [entry], "info": {"author": "xcode", "version": 1}},
                                                     indent=2) + "\n")
    print(f"wrote {folder.relative_to(ROOT)}")


def main():
    write_imageset("LoginBackground", login_background())
    write_imageset("LaunchMark", launch_mark(), scale=3)


if __name__ == "__main__":
    main()
