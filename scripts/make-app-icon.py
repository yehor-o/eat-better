#!/usr/bin/env python3
"""Draws the app icon: a bowl with a sprout on a warm gradient (1024 × 1024, no alpha).

Usage: python3 scripts/make-app-icon.py   (needs Pillow; writes App/Assets.xcassets/AppIcon.appiconset/icon.png)
"""
import math
import pathlib

from PIL import Image, ImageDraw, ImageFilter

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / "App/Assets.xcassets/AppIcon.appiconset/icon.png"
N = 4096  # drawn large, scaled down for smooth edges


def lerp(a, b, t):
    return tuple(round(x + (y - x) * t) for x, y in zip(a, b))


def leaf(draw, base, angle, length, width, fill):
    """A pointed leaf from `base`, leaning `angle` degrees from straight up."""
    a = math.radians(angle)
    ux, uy = math.sin(a), -math.cos(a)          # along the leaf
    px, py = -uy, ux                            # across it
    points = []
    for i in range(41):
        t = i / 40
        w = math.sin(math.pi * t) * width / 2
        points.append((base[0] + ux * length * t + px * w, base[1] + uy * length * t + py * w))
    for i in range(40, -1, -1):
        t = i / 40
        w = math.sin(math.pi * t) * width / 2
        points.append((base[0] + ux * length * t - px * w, base[1] + uy * length * t - py * w))
    draw.polygon(points, fill=fill)


def main():
    top, bottom = (255, 170, 72), (240, 84, 52)
    img = Image.new("RGB", (N, N))
    px = img.load()
    for y in range(N):
        row = lerp(top, bottom, y / (N - 1))
        for x in range(N):
            px[x, y] = row

    # Soft shadow under the bowl.
    shadow = Image.new("L", (N, N), 0)
    ImageDraw.Draw(shadow).ellipse((880, 3140, 3216, 3420), fill=90)
    shadow = shadow.filter(ImageFilter.GaussianBlur(90))
    img.paste((150, 45, 25), mask=shadow)

    d = ImageDraw.Draw(img)
    cream, green, dark_green = (255, 248, 238), (76, 175, 80), (46, 125, 50)

    # Sprout first, so the bowl rim covers the bottom of the stem.
    stem_bottom, stem_top = (2048, 2300), (2048, 1350)
    d.line([stem_bottom, stem_top], fill=dark_green, width=120)
    leaf(d, (2048, 1700), -48, 820, 430, green)
    leaf(d, (2048, 1520), 42, 720, 380, green)
    leaf(d, (2048, 1380), -4, 520, 300, (102, 199, 106))

    # Bowl: lower half of an ellipse, a rim and a foot.
    cx, rim_y, rx, ry = 2048, 2240, 1320, 1000
    d.pieslice((cx - rx, rim_y - ry, cx + rx, rim_y + ry), 0, 180, fill=cream)
    d.rounded_rectangle((cx - rx - 90, rim_y - 110, cx + rx + 90, rim_y + 70), radius=90, fill=cream)
    d.rounded_rectangle((cx - 520, rim_y + ry - 120, cx + 520, rim_y + ry + 60), radius=60, fill=cream)
    # A warm stripe on the bowl.
    d.arc((cx - rx + 170, rim_y - ry + 230, cx + rx - 170, rim_y + ry - 230), 25, 155, fill=(255, 196, 120), width=110)

    OUT.parent.mkdir(parents=True, exist_ok=True)
    img.resize((1024, 1024), Image.LANCZOS).save(OUT)
    print(OUT)


if __name__ == "__main__":
    main()
