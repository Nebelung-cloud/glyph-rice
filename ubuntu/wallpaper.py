#!/usr/bin/env python3
"""Glyph home screen as a still wallpaper for GNOME: the dot grid of home/Back.qml and the halftone orb of
components/Orb.qml (at its mid-breath opacity), drawn into a PNG.

    wallpaper.py OUT.png [WIDTHxHEIGHT]     default 2880x1800; GNOME zooms it to the screen
"""
import math
import sys

from PIL import Image, ImageDraw

BG = (0, 0, 0)
GRID = (0x1A, 0x1A, 0x1A)  # Theme.s2
FG = (0xF2, 0xF2, 0xF2)    # Theme.fg


def render(w, h):
    # Glyph lays out on a 2560-wide stage; scale its pixel sizes to this image
    k = w / 2560
    ss = 2  # supersample, then shrink: round dots without a blur pass
    im = Image.new("RGB", (w * ss, h * ss), BG)
    d = ImageDraw.Draw(im)

    pitch, r = 32 * k * ss, 1.5 * k * ss
    y = pitch / 2
    while y < h * ss:
        x = pitch / 2
        while x < w * ss:
            d.ellipse((x - r, y - r, x + r, y + r), fill=GRID)
            x += pitch
        y += pitch

    # orb: 1100 circle at (W-720, H-580) on the stage, radial gradient from a focal point, sampled in 14 px cells
    size = 1100 * k
    ox, oy = w - 720 * k, h - 580 * k
    fx, fy, fr = ox + 352 * k, oy + 330 * k, 730 * k
    cx, cy, cr = ox + size / 2, oy + size / 2, size / 2
    opacity = 0.18
    step = 14 * k  # Dm samples the orb in 14 px cells on screen
    dot = step * 0.34
    gy = oy + step / 2
    while gy < oy + size:
        gx = ox + step / 2
        while gx < ox + size:
            if math.hypot(gx - cx, gy - cy) <= cr:
                a = max(0.0, 1 - math.hypot(gx - fx, gy - fy) / fr) * opacity
                if a > 0.004:
                    c = tuple(round(BG[i] + (FG[i] - BG[i]) * a) for i in range(3))
                    rr = dot * ss
                    d.ellipse((gx * ss - rr, gy * ss - rr, gx * ss + rr, gy * ss + rr), fill=c)
            gx += step
        gy += step

    return im.resize((w, h), Image.LANCZOS)


def main():
    if len(sys.argv) not in (2, 3):
        sys.exit(__doc__.strip())
    w, h = map(int, (sys.argv[2] if len(sys.argv) == 3 else "2880x1800").lower().split("x"))
    render(w, h).save(sys.argv[1], optimize=True)


if __name__ == "__main__":
    main()
