"""Renders the launcher-icon sources from the logo symbol.

Reads assets/logo/logo.svg, skips its tile (<rect>) and wordmark (<text>),
and writes the text-free icon sources used by flutter_launcher_icons:

  assets/logo/app_icon.png             iOS / legacy Android: mark on paper
  assets/logo/app_icon_foreground.png  Android adaptive foreground (transparent)
  assets/logo/app_icon_monochrome.png  Android 13+ themed icon (white + alpha)

Usage (needs Pillow):
  python tool/generate_app_icons.py
  dart run flutter_launcher_icons

The SVG only uses absolute M/L/Q/Z paths and circles, which is all this
parser supports.
"""

import math
import re
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
LOGO = ROOT / "assets" / "logo" / "logo.svg"
OUT = ROOT / "assets" / "logo"

SIZE = 1024
SUPERSAMPLE = 4
PAPER = "#FFFDFC"  # AppColors.paper — the icon background

# iOS / legacy icon: width of the mark as a share of the icon.
FULL_MARK_WIDTH = 0.68
# Android adaptive icon: the farthest point of the mark sits at this share of
# the 66dp (of 108dp) safe-zone radius, so no launcher mask clips it.
ADAPTIVE_SAFE_RADIUS = SIZE * 33 / 108
ADAPTIVE_FILL = 0.86


def _parse_path(d):
    """Absolute M/L/Q/Z path data → list of (points, closed) subpaths."""
    tokens = re.findall(r"[MLQZ]|-?\d*\.?\d+", d.upper())
    subpaths, points, cmd, i = [], [], None, 0

    def num():
        nonlocal i
        i += 1
        return float(tokens[i - 1])

    while i < len(tokens):
        if tokens[i] in "MLQZ":
            cmd = tokens[i]
            i += 1
            if cmd == "Z":
                subpaths.append((points, True))
                points = []
                continue
        if cmd == "M":
            if points:
                subpaths.append((points, False))
            points = [(num(), num())]
            cmd = "L"  # implicit lineto after the first pair
        elif cmd == "L":
            points.append((num(), num()))
        elif cmd == "Q":
            cx, cy, x, y = num(), num(), num(), num()
            x0, y0 = points[-1]
            for step in range(1, 33):
                t = step / 32
                u = 1 - t
                points.append((
                    u * u * x0 + 2 * u * t * cx + t * t * x,
                    u * u * y0 + 2 * u * t * cy + t * t * y,
                ))
        else:
            raise ValueError(f"Unsupported path data near token {i}: {d}")
    if points:
        subpaths.append((points, False))
    return subpaths


def load_symbol():
    """The logo's shapes in paint order, without the tile and wordmark."""
    shapes = []
    for el in ET.parse(LOGO).getroot():
        tag = el.tag.split("}")[-1]
        if tag == "path":
            subpaths = _parse_path(el.get("d"))
            if el.get("stroke"):
                shapes.append(("stroke", subpaths, el.get("stroke"),
                               float(el.get("stroke-width", "1"))))
            else:
                shapes.append(("fill", subpaths, el.get("fill"), 0.0))
        elif tag == "circle":
            centre = (float(el.get("cx")), float(el.get("cy")))
            shapes.append(("circle", centre, el.get("fill"),
                           float(el.get("r"))))
        elif tag in ("rect", "text"):
            continue  # tile and wordmark
        else:
            raise ValueError(f"Unsupported SVG element <{tag}>")
    return shapes


def _extents(shapes):
    """(x, y, reach) for every painted point; reach = stroke/circle radius."""
    for kind, geometry, _, size in shapes:
        if kind == "circle":
            yield geometry[0], geometry[1], size
        else:
            for points, _ in geometry:
                for x, y in points:
                    yield x, y, size / 2


def bounds(shapes):
    ext = list(_extents(shapes))
    return (min(x - r for x, _, r in ext), min(y - r for _, y, r in ext),
            max(x + r for x, _, r in ext), max(y + r for _, y, r in ext))


def max_radius(shapes, cx, cy):
    return max(math.hypot(x - cx, y - cy) + r for x, y, r in _extents(shapes))


def _stroke(draw, pts, r, colour):
    """A polyline with round caps and joins: a quad per segment plus a disc
    at every vertex (ImageDraw.line leaves ragged edges on dense curves)."""
    for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
        length = math.hypot(x1 - x0, y1 - y0)
        if length == 0:
            continue
        nx, ny = -(y1 - y0) / length * r, (x1 - x0) / length * r
        draw.polygon([(x0 + nx, y0 + ny), (x1 + nx, y1 + ny),
                      (x1 - nx, y1 - ny), (x0 - nx, y0 - ny)], fill=colour)
    for x, y in pts:
        draw.ellipse((x - r, y - r, x + r, y + r), fill=colour)


def render(shapes, centre, scale, background=None, monochrome=False):
    """Paints the symbol centred on the canvas at [scale] px per SVG unit.

    Monochrome paints the shapes white and knocks the paper-coloured parts
    (page rims, ✕ and ✓) out to transparent.
    """
    big = SIZE * SUPERSAMPLE
    k = scale * SUPERSAMPLE

    def tx(x, y):
        return ((x - centre[0]) * k + big / 2, (y - centre[1]) * k + big / 2)

    if monochrome:
        canvas = Image.new("L", (big, big), 0)
    else:
        canvas = Image.new("RGBA", (big, big), background or (0, 0, 0, 0))
    draw = ImageDraw.Draw(canvas)

    for kind, geometry, colour, size in shapes:
        if monochrome:
            colour = 0 if colour.upper() == PAPER else 255
        if kind == "circle":
            x, y = tx(*geometry)
            r = size * k
            draw.ellipse((x - r, y - r, x + r, y + r), fill=colour)
        elif kind == "fill":
            for points, _ in geometry:
                draw.polygon([tx(*p) for p in points], fill=colour)
        else:
            for points, _ in geometry:
                _stroke(draw, [tx(*p) for p in points], size * k / 2, colour)

    canvas = canvas.reduce(SUPERSAMPLE)  # box filter = clean anti-aliasing
    if monochrome:
        white = Image.new("RGBA", canvas.size, (255, 255, 255, 0))
        white.putalpha(canvas)
        return white
    return canvas


def main():
    shapes = load_symbol()
    left, top, right, bottom = bounds(shapes)
    centre = ((left + right) / 2, (top + bottom) / 2)

    full_scale = SIZE * FULL_MARK_WIDTH / (right - left)
    adaptive_scale = (ADAPTIVE_SAFE_RADIUS * ADAPTIVE_FILL
                      / max_radius(shapes, *centre))

    render(shapes, centre, full_scale, background=PAPER) \
        .convert("RGB").save(OUT / "app_icon.png", optimize=True)
    render(shapes, centre, adaptive_scale) \
        .save(OUT / "app_icon_foreground.png", optimize=True)
    render(shapes, centre, adaptive_scale, monochrome=True) \
        .save(OUT / "app_icon_monochrome.png", optimize=True)

    print(f"mark bounds {left:.0f},{top:.0f} → {right:.0f},{bottom:.0f}; "
          f"full scale {full_scale:.3f}, adaptive scale {adaptive_scale:.3f}")


if __name__ == "__main__":
    sys.exit(main())
