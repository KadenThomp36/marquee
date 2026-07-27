#!/usr/bin/env python3
"""Render the app icon at 1024pt from the same design as the web client's icon.svg:
a brass marquee canopy with bulb rows and an M, on a near-black ground. The M is set
in Limelight — the app's own display face — rather than the web icon's Georgia
fallback, so the icon and the wordmark inside the app are the same letterform.

Usage:  python3 Tools/build_icon.py
Needs:  pip install pillow
"""
import os

from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FONT = os.path.join(ROOT, "Shared", "Resources", "Fonts", "Limelight-Regular.ttf")
OUT = os.path.join(ROOT, "Marquee", "Assets.xcassets", "AppIcon.appiconset", "icon-1024.png")

S = 1024
K = S / 512.0          # the source artwork is drawn on a 512 grid


def lerp(a, b, t):
    return tuple(round(x + (y - x) * t) for x, y in zip(a, b))


def vertical_gradient(size, top, bottom):
    img = Image.new("RGB", (1, size[1]))
    for y in range(size[1]):
        img.putpixel((0, y), lerp(top, bottom, y / max(1, size[1] - 1)))
    return img.resize(size, Image.BILINEAR)


def diagonal_brass(size):
    """#ffd98a → #f0b544 on the 45° diagonal, matching the SVG's linearGradient."""
    w, h = size
    img = Image.new("RGB", (64, 64))
    a, b = (0xFF, 0xD9, 0x8A), (0xF0, 0xB5, 0x44)
    for y in range(64):
        for x in range(64):
            img.putpixel((x, y), lerp(a, b, (x + y) / 126))
    return img.resize(size, Image.BILINEAR)


def main():
    base = vertical_gradient((S, S), (0x1C, 0x18, 0x11), (0x0E, 0x0C, 0x09)).convert("RGBA")
    brass = diagonal_brass((S, S)).convert("RGBA")

    # everything brass is painted by masking the gradient, so one gradient serves all
    mask = Image.new("L", (S, S), 0)
    d = ImageDraw.Draw(mask)

    stroke = round(16 * K)
    d.rounded_rectangle([96 * K, 150 * K, (96 + 320) * K, (150 + 212) * K],
                        radius=26 * K, outline=255, width=stroke)

    for cy in (150, 362):
        for cx in range(130, 371, 48):
            r = 9 * K
            d.ellipse([cx * K - r, cy * K - r, cx * K + r, cy * K + r], fill=255)

    # Limelight's M is wider and taller than the SVG's Georgia fallback at the same
    # point size, so it's set smaller and optically centred in the canopy instead
    size = round(158 * K)
    font = ImageFont.truetype(FONT, size)
    letter = Image.new("L", (S, S), 0)
    ld = ImageDraw.Draw(letter)
    ld.text((256 * K, 313 * K), "M", font=font, fill=255, anchor="ms")
    mask = Image.composite(Image.new("L", (S, S), 255), mask, letter)

    icon = Image.composite(brass, base, mask).convert("RGB")
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    icon.save(OUT, "PNG")
    print("wrote", OUT, f"{os.path.getsize(OUT):,} bytes")


if __name__ == "__main__":
    main()
