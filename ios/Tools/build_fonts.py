#!/usr/bin/env python3
"""Bake the app's typefaces from the Marquee server's web fonts.

The web client ships Limelight (display) and a variable Archivo (body) as woff2.
iOS can't load woff2, and a single variable instance would flatten the weight
contrast the design leans on — so this produces:

  Limelight-Regular.ttf              the display face, unchanged
  Archivo-{Regular,Medium,SemiBold,Bold,ExtraBold}.ttf

as a real family named "Archivo", which is what Font.custom() matches on.

Usage:  python3 Tools/build_fonts.py /path/to/marquee/static/fonts
Needs:  pip install fonttools brotli
"""
import os
import sys

from fontTools.ttLib import TTFont
from fontTools.ttLib.woff2 import decompress
from fontTools.varLib import instancer

OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                   "Shared", "Resources", "Fonts")

# (style name, weight axis value, OS/2 usWeightClass, mac style bit for bold)
WEIGHTS = [("Regular", 400, 400), ("Medium", 500, 500), ("SemiBold", 600, 600),
           ("Bold", 700, 700), ("ExtraBold", 800, 800)]

# name table IDs we rewrite so the family reads as one family with five styles
FAMILY, SUBFAMILY, FULL, PS, PREF_FAMILY, PREF_SUB = 1, 2, 4, 6, 16, 17


def set_names(font, family, style):
    """Rewrite the name table so iOS sees one family with named styles. The typographic
    pair (16/17) is what CoreText prefers; the legacy pair (1/2) must agree with it or
    the styles show up as separate families in the font picker."""
    name = font["name"]
    ps = f"{family}-{style}".replace(" ", "")
    full = f"{family} {style}"
    # Regular is the only style allowed to occupy the legacy family slot on its own
    legacy_family = family if style in ("Regular", "Bold") else full
    legacy_style = style if style in ("Regular", "Bold") else "Regular"
    for nid, value in ((FAMILY, legacy_family), (SUBFAMILY, legacy_style), (FULL, full),
                       (PS, ps), (PREF_FAMILY, family), (PREF_SUB, style)):
        name.setName(value, nid, 3, 1, 0x409)   # Windows / Unicode BMP / en-US
        name.setName(value, nid, 1, 0, 0)       # Mac / Roman / English
    return ps


def bake_archivo(src):
    made = []
    for style, wght, weight_class in WEIGHTS:
        font = TTFont(src)
        instancer.instantiateVariableFont(font, {"wght": wght}, inplace=True)
        font["OS/2"].usWeightClass = weight_class
        # bit0 ITALIC, bit5 BOLD, bit6 REGULAR — exactly one of BOLD/REGULAR may be set
        font["OS/2"].fsSelection &= ~0x61
        font["head"].macStyle &= ~0x01
        if style == "Regular":
            font["OS/2"].fsSelection |= 0x40
        if style == "Bold":
            font["OS/2"].fsSelection |= 0x20
            font["head"].macStyle |= 0x01
        ps = set_names(font, "Archivo", style)
        path = os.path.join(OUT, f"Archivo-{style}.ttf")
        font.save(path)
        made.append((os.path.basename(path), ps, os.path.getsize(path)))
    return made


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    src_dir = os.path.abspath(os.path.expanduser(sys.argv[1]))
    os.makedirs(OUT, exist_ok=True)
    tmp = os.path.join(OUT, "_archivo-var.ttf")
    decompress(os.path.join(src_dir, "archivo.woff2"), tmp)
    decompress(os.path.join(src_dir, "limelight.woff2"),
               os.path.join(OUT, "Limelight-Regular.ttf"))
    lime = TTFont(os.path.join(OUT, "Limelight-Regular.ttf"))
    set_names(lime, "Limelight", "Regular")
    lime.save(os.path.join(OUT, "Limelight-Regular.ttf"))
    made = bake_archivo(tmp)
    os.remove(tmp)
    made.insert(0, ("Limelight-Regular.ttf", "Limelight-Regular",
                    os.path.getsize(os.path.join(OUT, "Limelight-Regular.ttf"))))
    for fn, ps, size in made:
        print(f"{fn:32} {ps:24} {size:>7,} bytes")


if __name__ == "__main__":
    main()
