"""itch.io store assets from real game captures (docs/media), pixel-crisp (no smoothing).

usage: python tools/make_itch_assets.py
writes docs/itch/: cover_630x500.png (the store card), banner_1920x480.png (page header),
and copies the gallery screenshots in the order the page should show them.
"""
import os, shutil
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.join(os.path.dirname(__file__), "..")
MEDIA = os.path.join(ROOT, "docs", "media")
OUT = os.path.join(ROOT, "docs", "itch")
os.makedirs(OUT, exist_ok=True)
LOGO = Image.open(os.path.join(ROOT, "assets", "pixel", "logo.png")).convert("RGBA")
FONT = os.path.join(ROOT, "assets", "fonts", "CyberpunkCraftpixPixel.otf")
AMBER = (255, 179, 71, 255)
TEXT = (230, 236, 248, 255)


def logo(scale):
    return LOGO.resize((LOGO.width * scale, LOGO.height * scale), Image.NEAREST)


def text(img, xy, s, size, col, anchor="mm"):
    d = ImageDraw.Draw(img)
    d.fontmode = "1"      # no anti-aliasing: pixel font stays pixel
    f = ImageFont.truetype(FONT, size)
    x, y = xy
    d.text((x + 3, y + 3), s, font=f, fill=(0, 0, 0, 200), anchor=anchor)
    d.text((x, y), s, font=f, fill=col, anchor=anchor)


def shade(img, top_alpha, bottom_alpha, y0=0):
    """A vertical darkening so text reads over the scene."""
    w, h = img.size
    ov = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(ov)
    for y in range(y0, h):
        a = int(top_alpha + (bottom_alpha - top_alpha) * (y - y0) / max(1, h - y0 - 1))
        d.line([(0, y), (w, y)], fill=(4, 6, 16, a))
    return Image.alpha_composite(img, ov)


title = Image.open(os.path.join(MEDIA, "title.png")).convert("RGBA")

def hfade(img, x0, x1, alpha):
    """Darken from the left edge (alpha) to nothing at x1: a soft panel for text, no hard seam."""
    w, h = img.size
    ov = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(ov)
    for x in range(0, x1):
        a = alpha if x < x0 else int(alpha * (1.0 - (x - x0) / max(1, x1 - x0)))
        d.line([(x, 0), (x, h)], fill=(5, 7, 18, a))
    return Image.alpha_composite(img, ov)


def trevor(scale):
    """Trevor's idle frame straight from the sprite sheet, in the game's default look (EVA white, gold visor),
    at a whole-number scale: crisp, with the sheet's own transparency."""
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


ledge = title.crop((900, 866, 1800, 930))                   # brick ledge top, from the scene
# Cover 630 x 500: moon and Spire behind (cropped below the title's menu badges), Trevor on a ledge.
cover = title.crop((1000, 150, 1630, 650)).copy()
cover = shade(cover, 120, 30, 0)
cover.alpha_composite(ledge.crop((0, 0, 630, 64)), (0, 500 - 112))
ImageDraw.Draw(cover).rectangle((0, 500 - 48, 630, 500), fill=(18, 22, 44, 255))
hero = trevor(6)
cover.alpha_composite(hero, (360, 500 - 112 - hero.height + 6))
cover = Image.alpha_composite(cover, shade(Image.new("RGBA", cover.size, (0, 0, 0, 0)), 0, 170, 420))
lg = logo(2)
cover.alpha_composite(lg, ((630 - lg.width) // 2, 30))
text(cover, (315, 474), "THE TOWER RE-ROLLS EVERY TIME YOU DIE", 15, AMBER)
cover.convert("RGB").save(os.path.join(OUT, "cover_630x500.png"))

# Banner 1920 x 480: the title skyline with the menu faded out, logo and pitch on the left, Trevor 3x right.
ban = title.crop((0, 150, 1920, 630)).copy()
ban = hfade(ban, 760, 1150, 255)
ban.alpha_composite(ledge, (1020, 480 - 64))
ImageDraw.Draw(ban).rectangle((1020, 480 - 16, 1920, 480), fill=(18, 22, 44, 255))
hero_b = trevor(8)
ban.alpha_composite(hero_b, (1380, 480 - 64 - hero_b.height + 8))
lg3 = logo(4)
ban.alpha_composite(lg3, (110, 120))
text(ban, (110 + lg3.width // 2, 120 + lg3.height + 52), "40 LEVELS.  8 BOSSES.  NOTHING TO MEMORISE.", 22, TEXT)
text(ban, (110 + lg3.width // 2, 120 + lg3.height + 94), "FREE  -  WINDOWS  -  MACOS  -  LINUX  -  BROWSER", 16, AMBER)
ban.convert("RGB").save(os.path.join(OUT, "banner_1920x480.png"))

# Gallery, in page order (itch shows the first five on the page).
gallery = ["play_L22_2600.png", "level_clear.png", "play_L30_1500.png", "play_L5_3000.png", "play_L20_1500.png",
           "endless_boundary_2.png", "play_L37_2600.png", "play_L10_800.png", "settings_character.png", "briefing.png"]
for i, g in enumerate(gallery, 1):
    src = os.path.join(MEDIA, g)
    if os.path.exists(src):
        shutil.copyfile(src, os.path.join(OUT, "gallery_%02d_%s" % (i, g)))
print("ok", sorted(os.listdir(OUT)))
