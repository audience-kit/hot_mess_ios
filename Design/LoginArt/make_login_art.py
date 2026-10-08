#!/usr/bin/env python3
"""Renders the login background and the launch screen mark into HotMess/Assets.xcassets.

Both use the app icon's "misprint" mark (the figure in Design/AppIcon/silhouette.svg
with blue and pink copies out of register behind it), so the launch screen, the
login screen and the icon read as one piece:

  LoginBackground  1290x2796 portrait. The figure rises from the bottom edge,
                   printed in ink on a dark ground so only the blue and pink
                   edges catch the light, and the bottom third fades to ink,
                   where the sign-in button sits.
  LaunchMark       The light app icon as a rounded tile, 180pt at @3x, shown
                   centred on the ink LaunchBackground colour.

  python3 Design/LoginArt/make_login_art.py        # from the repository root

Requires cairosvg and Pillow.
"""

from __future__ import annotations

import io
import json
import re
from pathlib import Path

import cairosvg
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[2]
ASSETS = ROOT / "HotMess" / "Assets.xcassets"
SILHOUETTE = ROOT / "Design" / "AppIcon" / "silhouette.svg"
ICON = ASSETS / "AppIcon.appiconset" / "AppIcon.png"

INK = (0x1A, 0x15, 0x19)  # LaunchBackground
INK_RAISED = (0x2E, 0x25, 0x2C)
FIGURE = "#0e0a0d"
LEFT_INK, RIGHT_INK = "#2fb4ff", "#ff3d9a"  # the Production icon's inks

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


def login_background():
    size = (WIDTH, HEIGHT)
    image = gradient(size, [(0, INK_RAISED), (0.5, INK), (1, INK)])

    # The figure in silhouette.svg's 1200px-wide space, scaled so its shoulders run
    # off both sides and its head sits a little below the middle of the screen.
    d = re.search(r'<path id="figure" d="([^"]+)"', SILHOUETTE.read_text()).group(1)
    scale, dx, dy = 1.2, 37, 300
    offset_x, offset_y = 44, 20
    layer = lambda fill, x, y: (f'<path transform="translate({x} {y}) scale({scale}) translate({dx} {dy})" '
                                f'd="{d}" fill="{fill}"/>')
    svg = (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {WIDTH} {HEIGHT}">'
           + layer(LEFT_INK, -offset_x, -offset_y) + layer(RIGHT_INK, offset_x, offset_y) + layer(FIGURE, 0, 0)
           + "</svg>")
    figure = Image.open(io.BytesIO(cairosvg.svg2png(bytestring=svg.encode(), output_width=WIDTH,
                                                    output_height=HEIGHT))).convert("RGBA")
    # A faint bloom from the inks, as if the edges were lit from behind.
    bloom = figure.filter(ImageFilter.GaussianBlur(40))
    bloom.putalpha(bloom.getchannel("A").point(lambda a: a * 0.35))
    image = image.convert("RGBA")
    image.alpha_composite(bloom)
    image.alpha_composite(figure)
    image = image.convert("RGB")

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
