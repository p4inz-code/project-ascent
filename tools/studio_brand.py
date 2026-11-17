"""P4INZ INTERACTIVE LABS brand system: hand-drawn pixel marks with a stepped 3D extrusion, exported HD.

Every mark is built ONCE at native pixel size (face + bevel + extrusion + outline), then scaled only by whole
numbers, so a 16 px favicon and a 4K print logo are the same pixels. The 3D look is the classic arcade
block logo: the face carries a lit top edge and a shaded bottom bevel, the body is extruded down-right in
stepped bands that darken with depth, and a 1 px dark outline wraps the whole solid.

Tiers (docs/brand/BRAND.md): 1 studio (rocket symbol, P4INZ wordmark, INTERACTIVE LABS, @p4inz),
2 game (PROJECT ASCENT logo, Trevor, palette), 3 campaign assets (tools/make_itch_assets.py).

python tools/studio_brand.py  -> docs/brand/ (studio/, game/, avatar/, favicon/, brand_board_*.png)
"""
import os
from PIL import Image, ImageDraw, ImageFont, ImageFilter

ROOT = os.path.join(os.path.dirname(__file__), "..")
SILK = os.path.join(ROOT, "assets", "fonts", "ofl", "Silkscreen-Regular.ttf")
OUT = os.path.join(ROOT, "docs", "brand")
CLEAR = (0, 0, 0, 0)

# Tier 1 palette (studio)
OUTLINE = (4, 7, 14, 255)
NIGHT = (10, 13, 24, 255)
BODY = (255, 179, 71, 255)       # amber
LIGHT = (255, 231, 176, 255)     # amber light
MID = (240, 150, 52, 255)        # bottom bevel
SHADE = (214, 126, 32, 255)      # amber shade
ACCENT = (92, 200, 255, 255)     # lab cyan
PAPER = (236, 232, 222, 255)
INK = (24, 28, 44, 255)
TEXT = (230, 236, 248, 255)
AMBER_DEPTH = [(176, 92, 22, 255), (130, 64, 18, 255), (92, 42, 14, 255), (62, 28, 10, 255)]
# Tier 2 palette (game)
ICE = (107, 199, 255, 255)
SUIT = (235, 232, 219, 255)
VISOR = (255, 209, 89, 255)
DANGER = (255, 106, 92, 255)
ICE_DEPTH = [(40, 92, 160, 255), (30, 70, 128, 255), (22, 52, 98, 255), (15, 36, 72, 255)]

# Colour themes for the studio marks (the grading test). The game palette never changes.
THEMES = {
    "amber": dict(BODY=(255, 179, 71, 255), LIGHT=(255, 231, 176, 255), MID=(240, 150, 52, 255),
                  SHADE=(214, 126, 32, 255),
                  DEPTH=[(176, 92, 22, 255), (130, 64, 18, 255), (92, 42, 14, 255), (62, 28, 10, 255)]),
    # violet, brightened for 7.2:1 contrast on the night sky (the first violet was 5.5:1 and faded in thumbnails)
    "violet": dict(BODY=(190, 150, 255, 255), LIGHT=(238, 228, 255, 255), MID=(164, 120, 246, 255),
                   SHADE=(128, 84, 222, 255),
                   DEPTH=[(98, 58, 192, 255), (74, 42, 152, 255), (54, 30, 114, 255), (36, 20, 80, 255)]),
    "magenta": dict(BODY=(255, 92, 170, 255), LIGHT=(255, 206, 230, 255), MID=(236, 66, 146, 255),
                    SHADE=(196, 40, 118, 255),
                    DEPTH=[(150, 26, 92, 255), (114, 20, 72, 255), (82, 14, 54, 255), (56, 10, 38, 255)]),
}


def set_theme(name):
    global BODY, LIGHT, MID, SHADE, AMBER_DEPTH, STUDIO_PALETTE, THEME
    t = THEMES[name]
    BODY, LIGHT, MID, SHADE, AMBER_DEPTH = t["BODY"], t["LIGHT"], t["MID"], t["SHADE"], t["DEPTH"]
    THEME = name
    STUDIO_PALETTE = [("NIGHT", NIGHT), ("BRAND", BODY), ("BRAND LIGHT", LIGHT), ("BRAND SHADE", SHADE),
                      ("OUTLINE", OUTLINE), ("LAB CYAN", ACCENT)]


STUDIO_PALETTE = [("NIGHT", NIGHT), ("AMBER", BODY), ("AMBER LIGHT", LIGHT), ("AMBER SHADE", SHADE),
                  ("OUTLINE", OUTLINE), ("LAB CYAN", ACCENT)]
GAME_PALETTE = [("SPIRE NIGHT", NIGHT), ("ICE", ICE), ("SUIT WHITE", SUIT), ("VISOR GOLD", VISOR),
                ("TRIM ORANGE", BODY), ("DANGER RED", DANGER)]

set_theme(os.environ.get("BRAND_THEME", "violet"))   # chosen by the grading test, docs/brand/BRAND.md

# Bold 6x7 glyphs: every stroke two cells wide, so nothing thins out when the mark is small.
GLYPHS = {
    "P": ["#####.", "##..##", "##..##", "#####.", "##....", "##....", "##...."],
    "4": ["##..##", "##..##", "##..##", "######", "....##", "....##", "....##"],
    "I": ["######", "..##..", "..##..", "..##..", "..##..", "..##..", "######"],
    "N": ["##..##", "###.##", "######", "##.###", "##..##", "##..##", "##..##"],
    "Z": ["######", "....##", "...##.", "..##..", ".##...", "##....", "######"],
}
GW = 6
# The rocket: pointed nose, a cyan porthole, swept fins, a two-tone flame. l lit side, a body, s shaded side,
# w porthole, f fin, y flame core, r flame tip.
ROCKET = [
    ".....la.....",
    "....llas....",
    "...llaaas...",
    "...laaaas...",
    "...lawwas...",
    "...lawwas...",
    "...laaaas...",
    "..flaaaasf..",
    ".fflaaaasff.",
    ".ff.laas.ff.",
    ".....yy.....",
    "....yrry....",
    ".....rr.....",
]


# ---------------------------------------------------------------- engine
def up(img, s):
    """Whole-number nearest-neighbour scale: the only way marks are ever resized."""
    s = max(1, int(s))
    return img if s == 1 else img.resize((img.width * s, img.height * s), Image.NEAREST)


def solid(img):
    return img.split()[3].point(lambda v: 255 if v > 0 else 0)


def outline(img, col=OUTLINE):
    """Wrap the solid in a 1 px outline (8-neighbour), growing the canvas by 1 px each side."""
    out = Image.new("RGBA", (img.width + 2, img.height + 2), CLEAR)
    out.paste(img, (1, 1))
    a = solid(out)
    ring = Image.eval(a.filter(ImageFilter.MaxFilter(3)), lambda v: v)
    ring = Image.composite(ring, Image.new("L", a.size, 0), Image.eval(a, lambda v: 255 - v))
    out.paste(Image.new("RGBA", out.size, col), (0, 0), ring)
    return out


def extrude(img, depth, bands, dx=1, dy=1):
    """The 3D step: the silhouette repeated down-right `depth` times in bands (nearest = lightest)."""
    if depth <= 0:
        return img
    out = Image.new("RGBA", (img.width + depth * dx, img.height + depth * dy), CLEAR)
    a = solid(img)
    for k in range(depth, 0, -1):
        col = bands[min(k - 1, len(bands) - 1)]
        out.paste(Image.new("RGBA", img.size, col), (k * dx, k * dy), a)
    out.alpha_composite(img, (0, 0))
    return out


def grid(rows, cell, colours):
    h, w = len(rows), max(len(r) for r in rows)
    img = Image.new("RGBA", (w * cell, h * cell), CLEAR)
    d = ImageDraw.Draw(img)
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch in colours and colours[ch][3]:
                d.rectangle((x * cell, y * cell, x * cell + cell - 1, y * cell + cell - 1), fill=colours[ch])
    return img


def silk(size):
    return ImageFont.truetype(SILK, size)


def pixel_text(s, col, size=8, depth=1, depth_col=OUTLINE):
    """Silkscreen at its native 8 px grid (crisp, no smoothing) with a 1 px drop for depth."""
    f = silk(size)
    l, t, r, b = f.getbbox(s)
    img = Image.new("RGBA", (r - l + 1, b - t + 1), CLEAR)
    d = ImageDraw.Draw(img)
    d.fontmode = "1"
    d.text((-l, -t), s, font=f, fill=col)
    return extrude(img, depth, [depth_col], 1, 1) if depth else img


# ---------------------------------------------------------------- tier 1 marks (native pixels)
def wordmark_face(c=1, col=None):
    """Flat P4INZ face: lit top edges, shaded bottom bevel (or one colour when col is given)."""
    gap = 2
    w, h = 5 * GW + 4 * gap, 7
    face = [[False] * w for _ in range(h)]
    for i, ch in enumerate("P4INZ"):
        for y in range(7):
            for x in range(GW):
                if GLYPHS[ch][y][x] == "#":
                    face[y][i * (GW + gap) + x] = True
    rows = []
    for y in range(h):
        row = ""
        for x in range(w):
            if not face[y][x]:
                row += "."
            elif col:
                row += "b"
            elif y == 0 or not face[y - 1][x]:
                row += "l"
            elif y == h - 1 or not face[y + 1][x]:
                row += "m"
            else:
                row += "b"
        rows.append(row)
    cols = {"b": col or BODY, "l": col or LIGHT, "m": col or MID}
    return grid(rows, c, cols)


def wordmark3d(c=2, depth=3):
    return outline(extrude(wordmark_face(c), depth, AMBER_DEPTH))


def wordmark_flat(col, c=2):
    return wordmark_face(c, col)


def rocket_face(c=1, col=None):
    cols = {"l": LIGHT, "a": BODY, "s": SHADE, "w": ACCENT, "f": (200, 84, 40, 255), "y": LIGHT,
            "r": (255, 106, 92, 255)}
    if col:
        cols = {k: col for k in cols}
        cols["w"] = CLEAR
    return grid(ROCKET, c, cols)


def rocket3d(c=2, depth=2):
    return outline(extrude(rocket_face(c), depth, AMBER_DEPTH))


def rocket_flat(col, c=2):
    return rocket_face(c, col)


def lockup_native(kind="full", sub_col=TEXT, mono=None):
    """kind: full (symbol + wordmark + descriptor + handle), compact (no handle), stacked (centred, for squares).
    mono: one flat colour, no depth, no outline (print, overlays)."""
    if mono:
        r, wm = rocket_flat(mono), wordmark_flat(mono)
        sub = pixel_text("INTERACTIVE LABS", mono, depth=0)
        hdl = pixel_text("@p4inz", mono, depth=0)
    else:
        r, wm = rocket3d(), wordmark3d()
        sub = pixel_text("INTERACTIVE LABS", sub_col, depth_col=OUTLINE if sub_col != INK else (180, 176, 168, 255))
        hdl = pixel_text("@p4inz", SHADE if sub_col == INK else BODY,
                         depth_col=OUTLINE if sub_col != INK else (180, 176, 168, 255))
    if kind == "stacked":
        parts = [r, wm, sub] + ([hdl] if not mono or True else [])
        w = max(p.width for p in parts)
        gaps = [6, 5, 4]
        h = sum(p.height for p in parts) + sum(gaps[:len(parts) - 1])
        img = Image.new("RGBA", (w, h), CLEAR)
        y = 0
        for i, p in enumerate(parts):
            img.alpha_composite(p, ((w - p.width) // 2, y))
            y += p.height + (gaps[i] if i < len(gaps) else 0)
        return img
    col_h = wm.height + 4 + sub.height + (4 + hdl.height if kind == "full" else 0)
    w = r.width + 6 + max(wm.width, sub.width, hdl.width)
    h = max(r.height, col_h)
    img = Image.new("RGBA", (w, h), CLEAR)
    img.alpha_composite(r, (0, (h - r.height) // 2))
    x, y = r.width + 6, (h - col_h) // 2
    img.alpha_composite(wm, (x, y))
    img.alpha_composite(sub, (x + 1, y + wm.height + 4))
    if kind == "full":
        img.alpha_composite(hdl, (x + 1, y + wm.height + 4 + sub.height + 4))
    return img


# ---------------------------------------------------------------- tier 2 marks
def game_logo_native():
    return Image.open(os.path.join(ROOT, "assets", "pixel", "logo.png")).convert("RGBA")


def game_logo3d(depth=3):
    return outline(extrude(game_logo_native(), depth, ICE_DEPTH))


def trevor_native(frame=0):
    """Trevor's idle frame in the default look (EVA white suit, gold visor), from the real sprite sheet."""
    sheet = Image.open(os.path.join(ROOT, "assets", "pixel", "player_sheet.png")).convert("RGBA")
    f = sheet.crop((frame * 18, 0, frame * 18 + 18, 20))
    px = f.load()
    swap = {(107, 199, 255): (235, 232, 219), (63, 143, 214): (169, 167, 158), (235, 248, 255): (255, 209, 89)}
    for y in range(f.height):
        for x in range(f.width):
            r_, g_, b_, a_ = px[x, y]
            if a_ and (r_, g_, b_) in swap:
                px[x, y] = swap[(r_, g_, b_)] + (a_,)
    return f


# ---------------------------------------------------------------- compatibility (kit script)
def wordmark(cell=6, mono=None):
    return up(wordmark_flat(mono, 1) if mono else wordmark3d(1, 2), cell)


def rocket(cell=4, mono=None):
    return up(rocket_flat(mono, 1) if mono else rocket3d(1, 1), cell)


def lockup(scale=1, handle=True, sub_col=TEXT):
    return up(lockup_native("full" if handle else "compact", sub_col), scale)


def draw_text(img, xy, s, size, col, anchor="la", shadow=True):
    d = ImageDraw.Draw(img)
    d.fontmode = "1"
    if shadow:
        o = max(2, size // 8)
        d.text((xy[0] + o, xy[1] + o), s, font=silk(size), fill=(0, 0, 0, 220), anchor=anchor)
    d.text(xy, s, font=silk(size), fill=col, anchor=anchor)


# ---------------------------------------------------------------- exports
def ladder(img, folder, name, widths=(3840, 2048, 1024, 512, 256)):
    """Save the largest whole-number scale that fits each target width (HD first, smallest last)."""
    os.makedirs(folder, exist_ok=True)
    done = set()
    for tw in widths:
        s = max(1, tw // img.width)
        if s in done:
            continue
        done.add(s)
        up(img, s).save(os.path.join(folder, "%s_%dw.png" % (name, img.width * s)))


def on(bg, img, pad):
    out = Image.new("RGBA", (img.width + 2 * pad, img.height + 2 * pad), bg)
    out.alpha_composite(img, (pad, pad))
    return out


def avatar_native():
    """64 x 64 profile mark: the 3D rocket on night inside a pixel ring."""
    av = Image.new("RGBA", (64, 64), NIGHT)
    d = ImageDraw.Draw(av)
    d.ellipse((2, 2, 61, 61), fill=AMBER_DEPTH[2])
    d.ellipse((4, 4, 59, 59), fill=NIGHT)
    rk = rocket3d(3, 2)
    av.alpha_composite(rk, ((64 - rk.width) // 2, (64 - rk.height) // 2 - 1))
    return av


def favicon_native():
    ic = Image.new("RGBA", (16, 16), NIGHT)
    rk = rocket3d(1, 1)
    ic.alpha_composite(rk, ((16 - rk.width) // 2, (16 - rk.height) // 2))
    return ic


def swatch_row(img, x, y, palette, size, label_size):
    d = ImageDraw.Draw(img)
    d.fontmode = "1"
    for i, (name, col) in enumerate(palette):
        sx = x + i * (size + 18)
        d.rectangle((sx, y, sx + size - 1, y + size - 1), fill=col, outline=(60, 70, 96, 255))
        d.text((sx, y + size + 10), name, font=silk(label_size), fill=TEXT)
        d.text((sx, y + size + 10 + label_size + 6), "#%02X%02X%02X" % col[:3], font=silk(label_size), fill=(150, 165, 190, 255))


def label(img, xy, s, size=16, col=ACCENT):
    d = ImageDraw.Draw(img)
    d.fontmode = "1"
    d.text(xy, s, font=silk(size), fill=col)


def board(kit=None):
    """The brand board (1920 x 1080 composed, also saved at 3840 x 2160): all three tiers on one page."""
    W, H = 1920, 1080
    b = Image.new("RGBA", (W, H), NIGHT)
    d = ImageDraw.Draw(b)
    # header
    hdr = up(lockup_native("compact"), 2)
    b.alpha_composite(hdr, (64, 40))
    d.rectangle((64, 150, W - 64, 152), fill=(36, 48, 78, 255))
    hd = ImageDraw.Draw(b)
    hd.fontmode = "1"
    hd.text((W - 64, 56), "BRAND SYSTEM", font=silk(32), fill=TEXT, anchor="ra")
    hd.text((W - 64, 100), "VISUAL IDENTITY  /  2026", font=silk(16), fill=(150, 165, 190, 255), anchor="ra")
    # tier 1
    label(b, (64, 180), "01  STUDIO  /  P4INZ INTERACTIVE LABS", 16)
    full = up(lockup_native("full"), 4)
    b.alpha_composite(full, (64, 220))
    y1 = 220 + full.height + 30
    chip = on(PAPER, up(lockup_native("full", sub_col=INK), 2), 18)
    b.alpha_composite(chip, (64, y1))
    mono = on(BODY, up(lockup_native("full", mono=NIGHT), 2), 18)
    b.alpha_composite(mono, (64 + chip.width + 20, y1))
    # symbol ladder
    # symbol ladder at true sizes: avatar 128 and 64, favicon 32 and 16
    sx, base = 64 + 6 * (64 + 18) + 30, y1 + 180 + 128
    label(b, (sx, y1 + 180 - 26), "SYMBOL  128 / 64 / 32 / 16", 8, (150, 165, 190, 255))
    for im in (up(avatar_native(), 2), avatar_native(), up(favicon_native(), 2), favicon_native()):
        b.alpha_composite(im, (sx, base - im.height))
        sx += im.width + 14
    swatch_row(b, 64, y1 + 180, STUDIO_PALETTE, 64, 8)
    # tier 2
    x2 = 1010
    d.rectangle((x2 - 40, 180, x2 - 38, 760), fill=(36, 48, 78, 255))
    label(b, (x2, 180), "02  GAME  /  PROJECT ASCENT", 16)
    lg = up(game_logo3d(), 5)
    b.alpha_composite(lg, (x2, 230))
    tv = up(trevor_native(), 8)
    ty = 230 + lg.height + 30
    b.alpha_composite(tv, (x2, ty))
    hd.text((x2 + tv.width + 30, ty + 30), "TREVOR", font=silk(24), fill=SUIT)
    hd.text((x2 + tv.width + 30, ty + 70), "EVA SUIT  /  GOLD VISOR  /  ORANGE SCARF", font=silk(8), fill=(150, 165, 190, 255))
    hd.text((x2 + tv.width + 30, ty + 100), "THE TOWER RE-ROLLS", font=silk(16), fill=BODY)
    hd.text((x2 + tv.width + 30, ty + 124), "EVERY TIME YOU DIE", font=silk(16), fill=BODY)
    swatch_row(b, x2, ty + tv.height + 30, GAME_PALETTE, 64, 8)
    # tier 3
    d.rectangle((64, 790, W - 64, 792), fill=(36, 48, 78, 255))
    label(b, (64, 812), "03  CAMPAIGN  /  BUILT FROM TIERS 1 AND 2", 16)
    kx = 64
    for p in (kit or []):
        if not os.path.exists(p):
            continue
        im = Image.open(p).convert("RGBA")
        f = max(1, -(-im.height // 200))
        th = im.reduce(f)
        if kx + th.width > W - 64:
            break
        b.alpha_composite(th, (kx, 850))
        d.rectangle((kx - 1, 849, kx + th.width, 850 + th.height), outline=(60, 70, 96, 255))
        kx += th.width + 20
    hd.text((W - 64, H - 40), "@p4inz", font=silk(16), fill=BODY, anchor="rs")
    b.convert("RGB").save(os.path.join(OUT, "brand_board_1920x1080.png"))
    up(b, 2).convert("RGB").save(os.path.join(OUT, "brand_board_3840x2160.png"))
    return b


def export_all():
    os.makedirs(OUT, exist_ok=True)
    for old in ("p4inz_wordmark.png", "p4inz_wordmark_white.png", "p4inz_lockup.png", "p4inz_avatar_400.png",
                "p4inz_icon_16.png", "p4inz_icon_32.png", "p4inz_icon_64.png", "_review_sheet.png"):
        p = os.path.join(OUT, old)
        if os.path.exists(p):
            os.remove(p)
    st = os.path.join(OUT, "studio")
    ladder(lockup_native("full"), st, "p4inz_lockup_full_3d")
    ladder(lockup_native("compact"), st, "p4inz_lockup_compact_3d")
    ladder(lockup_native("stacked"), st, "p4inz_lockup_stacked_3d", (2048, 1024, 512, 256))
    ladder(lockup_native("full", sub_col=INK), st, "p4inz_lockup_full_3d_on_light")
    ladder(lockup_native("full", mono=(255, 255, 255, 255)), st, "p4inz_lockup_mono_white")
    ladder(lockup_native("full", mono=NIGHT), st, "p4inz_lockup_mono_black")
    ladder(wordmark3d(), st, "p4inz_wordmark_3d")
    ladder(wordmark_flat(BODY), st, "p4inz_wordmark_flat")
    ladder(rocket3d(), st, "p4inz_symbol_3d", (2048, 1024, 512, 256, 128))
    gm = os.path.join(OUT, "game")
    ladder(game_logo3d(), gm, "project_ascent_logo_3d")
    ladder(game_logo_native(), gm, "project_ascent_logo_flat")
    ladder(on(NIGHT, game_logo3d(), 12), gm, "project_ascent_logo_3d_on_night")
    ladder(trevor_native(), gm, "trevor_idle", (2048, 1024, 512, 256))
    av = os.path.join(OUT, "avatar")
    os.makedirs(av, exist_ok=True)
    for s in (32, 16, 8, 4, 2, 1):
        up(avatar_native(), s).save(os.path.join(av, "p4inz_avatar_%d.png" % (64 * s)))
    fv = os.path.join(OUT, "favicon")
    os.makedirs(fv, exist_ok=True)
    for s in (16, 8, 4, 3, 2, 1):
        up(favicon_native(), s).save(os.path.join(fv, "p4inz_favicon_%d.png" % (16 * s)))
    favicon_native().save(os.path.join(fv, "favicon.ico"), sizes=[(16, 16)])
    up(favicon_native(), 2).save(os.path.join(fv, "favicon_32.ico"), sizes=[(32, 32)])


if __name__ == "__main__":
    export_all()
    kit = [os.path.join(ROOT, "docs", "itch", n) for n in
           ("cover_630x500.png", "banner_1920x480.png", "social_1200x630.png", "square_1080.png")]
    board(kit)
    for dp, _, fs in os.walk(OUT):
        for f in sorted(fs):
            if f.endswith((".png", ".ico")):
                print(os.path.relpath(os.path.join(dp, f), OUT))
