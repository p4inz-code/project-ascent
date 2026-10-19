"""Opening-cutscene art, version 2: the survey ship (nose right), its exhaust, Trevor's bust, the
cockpit, the Spire, the dock. Deterministic. Sizes are art pixels on the 320x180 cutscene grid;
the cutscene scales them by whole numbers (x6 at 1080p).

Run from the repo root:  python tools/gen_story_art.py
"""
import math
import os
import random

from PIL import Image, ImageDraw

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "pixel")
CLEAR = (0, 0, 0, 0)


def rect(d, x0, y0, x1, y1, c):
    d.rectangle([x0, y0, x1, y1], fill=c)


def outline(img, color=(8, 10, 24, 255)):
    """A one-pixel dark outline around every opaque pixel (4-neighbour)."""
    w, h = img.size
    src = img.copy()
    sp = src.load()
    dp = img.load()
    for y in range(h):
        for x in range(w):
            if sp[x, y][3] != 0:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < w and 0 <= ny < h and sp[nx, ny][3] != 0:
                    dp[x, y] = color
                    break


def ellipse_mask(w, h, cx, cy, rx, ry):
    return [(x, y) for y in range(h) for x in range(w) if ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 <= 1.0]


# ───────────────────────── the ship: side view, nose to the RIGHT ─────────────────────────

WHITE = (238, 242, 250, 255)
LIGHT = (205, 214, 232, 255)
GREY = (150, 160, 186, 255)
DARK = (92, 100, 130, 255)
RED = (226, 66, 74, 255)
RED_D = (164, 40, 52, 255)
GLASS = (120, 212, 255, 255)
GLASS_D = (52, 120, 190, 255)
AMBER = (255, 211, 120, 255)


def build_ship():
    w, h = 76, 28
    im = Image.new("RGBA", (w, h), CLEAR)
    d = ImageDraw.Draw(im)
    # Lower wing and dorsal fin first, so the fuselage sits on top of them.
    d.polygon([(26, 17), (50, 17), (40, 26), (22, 26)], fill=RED_D)
    d.polygon([(26, 17), (50, 17), (44, 22), (24, 22)], fill=RED)
    d.polygon([(8, 11), (22, 3), (28, 3), (22, 11)], fill=RED)
    d.polygon([(8, 11), (22, 3), (24, 3), (12, 11)], fill=RED_D)
    # Fuselage: a long body, flat at the back, tapering to a nose on the right.
    d.polygon([(8, 9), (52, 8), (66, 11), (72, 14), (66, 17), (52, 20), (8, 19)], fill=WHITE)
    d.polygon([(8, 15), (52, 15), (66, 15), (72, 14), (66, 17), (52, 20), (8, 19)], fill=LIGHT)
    d.polygon([(8, 17), (52, 18), (66, 17), (52, 20), (8, 19)], fill=GREY)
    # Nose cone, red.
    d.polygon([(62, 10), (66, 11), (72, 14), (66, 17), (62, 18)], fill=RED)
    d.polygon([(66, 11), (72, 14), (66, 17)], fill=RED_D)
    rect(d, 70, 13, 72, 14, WHITE)
    # Hull stripe and panel lines.
    rect(d, 30, 9, 35, 18, RED)
    rect(d, 32, 9, 35, 18, RED_D)
    for x in (16, 24, 44, 56):
        rect(d, x, 10, x, 18, GREY)
    # Cockpit window with a glint.
    d.polygon([(46, 10), (58, 10), (60, 13), (46, 13)], fill=GLASS_D)
    d.polygon([(46, 10), (58, 10), (59, 12), (46, 12)], fill=GLASS)
    rect(d, 48, 11, 50, 11, (255, 255, 255, 255))
    # Engine bell on the back (left), dark with a hot rim.
    rect(d, 2, 10, 8, 18, DARK)
    rect(d, 2, 10, 4, 18, (60, 66, 92, 255))
    rect(d, 4, 12, 6, 16, (30, 34, 52, 255))
    rect(d, 7, 9, 8, 19, GREY)
    # Antenna on top.
    rect(d, 40, 5, 40, 8, GREY)
    rect(d, 39, 4, 41, 4, AMBER)
    outline(im)
    return im


def build_exhaust():
    """Three flame frames, 22x14, pointing LEFT (the ship's tail is its left edge)."""
    frames = Image.new("RGBA", (22 * 3, 14), CLEAR)
    shapes = [
        [(22, 4, 12, 4), (22, 9, 12, 9), (18, 7, 4, 7)],
        [(22, 3, 8, 4), (22, 10, 8, 9), (18, 6, 2, 7)],
        [(22, 4, 14, 4), (22, 9, 14, 9), (18, 7, 6, 7)],
    ]
    for f in range(3):
        fr = Image.new("RGBA", (22, 14), CLEAR)
        d = ImageDraw.Draw(fr)
        length = (14, 20, 11)[f]
        # outer orange, inner yellow, core white.
        d.polygon([(21, 3), (21, 10), (21 - length, 7)], fill=(255, 120, 40, 255))
        d.polygon([(21, 4), (21, 9), (21 - int(length * 0.7), 7)], fill=(255, 190, 70, 255))
        d.polygon([(21, 5), (21, 8), (21 - int(length * 0.4), 7)], fill=(255, 245, 190, 255))
        frames.paste(fr, (f * 22, 0))
    return frames


# ───────────────────────── Trevor, bust ─────────────────────────

SUIT = (104, 200, 255, 255)
SUIT_S = (60, 140, 214, 255)
SUIT_D = (34, 84, 150, 255)
TRIM = (255, 179, 71, 255)
TRIM_D = (200, 120, 30, 255)
VISOR_D = (10, 16, 38, 255)
VISOR_M = (22, 44, 96, 255)
VISOR_L = (52, 110, 190, 255)
HUD = (110, 240, 255, 255)


def draw_bust(frame):
    """64x72 front-facing bust. frame 0: HUD calm (cyan). frame 1: HUD alert (amber), visor flicker."""
    w, h = 64, 72
    im = Image.new("RGBA", (w, h), CLEAR)
    d = ImageDraw.Draw(im)
    # Backpack edge behind the left shoulder, antenna behind the helmet on the right.
    rect(d, 2, 40, 12, 64, SUIT_D)
    rect(d, 3, 42, 5, 62, (24, 60, 110, 255))
    rect(d, 50, 8, 51, 22, (150, 160, 186, 255))
    rect(d, 49, 6, 52, 8, TRIM)
    # Torso and shoulders.
    d.polygon([(8, 46), (18, 40), (46, 40), (56, 46), (60, 71), (4, 71)], fill=SUIT)
    d.polygon([(8, 56), (56, 56), (60, 71), (4, 71)], fill=SUIT_S)
    d.polygon([(4, 66), (60, 66), (60, 71), (4, 71)], fill=SUIT_D)
    # Shoulder pads with trim stripes.
    d.polygon([(4, 46), (16, 40), (20, 50), (6, 56)], fill=SUIT_S)
    d.polygon([(60, 46), (48, 40), (44, 50), (58, 56)], fill=SUIT_S)
    rect(d, 6, 48, 16, 49, TRIM)
    rect(d, 48, 48, 58, 49, TRIM)
    rect(d, 7, 50, 15, 50, TRIM_D)
    rect(d, 49, 50, 57, 50, TRIM_D)
    # Chest plate: a lit panel and two status lights.
    rect(d, 24, 52, 40, 64, SUIT_D)
    rect(d, 25, 53, 39, 63, (20, 48, 96, 255))
    rect(d, 27, 56, 29, 58, (255, 90, 90, 255) if frame else (80, 255, 150, 255))
    rect(d, 32, 56, 34, 58, TRIM)
    rect(d, 36, 56, 37, 62, SUIT_S)
    # Neck ring.
    rect(d, 20, 38, 44, 43, (160, 172, 200, 255))
    rect(d, 20, 41, 44, 43, (110, 122, 150, 255))
    # Helmet: a rounded shell.
    for (x, y) in ellipse_mask(w, h, 32, 22, 22, 22):
        d.point((x, y), fill=SUIT)
    for (x, y) in ellipse_mask(w, h, 32, 22, 22, 22):
        if y > 26 or x > 40:
            d.point((x, y), fill=SUIT_S)
    for (x, y) in ellipse_mask(w, h, 32, 22, 22, 22):
        if y > 36:
            d.point((x, y), fill=SUIT_D)
    # Top highlight on the shell.
    rect(d, 22, 3, 34, 4, (190, 235, 255, 255))
    rect(d, 18, 6, 22, 7, (190, 235, 255, 255))
    # Visor: a big dark glass window.
    vis = ellipse_mask(w, h, 32, 24, 17, 14)
    for (x, y) in vis:
        d.point((x, y), fill=VISOR_D)
    for (x, y) in ellipse_mask(w, h, 32, 24, 15, 12):
        d.point((x, y), fill=VISOR_M)
    for (x, y) in ellipse_mask(w, h, 32, 28, 13, 7):
        d.point((x, y), fill=VISOR_L)
    # Reflection streaks.
    for i in range(7):
        d.point((22 + i, 14 + i // 2), fill=(230, 245, 255, 255))
        d.point((21 + i, 15 + i // 2), fill=(150, 200, 240, 255))
    rect(d, 40, 30, 43, 30, (150, 200, 240, 255))
    # HUD readout across the visor.
    col = (255, 190, 70, 255) if frame else HUD
    rect(d, 24, 22, 40, 22, col)
    rect(d, 24, 25, 34, 25, col)
    rect(d, 24, 28, 38, 28, col)
    rect(d, 40, 25, 41, 25, col)
    if frame:
        rect(d, 24, 19, 28, 19, col)
        rect(d, 24, 31, 36, 31, col)
    outline(im)
    return im


def build_bust():
    sheet = Image.new("RGBA", (128, 72), CLEAR)
    for f in range(2):
        sheet.paste(draw_bust(f), (f * 64, 0))
    return sheet


# ───────────────────────── cockpit ─────────────────────────

def build_cockpit():
    rng = random.Random(21)
    w, h = 320, 180
    im = Image.new("RGBA", (w, h), (9, 12, 28, 255))
    d = ImageDraw.Draw(im)
    # Ceiling panels and ribs.
    rect(d, 0, 0, 319, 14, (16, 22, 44, 255))
    for x in range(0, 320, 40):
        rect(d, x, 0, x + 1, 14, (30, 40, 74, 255))
    rect(d, 0, 14, 319, 15, (44, 58, 100, 255))
    # Side pillars.
    for x0 in (0, 296):
        rect(d, x0, 15, x0 + 23, 119, (14, 18, 38, 255))
        rect(d, x0 + 4, 20, x0 + 6, 110, (34, 44, 80, 255))
        for y in range(24, 110, 14):
            rect(d, x0 + 10, y, x0 + 18, y + 2, (28, 36, 66, 255))
    # Round window.
    cx, cy, r = 160, 62, 52
    for y in range(h):
        for x in range(w):
            dist = (x - cx) ** 2 + (y - cy) ** 2
            if dist <= r * r:
                im.putpixel((x, y), (5, 7, 20, 255))
    for _ in range(46):
        a = rng.random() * 6.2832
        rr = rng.random() * (r - 4)
        im.putpixel((int(cx + math.cos(a) * rr), int(cy + math.sin(a) * rr)), (205, 222, 255, 255))
    # Frame ring with rivets.
    for t in range(r, r + 5):
        for a in range(0, 1440):
            ang = a / 1440 * 6.2832
            x, y = int(cx + math.cos(ang) * t), int(cy + math.sin(ang) * t)
            if 0 <= x < w and 0 <= y < h:
                im.putpixel((x, y), (82, 98, 150, 255) if t < r + 3 else (44, 56, 98, 255))
    for k in range(16):
        ang = k / 16 * 6.2832
        x, y = int(cx + math.cos(ang) * (r + 2)), int(cy + math.sin(ang) * (r + 2))
        im.putpixel((x, y), (160, 176, 220, 255))
    # Console, with a lit lip and screens.
    rect(d, 0, 118, 319, 179, (20, 26, 50, 255))
    rect(d, 0, 118, 319, 122, (72, 88, 140, 255))
    rect(d, 0, 123, 319, 124, (36, 46, 84, 255))
    for i in range(10):
        x0 = 20 + i * 28
        rect(d, x0, 132, x0 + 16, 140, (32, 40, 72, 255))
        rect(d, x0 + 2, 134, x0 + 5, 137, (58, 72, 118, 255))
    # Two big screens at the sides of the console.
    for x0 in (26, 232):
        rect(d, x0, 146, x0 + 60, 174, (12, 16, 34, 255))
        rect(d, x0 + 2, 148, x0 + 58, 172, (16, 34, 62, 255))
        for k in range(5):
            y = 151 + k * 4
            rect(d, x0 + 5, y, x0 + 5 + rng.randint(14, 44), y, (60, 150, 200, 255))
    rect(d, 140, 150, 180, 176, (28, 34, 62, 255))   # centre stick housing
    rect(d, 156, 140, 164, 152, (80, 92, 130, 255))   # the stick itself
    # Vignette.
    for y in range(h):
        for x in range(w):
            edge = min(x, w - 1 - x, y, h - 1 - y)
            if edge < 10:
                r_, g_, b_, a_ = im.getpixel((x, y))
                k = 0.6 + 0.04 * edge
                im.putpixel((x, y), (int(r_ * k), int(g_ * k), int(b_ * k), a_))
    return im


# ───────────────────────── the Spire ─────────────────────────

def build_spire():
    """128x360 vertical strip: a tall tower of stacked tiers with balconies, lit seams and antennas."""
    rng = random.Random(33)
    w, h = 128, 360
    im = Image.new("RGBA", (w, h), CLEAR)
    d = ImageDraw.Draw(im)
    # A thin central core running the whole height, so the tiers read as one structure.
    rect(d, 58, 0, 69, h - 1, (30, 34, 60, 255))
    rect(d, 58, 0, 59, h - 1, (66, 74, 116, 255))
    y = 0
    while y < h:
        tw = rng.choice((44, 56, 68, 80))
        th = rng.choice((26, 34, 44))
        x0 = 64 - tw // 2
        y1 = min(h - 1, y + th)
        rect(d, x0, y, x0 + tw, y1, (44, 50, 80, 255))
        rect(d, x0, y, x0 + 3, y1, (82, 92, 140, 255))                 # lit left face
        rect(d, x0 + tw - 3, y, x0 + tw, y1, (24, 28, 50, 255))        # shaded right face
        rect(d, x0 - 3, y, x0 + tw + 3, y + 1, (116, 128, 190, 255))   # balcony lip
        for rx in range(x0 - 3, x0 + tw + 4, 6):                         # railing posts
            rect(d, rx, y - 2, rx, y, (88, 98, 150, 255))
        # Windows in a loose grid, mostly amber, a few cool.
        for gx in range(x0 + 6, x0 + tw - 6, 7):
            for gy in range(y + 6, y1 - 4, 8):
                if rng.random() < 0.62:
                    c = (255, 211, 120, 255) if rng.random() > 0.3 else (140, 158, 224, 255)
                    rect(d, gx, gy, gx + 2, gy + 3, c)
        # A glowing vertical seam.
        sx = x0 + tw // 2
        rect(d, sx, y + 2, sx, y1 - 2, (96, 120, 210, 255))
        y += th
    # Antennas at the very top.
    for ax, ah in ((52, 18), (76, 12)):
        rect(d, ax, 0, ax, ah, (120, 130, 180, 255))
        rect(d, ax - 1, 0, ax + 1, 1, (255, 90, 90, 255))
    outline(im, (10, 12, 28, 255))
    return im


# ───────────────────────── the dock ─────────────────────────

def build_dock():
    w, h = 112, 28
    im = Image.new("RGBA", (w, h), CLEAR)
    d = ImageDraw.Draw(im)
    rect(d, 0, 8, w - 1, h - 1, (58, 66, 104, 255))
    rect(d, 0, 8, w - 1, 10, (140, 154, 214, 255))
    rect(d, 0, 11, w - 1, 12, (96, 108, 160, 255))
    for i in range(6, w - 4, 16):
        rect(d, i, 14, i + 1, h - 1, (36, 42, 70, 255))
    # Hazard stripes on the edges.
    for x in range(0, w, 8):
        c = (255, 211, 120, 255) if (x // 8) % 2 == 0 else (30, 34, 54, 255)
        rect(d, x, 11, min(w - 1, x + 3), 12, c)
    # Landing ring marking on top.
    rect(d, 38, 8, 74, 8, (255, 211, 120, 255))
    rect(d, 52, 9, 60, 9, (255, 211, 120, 255))
    # Lamps and railing posts.
    for lx in (4, 55, 106):
        rect(d, lx, 2, lx + 2, 7, (255, 211, 120, 255))
        rect(d, lx, 2, lx + 2, 3, (255, 240, 190, 255))
    outline(im)
    return im


def main():
    os.makedirs(OUT, exist_ok=True)
    build_ship().save(os.path.join(OUT, "cs_ship.png"))
    build_exhaust().save(os.path.join(OUT, "cs_exhaust.png"))
    build_bust().save(os.path.join(OUT, "cs_trevor_bust.png"))
    build_cockpit().save(os.path.join(OUT, "cs_cockpit.png"))
    build_spire().save(os.path.join(OUT, "cs_spire.png"))
    build_dock().save(os.path.join(OUT, "cs_dock.png"))
    print("story art written")


if __name__ == "__main__":
    main()
