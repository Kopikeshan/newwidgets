#!/usr/bin/env python3
"""Draws the Liby app icon and writes every size the asset catalog needs.

    python3 Branding/make_icon.py

The mark is the clock only — the wordmark is dropped, because at the sizes an
app icon is actually seen (16-128px in the Dock, Finder and menu bar) lettering
turns to mush, and the app's name is always shown beside the icon regardless.

To use a supplied image instead of this drawing, pass it as an argument:

    python3 Branding/make_icon.py path/to/liby-1024.png

It is placed on the macOS rounded-rectangle plate at the standard proportions.
"""

import json
import math
import sys
from pathlib import Path

from PIL import Image, ImageDraw

# Colours sampled from the logo.
PURPLE = (91, 79, 224, 255)
SPARK = (169, 157, 242, 255)
PLATE = (255, 255, 255, 255)

# Everything is drawn on a 1024 grid at 4x, then resampled down.
GRID = 1024
SS = 4

# Apple's macOS icon proportions: the plate is 824/1024 of the canvas with a
# 185/1024 corner radius, leaving the margin the system expects.
PLATE_INSET = 100
PLATE_RADIUS = 185

OUT = Path("StudyTimer/Assets.xcassets/AppIcon.appiconset")
SIZES = [(16, 1), (16, 2), (32, 1), (32, 2), (128, 1), (128, 2),
         (256, 1), (256, 2), (512, 1), (512, 2)]


def round_line(draw, start, end, width, fill):
    """A line with round caps — PIL has no cap styles, so cap it by hand."""
    draw.line([start, end], fill=fill, width=width)
    for point in (start, end):
        draw.ellipse(
            [point[0] - width / 2, point[1] - width / 2,
             point[0] + width / 2, point[1] + width / 2],
            fill=fill,
        )


def polar(centre, radius, degrees):
    """A point at `degrees` measured anticlockwise from east, y growing down."""
    rad = math.radians(degrees)
    return (centre[0] + radius * math.cos(rad), centre[1] - radius * math.sin(rad))


def draw_mark(size):
    """The clock mark on its plate, at `size` pixels square."""
    scale = size / GRID
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    def s(value):
        return value * scale

    # Plate
    draw.rounded_rectangle(
        [s(PLATE_INSET), s(PLATE_INSET), s(GRID - PLATE_INSET), s(GRID - PLATE_INSET)],
        radius=s(PLATE_RADIUS),
        fill=PLATE,
    )

    radius = s(265)
    stroke = s(38)
    sparks = ((52, 319, 385), (30, 335, 395), (8, 342, 389))

    # The sparks all sit off to the right, so centring the ring would leave the
    # whole mark looking shoved left. Centre the drawn extent instead.
    right = s(max(outer for _, _, outer in sparks))
    left = radius + stroke / 2
    centre = (s(GRID / 2) - (right - left) / 2, s(GRID / 2))

    # The ring, open on the right between about 1 and 4:30 o'clock. PIL measures
    # arc angles clockwise from east, so this runs 45deg round to 300deg.
    box = [centre[0] - radius, centre[1] - radius, centre[0] + radius, centre[1] + radius]
    draw.arc(box, start=45, end=300, fill=PURPLE, width=int(round(stroke)))
    # Round off both ends. `arc` insets its stroke, so the centreline — and so
    # the cap — sits half a stroke inside the radius.
    for angle in (45, 300):
        spine = radius - stroke / 2
        cap = (centre[0] + spine * math.cos(math.radians(angle)),
               centre[1] + spine * math.sin(math.radians(angle)))
        draw.ellipse([cap[0] - stroke / 2, cap[1] - stroke / 2,
                      cap[0] + stroke / 2, cap[1] + stroke / 2], fill=PURPLE)

    # Hands: one straight up, one out to the lower right.
    hand = s(159)
    hand_stroke = s(34)
    round_line(draw, centre, (centre[0], centre[1] - hand), int(round(hand_stroke)), PURPLE)
    round_line(draw, centre, polar(centre, hand, -26), int(round(hand_stroke)), PURPLE)
    draw.ellipse([centre[0] - hand_stroke / 2, centre[1] - hand_stroke / 2,
                  centre[0] + hand_stroke / 2, centre[1] + hand_stroke / 2], fill=PURPLE)

    # Three radial sparks in the ring's opening, shrinking as they go round.
    for angle, inner, outer in sparks:
        round_line(draw, polar(centre, s(inner), angle), polar(centre, s(outer), angle),
                   int(round(s(32))), SPARK)

    return img


def from_source(path, size):
    """Place a supplied square image on the same plate."""
    scale = size / GRID
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    inset, radius = PLATE_INSET * scale, PLATE_RADIUS * scale
    draw.rounded_rectangle([inset, inset, size - inset, size - inset], radius=radius, fill=PLATE)

    art = Image.open(path).convert("RGBA")
    side = int(size - 2 * inset)
    art = art.resize((side, side), Image.LANCZOS)

    mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        [inset, inset, size - inset, size - inset], radius=radius, fill=255
    )
    img.paste(art, (int(inset), int(inset)), art)
    img.putalpha(mask)
    return img


def main():
    source = sys.argv[1] if len(sys.argv) > 1 else None
    OUT.mkdir(parents=True, exist_ok=True)

    big = GRID * SS
    master = from_source(source, big) if source else draw_mark(big)
    master.resize((GRID, GRID), Image.LANCZOS).save("Branding/liby-icon-1024.png")

    images = []
    for size, scale in SIZES:
        pixels = size * scale
        name = f"icon_{size}x{size}{'@2x' if scale == 2 else ''}.png"
        master.resize((pixels, pixels), Image.LANCZOS).save(OUT / name)
        images.append({"filename": name, "idiom": "mac",
                       "scale": f"{scale}x", "size": f"{size}x{size}"})
        print(f"  {name}  ({pixels}px)")

    (OUT / "Contents.json").write_text(
        json.dumps({"images": images, "info": {"author": "xcode", "version": 1}}, indent=2) + "\n"
    )
    print(f"wrote {len(images)} icons to {OUT}")


if __name__ == "__main__":
    main()
