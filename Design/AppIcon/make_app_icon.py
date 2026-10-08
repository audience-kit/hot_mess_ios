#!/usr/bin/env python3
"""Renders the Hot Mess app icons into HotMess/Assets.xcassets.

The mark is the "misprint": the figure from the original login background
(silhouette.svg) in ink, with two offset copies slipping out of register
behind it. Each build has its own colour, as the 2017 icons did:

  AppIcon             Production   blue    (white paper, blue and pink inks)
  AppIconStaging      Test         green
  AppIconDevelopment  Development  purple

Each set is one 1024x1024 universal icon with light, dark and tinted
appearances, opaque with square corners (iOS applies the mask). The SVG
masters are written next to this script in masters/.

  python3 Design/AppIcon/make_app_icon.py          # from the repository root

Requires cairosvg.
"""

from __future__ import annotations

import json
import re
from pathlib import Path

import cairosvg

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
ASSETS = ROOT / "HotMess" / "Assets.xcassets"
MASTERS = HERE / "masters"
SIZE = 1024

INK = "#1a1519"  # hot_mess_dark surface
PAPER_DARK = "#141014"

# Icon set -> paper, the ink behind-left, the ink behind-right, and the figure in dark mode.
ICON_SETS = {
    "AppIcon": dict(paper="#f6eff3", left="#2fb4ff", right="#ff3d9a", dark_figure="#cfe9ff"),
    "AppIconStaging": dict(paper="#c9efc6", left="#ffd23d", right="#2fbf4f", dark_figure="#c9efc6"),
    "AppIconDevelopment": dict(paper="#dcc0f5", left="#a46bff", right="#5e1a9c", dark_figure="#dcc0f5"),
}

# The figure is scaled and placed so the head sits in the upper middle of the icon.
PLACEMENT = "scale(0.80) translate(140 -470)"
OFFSET = (30, 14)


def figure_path():
    svg = (HERE / "silhouette.svg").read_text()
    return re.search(r'<path id="figure" d="([^"]+)"', svg).group(1)


def misprint(paper, left, right, figure):
    d = figure_path()
    dx, dy = OFFSET
    layer = lambda fill, x, y: (
        f'<g transform="translate({x} {y})"><path transform="{PLACEMENT}" d="{d}" fill="{fill}"/></g>'
    )
    return (
        f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {SIZE} {SIZE}" width="{SIZE}" height="{SIZE}">'
        f'<rect width="{SIZE}" height="{SIZE}" fill="{paper}"/>'
        + layer(left, -dx, -dy)
        + layer(right, dx, dy)
        + layer(figure, 0, 0)
        + "</svg>\n"
    )


def render(colours):
    light = misprint(colours["paper"], colours["left"], colours["right"], INK)
    # Dark mode prints in reverse: light figure on dark paper, same inks.
    dark = misprint(PAPER_DARK, colours["left"], colours["right"], colours["dark_figure"])
    # Tinted icons are greyscale on black; iOS tints them by luminance.
    tinted = misprint("#000000", "#5c5c5c", "#8e8e8e", "#ffffff")
    return {"": light, "-dark": dark, "-tinted": tinted}


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
    MASTERS.mkdir(exist_ok=True)
    for name, colours in ICON_SETS.items():
        folder = ASSETS / f"{name}.appiconset"
        folder.mkdir(exist_ok=True)
        for old in folder.iterdir():
            old.unlink()

        for suffix, svg in render(colours).items():
            (MASTERS / f"{name}{suffix}.svg").write_text(svg)
            cairosvg.svg2png(bytestring=svg.encode(), write_to=str(folder / f"{name}{suffix}.png"),
                             output_width=SIZE, output_height=SIZE, background_color="white")
        (folder / "Contents.json").write_text(json.dumps(contents(name), indent=2) + "\n")
        print(f"wrote {folder.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
