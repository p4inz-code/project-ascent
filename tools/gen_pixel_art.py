"""Generates the PLACEHOLDER pixel art for the v2 redesign.

Deterministic and regenerable (same idea as tools/generate_audio.py): run it,
get the same PNGs. These are stand-ins so the game is playable in the new
style end to end; final art replaces the files in assets/pixel/ with no code
change as long as cell sizes and the frame table below are kept.

World scale: 1 art pixel = 3 world units (internal 640x360, camera zoom 1/3).

    python tools/gen_pixel_art.py
"""
import json
import os

from PIL import Image, ImageDraw

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "pixel")
os.makedirs(OUT, exist_ok=True)

CELL_W, CELL_H = 18, 20  # art pixels per player frame (room for scarf trail)

OUTLINE = (11, 22, 46, 255)
SUIT = (107, 199, 255, 255)
SUIT_SHADE = (63, 143, 214, 255)
VISOR = (235, 248, 255, 255)
VISOR_GLINT = (255, 255, 255, 255)
BOOT = (36, 59, 102, 255)
SCARF = (255, 179, 71, 255)
SCARF_SHADE = (214, 126, 32, 255)
CLEAR = (0, 0, 0, 0)


def px(d, x, y, c):
    d.point((x, y), fill=c)


def rect(d, x0, y0, x1, y1, c):
    d.rectangle((x0, y0, x1, y1), fill=c)


def draw_player(
    *,
    bob=0,
    lean=0,
    leg_a=0,
    leg_b=0,
    arm=0,
    scarf_rise=0,
    squash=0,
    visor_glint=False,
    pose="stand",
):
    """One 16x20 frame, facing right. Origin: feet at row 18, centered col 7."""
    img = Image.new("RGBA", (CELL_W, CELL_H), CLEAR)
    d = ImageDraw.Draw(img)
    cx = 9 + lean
    top = 2 + bob + squash  # head top row
    foot = 18

    if pose == "slide":
        # Low, long body skidding right.
        rect(d, 4, 13, 14, 17, SUIT)
        rect(d, 4, 16, 14, 17, SUIT_SHADE)
        rect(d, 12, 11, 16, 15, SUIT)  # head forward
        rect(d, 14, 12, 16, 13, VISOR)
        rect(d, 3, 12, 5, 13, SCARF)
        rect(d, 2, 13, 3, 14, SCARF_SHADE)
        rect(d, 5, 17, 7, 18, BOOT)
        rect(d, 11, 17, 13, 18, BOOT)
        _outline(img)
        return img

    if pose == "wall":
        # Back against a wall on the left, one hand up.
        rect(d, 7, 5, 12, 9, SUIT)  # head
        rect(d, 10, 6, 12, 7, VISOR)
        rect(d, 7, 10, 12, 15, SUIT)
        rect(d, 7, 14, 12, 15, SUIT_SHADE)
        rect(d, 6, 3, 7, 9, SUIT_SHADE)  # raised arm on the wall
        rect(d, 7, 16, 8, 18, BOOT)
        rect(d, 11, 15, 12, 17, BOOT)
        rect(d, 3, 7, 6, 8, SCARF)
        _outline(img)
        return img

    # Head
    rect(d, cx - 2, top, cx + 3, top + 5, SUIT)
    rect(d, cx, top + 1, cx + 3, top + 3, VISOR)
    if visor_glint:
        px(d, cx + 1, top + 1, VISOR_GLINT)
    rect(d, cx - 2, top + 4, cx + 3, top + 5, SUIT_SHADE)
    # Torso
    t0 = top + 6
    t1 = t0 + 5 - squash
    rect(d, cx - 2, t0, cx + 3, t1, SUIT)
    rect(d, cx - 2, t1 - 1, cx + 3, t1, SUIT_SHADE)
    # Arm (swings)
    ax = cx - 1 + arm
    rect(d, ax, t0 + 1, ax + 1, t0 + 4, SUIT_SHADE)
    # Legs
    l0 = t1 + 1
    ya = min(foot, l0 + 4)
    rect(d, cx - 2 + leg_a, l0, cx - 1 + leg_a, ya - 1, SUIT_SHADE)
    rect(d, cx - 2 + leg_a, ya - 1, cx + leg_a, ya, BOOT)
    rect(d, cx + 1 + leg_b, l0, cx + 2 + leg_b, ya - 1, SUIT)
    rect(d, cx + 1 + leg_b, ya - 1, cx + 3 + leg_b, ya, BOOT)
    # Scarf streaming left, rising with speed
    sy = t0 + 1 - scarf_rise
    rect(d, cx - 5, sy, cx - 2, sy + 1, SCARF)
    rect(d, cx - 7, sy + 1 - (1 if scarf_rise else 0), cx - 5, sy + 2, SCARF)
    rect(d, cx - 8, sy + 2 - scarf_rise, cx - 7, sy + 3 - scarf_rise, SCARF_SHADE)
    _outline(img)
    return img


def _outline(img):
    """1px dark outline around opaque pixels - the single biggest readability
    win for a small sprite against busy backgrounds."""
    w, h = img.size
    src = img.load()
    out = img.copy()
    o = out.load()
    for y in range(h):
        for x in range(w):
            if src[x, y][3] != 0:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < w and 0 <= ny < h and src[nx, ny][3] != 0:
                    o[x, y] = OUTLINE
                    break
    img.paste(out)


# (name, fps, loop, frames) - frame kwargs feed draw_player.
ANIMS = [
    ("idle", 3, True, [dict(bob=0, visor_glint=True), dict(bob=1, scarf_rise=1)]),
    (
        "run",
        12,
        True,
        [
            dict(leg_a=-1, leg_b=1, arm=1, lean=1, scarf_rise=1, bob=0),
            dict(leg_a=0, leg_b=0, arm=0, lean=1, scarf_rise=1, bob=1),
            dict(leg_a=1, leg_b=-1, arm=-1, lean=1, scarf_rise=1, bob=0),
            dict(leg_a=0, leg_b=0, arm=0, lean=1, scarf_rise=1, bob=1),
        ],
    ),
    ("jump", 1, False, [dict(leg_a=-1, leg_b=1, arm=-1, scarf_rise=0, bob=-1)]),
    ("fall", 1, False, [dict(leg_a=1, leg_b=-1, arm=1, scarf_rise=2, bob=0)]),
    ("land", 1, False, [dict(squash=2, bob=0)]),
    ("slide", 1, True, [dict(pose="slide")]),
    ("wall", 1, True, [dict(pose="wall")]),
    ("dash", 1, True, [dict(lean=2, leg_a=-2, leg_b=2, arm=2, scarf_rise=2)]),
    ("dead", 1, False, [dict(squash=2, bob=1, leg_a=2, leg_b=-2)]),
]


def build_player_sheet():
    rows = len(ANIMS)
    cols = max(len(a[3]) for a in ANIMS)
    sheet = Image.new("RGBA", (cols * CELL_W, rows * CELL_H), CLEAR)
    table = {"cell": [CELL_W, CELL_H], "anims": {}}
    for r, (name, fps, loop, frames) in enumerate(ANIMS):
        for c, kw in enumerate(frames):
            sheet.paste(draw_player(**kw), (c * CELL_W, r * CELL_H))
        table["anims"][name] = {"row": r, "frames": len(frames), "fps": fps, "loop": loop}
    sheet.save(os.path.join(OUT, "player_sheet.png"))
    with open(os.path.join(OUT, "player_sheet.json"), "w") as f:
        json.dump(table, f, indent=2)
    return sheet


def build_stone_tile():
    """16x16 grayscale brick tile. Grayscale on purpose: Polygon2D multiplies
    texture by its colour, so each level theme's platform_color tints the same
    tile and one asset serves all five acts."""
    import random

    rng = random.Random(7)
    n = 16
    img = Image.new("RGBA", (n, n), (255, 255, 255, 255))
    px_ = img.load()
    brick_h = 4
    for y in range(n):
        row = y // brick_h
        offset = 0 if row % 2 == 0 else 4
        for x in range(n):
            v = 0.93 + rng.uniform(-0.035, 0.035)
            on_mortar_row = y % brick_h == brick_h - 1
            on_mortar_col = (x + offset) % 8 == 7
            if on_mortar_row or on_mortar_col:
                v = 0.72
            elif y % brick_h == 0:
                v = min(1.0, v + 0.05)  # lit top lip of each brick
            g = int(max(0.0, min(1.0, v)) * 255)
            px_[x, y] = (g, g, g, 255)
    for cx, cy in ((3, 5), (4, 6), (11, 9), (12, 10), (12, 11)):  # hairline cracks
        g = 168
        px_[cx, cy] = (g, g, g, 255)
    img.save(os.path.join(OUT, "stone_tile.png"))
    return img


def build_logo():
    """PROJECT ASCENT wordmark in the game's own pixel font, rendered without
    anti-aliasing, with a gradient fill, a hard outline and a drop block, plus a
    small peak glyph above. Output is at art-pixel size; the game scales it
    up with nearest filtering."""
    from PIL import ImageFont

    font = ImageFont.truetype(
        os.path.join(os.path.dirname(__file__), "..", "assets", "fonts",
                     "CyberpunkCraftpixPixel.otf"), 16)
    text = "PROJECT ASCENT"
    mask = Image.new("L", (200, 30), 0)
    d = ImageDraw.Draw(mask)
    d.fontmode = "1"  # 1-bit: no anti-aliasing
    d.text((8, 6), text, font=font, fill=255)
    bbox = mask.getbbox()
    mask = mask.crop((bbox[0] - 2, bbox[1] - 2, bbox[2] + 2, bbox[3] + 2))
    w, h = mask.size
    pad = 3
    canvas = Image.new("RGBA", (w + pad * 2, h + pad * 2 + 14), (0, 0, 0, 0))
    ox, oy = pad, pad + 14
    src = mask.load()
    cv = canvas.load()
    # hard drop block (down-right), then outline, then gradient fill
    for y in range(h):
        for x in range(w):
            if src[x, y] > 0:
                for k in (1, 2):
                    cv[ox + x + k, oy + y + k] = (6, 12, 28, 255)
    for y in range(h):
        for x in range(w):
            if src[x, y] == 0:
                continue
    for y in range(h):
        for x in range(w):
            if src[x, y] > 0:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < w and 0 <= ny < h and src[nx, ny] > 0:
                    cv[ox + x, oy + y] = (11, 22, 46, 255)
                    break
    top, bot = (186, 230, 255), (51, 138, 230)
    for y in range(h):
        t = y / max(1, h - 1)
        col = tuple(int(top[i] + (bot[i] - top[i]) * t) for i in range(3)) + (255,)
        for x in range(w):
            if src[x, y] > 0:
                cv[ox + x, oy + y] = col
    # peak glyph above the wordmark, amber sun behind it
    cx = canvas.width // 2
    base = 12
    for r in range(7):
        for xx in range(-r, r + 1):
            # widest row at the base, apex up: a peak, with a sunlit left face
            y = base - 6 + r
            lit = xx <= 0
            cv[cx + xx, y] = (255, 211, 120, 255) if lit else (214, 126, 32, 255)
    cv[cx, base - 6] = (255, 255, 255, 255)
    canvas.save(os.path.join(OUT, "logo.png"))
    return canvas


def build_story_sprites():
    """Sprites for the opening cutscene: rocket (two flame frames), rift ring,
    door and orb. Art-pixel sizes; the cutscene scales them by whole numbers."""
    # Rocket 12x26, flame in a second frame stacked below.
    rk = Image.new("RGBA", (12, 34), CLEAR)
    d = ImageDraw.Draw(rk)
    white, red, grey, win, wing = (236, 240, 248, 255), (224, 64, 72, 255), (150, 160, 184, 255), (120, 210, 255, 255), (200, 70, 80, 255)
    rect(d, 4, 2, 7, 4, red)
    rect(d, 3, 5, 8, 7, red)
    rect(d, 3, 8, 8, 21, white)
    rect(d, 7, 8, 8, 21, grey)
    rect(d, 4, 10, 7, 13, win)
    rect(d, 5, 11, 6, 12, (255, 255, 255, 255))
    rect(d, 1, 16, 3, 24, wing)
    rect(d, 8, 16, 10, 24, wing)
    rect(d, 3, 22, 8, 23, grey)
    flame_a = [(5, 24, 6, 28, (255, 211, 120, 255)), (4, 24, 7, 26, (255, 150, 60, 255))]
    for x0, y0, x1, y1, c in flame_a:
        rect(d, x0, y0, x1, y1, c)
    _outline(rk)
    rk.save(os.path.join(OUT, "rocket.png"))

    # Rift: concentric dithered rings, 48x48.
    n = 48
    rf = Image.new("RGBA", (n, n), CLEAR)
    px_ = rf.load()
    import math

    for y in range(n):
        for x in range(n):
            r = math.hypot(x - n / 2 + 0.5, y - n / 2 + 0.5)
            if r > 23:
                continue
            band = int(r / 4)
            on = (x + y) % 2 == 0
            cols = [(255, 255, 255), (190, 150, 255), (130, 90, 230), (80, 50, 170), (40, 24, 110), (20, 12, 70)]
            c = cols[min(band, len(cols) - 1)]
            if band % 2 == 1 and on:
                c = cols[max(band - 1, 0)]
            px_[x, y] = c + (255,)
    rf.save(os.path.join(OUT, "rift.png"))

    # Door 16x26 with a glowing keyhole.
    dr = Image.new("RGBA", (16, 26), CLEAR)
    d = ImageDraw.Draw(dr)
    rect(d, 1, 1, 14, 25, (60, 52, 96, 255))
    rect(d, 3, 3, 12, 25, (28, 22, 58, 255))
    rect(d, 2, 1, 13, 2, (130, 110, 210, 255))
    rect(d, 7, 11, 8, 14, (255, 211, 120, 255))
    rect(d, 6, 10, 9, 10, (255, 211, 120, 255))
    _outline(dr)
    dr.save(os.path.join(OUT, "door.png"))

    # Orb 8x8.
    ob = Image.new("RGBA", (8, 8), CLEAR)
    d = ImageDraw.Draw(ob)
    rect(d, 2, 1, 5, 6, (255, 196, 64, 255))
    rect(d, 1, 2, 6, 5, (255, 196, 64, 255))
    rect(d, 2, 5, 5, 6, (214, 126, 32, 255))
    rect(d, 2, 2, 3, 3, (255, 247, 200, 255))
    _outline(ob)
    ob.save(os.path.join(OUT, "orb.png"))


if __name__ == "__main__":
    s = build_player_sheet()
    print("player_sheet.png", s.size)
    build_stone_tile()
    print("stone_tile.png (16, 16)")
    print("logo.png", build_logo().size)
    build_story_sprites()
    print("story sprites")
