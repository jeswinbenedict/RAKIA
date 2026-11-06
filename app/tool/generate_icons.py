"""Regenerates every RAKIA app icon from one design.

The mark is a bold "R" (Geist Bold, bundled under the SIL OFL) on the brand
violet, with a lime point as the orbiting craft. Each existing icon file is
redrawn at its current pixel size, so the platform icon sets keep their
structure. Run from app/:  python -I tool/generate_icons.py
"""
import glob
import os
import sys

from PIL import Image, ImageDraw, ImageFont

VIOLET = (125, 57, 235)       # brand.violet  #7D39EB
VIOLET_DEEP = (91, 43, 196)   # violetText    #5B2BC4
LIME = (198, 255, 51)         # accent.lime   #C6FF33
WHITE = (255, 255, 255)
CANVAS = (8, 6, 14)           # canvas.dark   #08060E

HERE = os.path.dirname(os.path.abspath(__file__))
APP = os.path.dirname(HERE)
FONT = os.path.join(APP, "assets", "fonts", "Geist-Bold.ttf")


def render(size, *, safe=1.0, rounded=True, opaque=False):
    """Draws the mark at size x size. `safe` shrinks the glyph into the
    maskable safe zone; `rounded` gives the square soft corners for
    platforms that do not mask icons themselves."""
    scale = 4  # supersample, then downsample for clean edges
    s = size * scale
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    # Background: vertical violet gradient.
    bg = Image.new("RGBA", (s, s))
    bd = ImageDraw.Draw(bg)
    for y in range(s):
        t = y / max(1, s - 1)
        c = tuple(round(VIOLET[i] * (1 - t) + VIOLET_DEEP[i] * t) for i in range(3))
        bd.line([(0, y), (s, y)], fill=c + (255,))
    mask = Image.new("L", (s, s), 0)
    md = ImageDraw.Draw(mask)
    if rounded:
        md.rounded_rectangle([0, 0, s - 1, s - 1], radius=round(s * 0.225), fill=255)
    else:
        md.rectangle([0, 0, s, s], fill=255)
    img.paste(bg, (0, 0), mask)

    # Glyph.
    font = ImageFont.truetype(FONT, round(s * 0.62 * safe))
    box = d.textbbox((0, 0), "R", font=font)
    gw, gh = box[2] - box[0], box[3] - box[1]
    gx = (s - gw) / 2 - box[0] - s * 0.02 * safe
    gy = (s - gh) / 2 - box[1]
    d.text((gx, gy), "R", font=font, fill=WHITE)

    # Lime point, upper right of the glyph.
    r = s * 0.075 * safe
    cx = s / 2 + s * 0.235 * safe
    cy = s / 2 - s * 0.235 * safe
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=LIME + (255,))

    out = img.resize((size, size), Image.LANCZOS)
    if opaque:  # iOS rejects icons with an alpha channel
        flat = Image.new("RGB", (size, size), VIOLET_DEEP)
        flat.paste(out, (0, 0), out)
        return flat
    return out


def redraw(pattern, **kw):
    files = sorted(glob.glob(os.path.join(APP, pattern)))
    for f in files:
        with Image.open(f) as old:
            w, h = old.size
        render(w, **kw).save(f)
        print(f"{os.path.relpath(f, APP)}  {w}x{h}")
    return len(files)


def main():
    n = 0
    n += redraw("web/favicon.png")
    n += redraw("web/icons/Icon-[0-9]*.png")
    n += redraw("web/icons/Icon-maskable-*.png", safe=0.8, rounded=False)
    n += redraw("android/app/src/main/res/mipmap-*/ic_launcher.png")
    n += redraw("ios/Runner/Assets.xcassets/AppIcon.appiconset/*.png",
                rounded=False, opaque=True)
    n += redraw("macos/Runner/Assets.xcassets/AppIcon.appiconset/*.png")
    ico = os.path.join(APP, "windows/runner/resources/app_icon.ico")
    render(256).save(ico, sizes=[(16, 16), (24, 24), (32, 32), (48, 48),
                                 (64, 64), (128, 128), (256, 256)])
    print("windows/runner/resources/app_icon.ico  16-256")
    n += 1
    if n < 10:
        sys.exit(f"expected the Flutter icon sets, found only {n} files")


if __name__ == "__main__":
    main()
