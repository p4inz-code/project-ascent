"""Project Ascent marketing kit, branded P4INZ INTERACTIVE LABS / @p4inz, from real game art.

usage: python tools/make_itch_assets.py
input : docs/itch/src/keyart_bg.png (tools/capture_keyart.gd: the title scene with no menu), falls back to
        docs/media/title.png; assets/pixel/logo.png; assets/pixel/player_sheet.png; the game's pixel font.
output: docs/itch/
  cover_630x500.png        itch store card
  banner_1920x480.png      itch page header
  social_1200x630.png      link preview (X, Discord, Reddit, GitHub social preview)
  x_header_1500x500.png    X / Twitter profile header
  square_1080.png          square post (Instagram, X, Reddit)
  studio_card_1920x1080.png  "A P4INZ INTERACTIVE LABS GAME" card (trailer, press kit)
  gallery_NN_*.png         the itch gallery in page order
Everything is pixel-crisp: nearest-neighbour scaling at whole numbers, the pixel font drawn without smoothing.
"""
import os, shutil, sys
from PIL import Image, ImageDraw, ImageFont
sys.path.insert(0, os.path.dirname(__file__))
import studio_brand as brand

ROOT = os.path.join(os.path.dirname(__file__), "..")
MEDIA = os.path.join(ROOT, "docs", "media")
OUT = os.environ.get("ITCH_OUT") or os.path.join(ROOT, "docs", "itch")
os.makedirs(OUT, exist_ok=True)
FONT = os.path.join(ROOT, "assets", "fonts", "CyberpunkCraftpixPixel.otf")
LOGO = Image.open(os.path.join(ROOT, "assets", "pixel", "logo.png")).convert("RGBA")

STUDIO = "P4INZ INTERACTIVE LABS"
HANDLE = "@p4inz"
TAGLINE = "THE TOWER RE-ROLLS EVERY TIME YOU DIE"
PITCH = "40 LEVELS.  8 BOSSES.  NOTHING TO MEMORISE."
PLATFORMS = "FREE  /  WINDOWS  /  MACOS  /  LINUX  /  BROWSER"
AMBER = (255, 179, 71, 255)
CYAN = (92, 200, 255, 255)
TEXT = (230, 236, 248, 255)
DIM = (150, 165, 190, 255)
NIGHT = (6, 8, 20)

bg_path = os.path.join(OUT, "src", "keyart_bg.png")
BG = Image.open(bg_path if os.path.exists(bg_path) else os.path.join(MEDIA, "title.png")).convert("RGBA")

# the studio's rocket mark (same grid as the in-game PixelIcons.STUDIO badge)
ROCKET = [
    ".....oo.....", "....olao....", "...olaaao...", "...oaaaao...", "...oadlao...", "...oaaaao...",
    "..ooaaaaoo..", ".oaoaaaaoao.", ".oaooaaooao.", ".oo.olao.oo.", ".....ll.....", "....l..l....",
]
ROCKET_COL = {"o": (4, 7, 14, 255), "a": AMBER, "l": (255, 236, 200, 255), "d": (60, 36, 10, 255)}


def rocket(scale):
    img = Image.new("RGBA", (12 * scale, 12 * scale), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    for y, row in enumerate(ROCKET):
        for x, ch in enumerate(row):
            if ch in ROCKET_COL:
                d.rectangle((x * scale, y * scale, x * scale + scale - 1, y * scale + scale - 1), fill=ROCKET_COL[ch])
    return img


LOGO3D = brand.game_logo3d()


def logo(scale):
    """The PROJECT ASCENT logo with the brand's stepped 3D extrusion and outline, whole-number scaled."""
    return brand.up(LOGO3D, scale)


def trevor(scale):
    """Trevor's idle frame from the sprite sheet in the default look (EVA white suit, gold visor)."""
    sheet = Image.open(os.path.join(ROOT, "assets", "pixel", "player_sheet.png")).convert("RGBA")
    f = sheet.crop((0, 0, 18, 20))
    px = f.load()
    swap = {(107, 199, 255): (235, 232, 219), (63, 143, 214): (169, 167, 158), (235, 248, 255): (255, 209, 89)}
    for y in range(f.height):
        for x in range(f.width):
            r, g, b, a = px[x, y]
            if a and (r, g, b) in swap:
                px[x, y] = swap[(r, g, b)] + (a,)
    return f.resize((18 * scale, 20 * scale), Image.NEAREST)


def font(size):
    return ImageFont.truetype(FONT, size)


def text(img, xy, s, size, col, anchor="la", shadow=True):
    d = ImageDraw.Draw(img)
    d.fontmode = "1"
    f = font(size)
    x, y = xy
    if shadow:
        d.text((x + max(2, size // 8), y + max(2, size // 8)), s, font=f, fill=(0, 0, 0, 220), anchor=anchor)
    d.text((x, y), s, font=f, fill=col, anchor=anchor)


def text_w(s, size):
    return font(size).getlength(s)


def panel(img, x0, x1, alpha, from_left=True):
    """A soft dark panel: solid to x0, fading out by x1 (no hard seam)."""
    w, h = img.size
    ov = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(ov)
    for x in range(w):
        xx = x if from_left else w - 1 - x
        if xx >= x1:
            continue
        a = alpha if xx < x0 else int(alpha * (1.0 - (xx - x0) / max(1, x1 - x0)))
        d.line([(x, 0), (x, h)], fill=NIGHT + (a,))
    return Image.alpha_composite(img, ov)


def vfade(img, y0, alpha):
    w, h = img.size
    ov = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(ov)
    for y in range(y0, h):
        d.line([(0, y), (w, y)], fill=NIGHT + (int(alpha * (y - y0) / max(1, h - y0)),))
    return Image.alpha_composite(img, ov)


def studio_badge(img, x, y, scale=1, anchor_right=False, handle=True):
    """The studio lock-up (tools/studio_brand.py): rocket mark, the P4INZ wordmark, INTERACTIVE LABS, @p4inz."""
    lk = brand.lockup(2 * scale, handle=handle)
    if anchor_right:
        x = x - lk.width
    img.alpha_composite(lk, (int(x), int(y)))
    return lk.size


KEYART = os.path.exists(bg_path)
LEDGE = int(BG.height * 0.80) if KEYART else BG.height - 112   # the ledge top in key-art pixels
GROUND = 110                                                   # ledge height above the bottom of the last scene()


def scene(w, h, focus_x, ground=110):
    """A w x h window of the key art, 1:1 pixels, centred on focus_x, cropped so the ledge sits `ground` px
    above the bottom edge (or as close as the art allows)."""
    global GROUND
    x0 = max(0, min(BG.width - w, int(focus_x - w / 2)))
    if h <= BG.height:
        y0 = max(0, min(BG.height - h, LEDGE + ground - h))
        GROUND = h - (LEDGE - y0)
        return BG.crop((x0, y0, x0 + w, y0 + h)).copy()
    # taller than the art: extend the night sky upward
    out = Image.new("RGBA", (w, h), BG.getpixel((x0 + 4, 4)))
    out.alpha_composite(BG.crop((x0, 0, x0 + w, BG.height)), (0, h - BG.height))
    GROUND = BG.height - LEDGE
    return out


def put_trevor(img, cx, scale, frame=0):
    """The one hero of the asset, standing on the ledge of the last scene(), centred on cx."""
    hero = trevor_idle(scale, frame)
    img.alpha_composite(hero, (int(cx - hero.width / 2), img.height - GROUND - hero.height + scale))
    return hero


def save(img, name):
    """Write the asset at its platform size and an HD @2x copy (whole-pixel, for retina screens and press)."""
    img.convert("RGB").save(os.path.join(OUT, name))
    hd = os.path.join(OUT, "hd")
    os.makedirs(hd, exist_ok=True)
    base, ext = os.path.splitext(name)
    brand.up(img, 2).convert("RGB").save(os.path.join(hd, base + "@2x" + ext))
    print("wrote", name, img.size, "+ hd @2x")


# 1. itch cover 630 x 500. Research: one focal point, title readable as a thumbnail, almost no other words.
#    The game logo large across the top, Trevor big on his ledge, only the studio mark small at the foot.
def cover_frame(t, trevor_frame=0):
    c = scene(630, 500, 1330)
    top = Image.new("RGBA", c.size, (0, 0, 0, 0))
    ImageDraw.Draw(top).rectangle((0, 0, 630, 170), fill=NIGHT + (165,))
    c = Image.alpha_composite(c, top)
    # twinkling stars in the dark band (deterministic per frame for the GIF)
    import random
    rng = random.Random(77)
    d = ImageDraw.Draw(c)
    for i in range(26):
        sx, sy = rng.randrange(6, 624, 3), rng.randrange(6, 160, 3)
        on = (i + t) % 5 != 0
        if on:
            d.rectangle((sx, sy, sx + 2, sy + 2), fill=(220, 230, 255, 230 if (i + t) % 3 else 140))
    put_trevor(c, 330, 6, trevor_frame)
    c = vfade(c, 430, 200)
    lg = logo(3)
    c.alpha_composite(lg, ((630 - lg.width) // 2, 40))
    lk = brand.lockup(1, handle=False)
    c.alpha_composite(lk, (630 - lk.width - 16, 500 - lk.height - 14))
    return c


def trevor_idle(scale, frame):
    """Idle animation frames (sheet row 0), default look."""
    sheet = Image.open(os.path.join(ROOT, "assets", "pixel", "player_sheet.png")).convert("RGBA")
    f = sheet.crop((frame * 18, 0, frame * 18 + 18, 20))
    px = f.load()
    swap = {(107, 199, 255): (235, 232, 219), (63, 143, 214): (169, 167, 158), (235, 248, 255): (255, 209, 89)}
    for y in range(f.height):
        for x in range(f.width):
            r_, g_, b_, a_ = px[x, y]
            if a_ and (r_, g_, b_) in swap:
                px[x, y] = swap[(r_, g_, b_)] + (a_,)
    return f.resize((18 * scale, 20 * scale), Image.NEAREST)


save(cover_frame(0), "cover_630x500.png")
# animated cover (itch accepts GIF covers under 3 MB): Trevor's 6-frame idle, stars twinkling
frames = [cover_frame(t, t % 6).convert("RGB").quantize(colors=96, method=Image.MEDIANCUT) for t in range(12)]
frames[0].save(os.path.join(OUT, "cover_630x500_animated.gif"), save_all=True, append_images=frames[1:],
               duration=160, loop=0, optimize=True, disposal=1)
print("wrote cover_630x500_animated.gif", os.path.getsize(os.path.join(OUT, "cover_630x500_animated.gif")) // 1024, "KB")
# thumbnail check: how the cover reads at itch's smallest grid size
c_small = cover_frame(0).resize((315, 250), Image.NEAREST)
c_small.convert("RGB").save(os.path.join(OUT, "src", "_cover_thumb_check.png") if os.path.isdir(os.path.join(OUT, "src")) else os.path.join(OUT, "_cover_thumb_check.png"))

# 2. itch banner 1920 x 480: logo, pitch and platforms on a left panel, the scene right, studio top-right.
b = scene(1920, 480, 1250)
b = panel(b, 760, 1180, 245)
put_trevor(b, 1480, 5)
lg = logo(4)
b.alpha_composite(lg, (110, 96))
text(b, (110, 96 + lg.height + 40), PITCH, 22, TEXT)
text(b, (110, 96 + lg.height + 84), PLATFORMS, 16, AMBER)
studio_badge(b, 1880, 30, 1, anchor_right=True)
save(b, "banner_1920x480.png")

# 3. social / link preview 1200 x 630 (the image X, Discord and Reddit show for the link).
s = scene(1200, 630, 1350)
s = panel(s, 520, 880, 245)
put_trevor(s, 1010, 6)
lg = logo(3)
s.alpha_composite(lg, (64, 150))
text(s, (64, 150 + lg.height + 34), TAGLINE, 18, AMBER)
text(s, (64, 150 + lg.height + 74), PITCH, 16, TEXT)
text(s, (64, 150 + lg.height + 108), PLATFORMS, 13, DIM)
studio_badge(s, 64, 40, 1)
save(s, "social_1200x630.png")

# 4. X / Twitter header 1500 x 500 (the avatar covers the lower-left, so the text sits right).
x = scene(1500, 500, 1100)
put_trevor(x, 600, 5)
x = panel(x, 560, 900, 235, from_left=False)
lg = logo(3)
x.alpha_composite(lg, (1500 - 70 - lg.width, 110))
text(x, (1500 - 70, 110 + lg.height + 34), TAGLINE, 16, AMBER, anchor="ra")
text(x, (1500 - 70, 110 + lg.height + 70), "FREE ON ITCH.IO AND GITHUB", 14, TEXT, anchor="ra")
studio_badge(x, 1500 - 70, 400, 1, anchor_right=True)
save(x, "x_header_1500x500.png")

# 5. square post 1080 x 1080: the scene, logo centred top, Trevor 2x larger in front, studio at the foot.
q = scene(1080, 1080, 1260)
q = Image.alpha_composite(q, Image.new("RGBA", q.size, NIGHT + (60,)))
put_trevor(q, 540, 10)
q = vfade(q, 760, 250)
topq = Image.new("RGBA", q.size, (0, 0, 0, 0))
ImageDraw.Draw(topq).rectangle((0, 0, 1080, 300), fill=NIGHT + (170,))
q = Image.alpha_composite(q, topq)
lg = logo(4)
q.alpha_composite(lg, ((1080 - lg.width) // 2, 70))
text(q, (540, 70 + lg.height + 36), TAGLINE, 20, AMBER, anchor="mt")
text(q, (540, 890), PITCH, 18, TEXT, anchor="mt")
lk = brand.lockup(2)
q.alpha_composite(lk, ((1080 - lk.width) // 2, 1080 - lk.height - 36))
save(q, "square_1080.png")

# 6. studio card 1920 x 1080: the rocket and the P4INZ wordmark, "INTERACTIVE LABS", "PRESENTS" (trailer opener).
k = Image.new("RGBA", (1920, 1080), NIGHT + (255,))
star = Image.new("RGBA", k.size, (0, 0, 0, 0))
sd = ImageDraw.Draw(star)
import random
rng = random.Random(4171)
for _ in range(260):
    sx, sy = rng.randrange(0, 1920, 3), rng.randrange(0, 1080, 3)
    sd.rectangle((sx, sy, sx + 2, sy + 2), fill=(200, 215, 255, rng.randrange(60, 200)))
k = Image.alpha_composite(k, star)
st = brand.up(brand.lockup_native("stacked"), 7)
k.alpha_composite(st, ((1920 - st.width) // 2, (1080 - st.height) // 2 - 50))
pr = brand.up(brand.pixel_text("PRESENTS", brand.TEXT), 4)
k.alpha_composite(pr, ((1920 - pr.width) // 2, (1080 + st.height) // 2 + 10))
save(k, "studio_card_1920x1080.png")

# the brand board picks up the fresh kit (tier 3 row)
brand.board([os.path.join(OUT, n) for n in
             ("cover_630x500.png", "banner_1920x480.png", "social_1200x630.png", "square_1080.png")])

# Gallery, in page order (itch shows the first five on the page).
gallery = ["play_L22_2600.png", "level_clear.png", "play_L30_1500.png", "play_L5_3000.png", "play_L20_1500.png",
           "endless_boundary_2.png", "play_L37_2600.png", "play_L10_800.png", "settings_character.png", "briefing.png"]
for old in os.listdir(OUT):
    if old.startswith("gallery_"):
        os.remove(os.path.join(OUT, old))
for i, g in enumerate(gallery, 1):
    src = os.path.join(MEDIA, g)
    if os.path.exists(src):
        shutil.copyfile(src, os.path.join(OUT, "gallery_%02d_%s" % (i, g)))
print("ok")
