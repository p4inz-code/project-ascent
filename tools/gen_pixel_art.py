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



# Accessory worn by this render pass: "pack", "antenna", "scarf" or "none".
ACC = "pack"
# Per-frame anchors for accessories: head top-centre and a point on the back.
_ANCH = {"head": (9, 2), "back": (6, 9)}

POSE_ANCHORS = {
    "skid": ((7, 3), (4, 10)),
    "tuck": ((8, 6), (4, 9)),
    "pound": ((9, 3), (6, 8)),
    "grapple": ((8, 5), (5, 11)),
    "hang": ((9, 5), (5, 10)),
    "pull": ((9, 6), (4, 12)),
    "hurt": ((7, 3), (5, 9)),
    "flat": ((14, 13), (3, 16)),
    "slide": ((14, 11), (4, 14)),
    "wall": ((9, 5), (6, 10)),
}


def arect(d, x0, y0, x1, y1, c):
    """Scarf pixels: drawn only when the scarf accessory is selected."""
    if ACC == "scarf":
        rect(d, x0, y0, x1, y1, c)


def _accessory(d):
    """Antenna or backpack, placed from the frame's anchors."""
    hx, hy = _ANCH["head"]
    bx, by = _ANCH["back"]
    if ACC == "antenna":
        rect(d, hx, max(hy - 1, 0), hx, max(hy - 1, 0), (150, 160, 185, 255))
        rect(d, hx, max(hy - 2, 0), hx, max(hy - 2, 0), SCARF)
    elif ACC == "pack":
        rect(d, bx - 2, by, bx, by + 4, (118, 128, 152, 255))
        rect(d, bx - 2, by + 3, bx, by + 4, (84, 92, 114, 255))
        rect(d, bx - 2, by + 1, bx - 2, by + 1, SCARF)


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
    rot=0,
    dissolve=0.0,
    flash=False,
    look=0,
    slash=0,
):
    """One 16x20 frame, facing right. Origin: feet at row 18, centered col 7."""
    img = Image.new("RGBA", (CELL_W, CELL_H), CLEAR)
    d = ImageDraw.Draw(img)
    cx = 9 + lean
    top = 2 + bob + squash  # head top row
    foot = 18
    if pose in POSE_ANCHORS:
        _ANCH["head"], _ANCH["back"] = POSE_ANCHORS[pose]
    else:
        _ANCH["head"] = (cx + look + 1, top)
        _ANCH["back"] = (cx - 2, top + 8)

    if pose == "slide":
        # Low, long body skidding right.
        rect(d, 4, 13, 14, 17, SUIT)
        rect(d, 4, 16, 14, 17, SUIT_SHADE)
        rect(d, 12, 11, 16, 15, SUIT)  # head forward
        rect(d, 14, 12, 16, 13, VISOR)
        arect(d, 3, 12, 5, 13, SCARF)
        arect(d, 2, 13, 3, 14, SCARF_SHADE)
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
        arect(d, 3, 7, 6, 8, SCARF)
        _outline(img)
        return img

    if pose == "skid":
        # Braking: leaning back, boots forward and dragging.
        rect(d, 5, 3, 10, 8, SUIT)
        rect(d, 8, 4, 11, 6, VISOR)
        rect(d, 5, 7, 10, 8, SUIT_SHADE)
        rect(d, 5, 9, 10, 14, SUIT)
        rect(d, 5, 13, 10, 14, SUIT_SHADE)
        rect(d, 6, 9, 7, 12, SUIT_SHADE)
        rect(d, 9, 15, 12, 16, SUIT)
        rect(d, 10, 17, 13, 18, BOOT)
        rect(d, 5, 15, 7, 17, SUIT_SHADE)
        rect(d, 4, 17, 7, 18, BOOT)
        arect(d, 11, 6, 14, 7, SCARF)
        arect(d, 13, 5, 15, 6, SCARF_SHADE)
        _finish(img, rot, dissolve, flash)
        return img

    if pose == "tuck":
        # Curled ball: the spin uses it, rotated.
        rect(d, 5, 6, 12, 14, SUIT)
        rect(d, 5, 12, 12, 14, SUIT_SHADE)
        rect(d, 9, 7, 12, 9, VISOR)
        arect(d, 4, 10, 6, 12, SCARF)
        rect(d, 11, 13, 13, 15, BOOT)
        rect(d, 5, 13, 7, 15, BOOT)
        _finish(img, rot, dissolve, flash)
        return img

    if pose == "pound":
        # Diving straight down, fist first.
        rect(d, 7, 3, 12, 7, SUIT)
        rect(d, 10, 4, 12, 5, VISOR)
        rect(d, 7, 8, 12, 13, SUIT)
        rect(d, 7, 12, 12, 13, SUIT_SHADE)
        rect(d, 8, 14, 9, 17, SUIT_SHADE)
        rect(d, 11, 14, 12, 17, SUIT)
        rect(d, 8, 17, 12, 18, BOOT)
        arect(d, 6, 0, 7, 3, SCARF)
        arect(d, 13, 0, 14, 3, SCARF_SHADE)
        _finish(img, rot, dissolve, flash)
        return img

    if pose == "grapple":
        # One arm thrown up and forward, hook line implied.
        rect(d, 6, 5, 11, 9, SUIT)
        rect(d, 9, 6, 11, 7, VISOR)
        rect(d, 6, 10, 11, 15, SUIT)
        rect(d, 6, 14, 11, 15, SUIT_SHADE)
        rect(d, 11, 1, 12, 8, SUIT_SHADE)
        arect(d, 12, 0, 14, 1, SCARF)
        rect(d, 6, 16, 8, 18, BOOT)
        rect(d, 10, 16, 12, 18, BOOT)
        arect(d, 3, 7, 6, 8, SCARF)
        _finish(img, rot, dissolve, flash)
        return img

    if pose == "hang":
        # Hanging from a ledge by both hands (ledge at the top of the cell).
        rect(d, 6, 1, 7, 6, SUIT_SHADE)
        rect(d, 11, 1, 12, 6, SUIT_SHADE)
        rect(d, 6, 5, 12, 9, SUIT)
        rect(d, 9, 6, 12, 7, VISOR)
        rect(d, 6, 10, 12, 15, SUIT)
        rect(d, 6, 14, 12, 15, SUIT_SHADE)
        rect(d, 7, 16, 8, 18, BOOT)
        rect(d, 10, 16, 11, 18, BOOT)
        arect(d, 4, 9, 6, 10, SCARF)
        _finish(img, rot, dissolve, flash)
        return img

    if pose == "pull":
        # Mid pull-up: elbows locked, torso rising over the edge.
        rect(d, 6, 6, 12, 10, SUIT)
        rect(d, 9, 7, 12, 8, VISOR)
        rect(d, 5, 11, 12, 16, SUIT)
        rect(d, 5, 15, 12, 16, SUIT_SHADE)
        rect(d, 5, 10, 7, 12, SUIT_SHADE)
        rect(d, 11, 10, 13, 12, SUIT_SHADE)
        rect(d, 6, 17, 8, 18, BOOT)
        rect(d, 10, 17, 12, 18, BOOT)
        arect(d, 3, 8, 5, 9, SCARF)
        _finish(img, rot, dissolve, flash)
        return img

    if pose == "hurt":
        # Struck: head thrown back, arms out, boots off the ground.
        rect(d, 5, 3, 10, 7, SUIT)
        rect(d, 8, 4, 10, 5, VISOR)
        rect(d, 6, 8, 11, 13, SUIT)
        rect(d, 6, 12, 11, 13, SUIT_SHADE)
        rect(d, 3, 8, 5, 9, SUIT_SHADE)
        rect(d, 12, 7, 14, 8, SUIT_SHADE)
        rect(d, 6, 14, 7, 16, SUIT_SHADE)
        rect(d, 10, 14, 11, 16, SUIT)
        rect(d, 5, 16, 8, 17, BOOT)
        rect(d, 10, 16, 12, 17, BOOT)
        arect(d, 11, 5, 14, 6, SCARF)
        _finish(img, rot, dissolve, flash)
        return img

    if pose == "flat":
        # Lying where he fell.
        rect(d, 3, 15, 14, 18, SUIT)
        rect(d, 3, 17, 14, 18, SUIT_SHADE)
        rect(d, 12, 13, 16, 17, SUIT)
        rect(d, 14, 14, 16, 15, VISOR)
        arect(d, 1, 16, 3, 17, SCARF)
        rect(d, 5, 18, 7, 18, BOOT)
        _finish(img, rot, dissolve, flash)
        return img

    # Head
    rect(d, cx - 2 + look, top, cx + 3 + look, top + 5, SUIT)
    rect(d, cx + look, top + 1, cx + 3 + look, top + 3, VISOR)
    if visor_glint:
        px(d, cx + 1 + look, top + 1, VISOR_GLINT)
    rect(d, cx - 2 + look, top + 4, cx + 3 + look, top + 5, SUIT_SHADE)
    # Torso
    t0 = top + 6
    t1 = t0 + 5 - squash
    rect(d, cx - 2, t0, cx + 3, t1, SUIT)
    rect(d, cx - 2, t1 - 1, cx + 3, t1, SUIT_SHADE)
    # Arm (swings)
    ax = cx - 1 + arm
    if slash == 0:
        rect(d, ax, t0 + 1, ax + 1, t0 + 4, SUIT_SHADE)
    else:
        # M1 slash: 1 = wind-up (arm back and up), 2 = strike (arm out, blade lit), 3 = follow-through.
        blade = (110, 240, 255, 255)
        core = (255, 255, 255, 255)
        if slash == 1:
            rect(d, cx - 3, t0 - 2, cx - 2, t0 + 2, SUIT_SHADE)
            px(d, cx - 4, t0 - 3, blade)
            px(d, cx - 5, t0 - 4, blade)
        elif slash == 2:
            rect(d, cx + 2, t0 + 1, cx + 6, t0 + 2, SUIT_SHADE)
            rect(d, cx + 7, t0 - 2, cx + 8, t0 + 4, blade)
            rect(d, cx + 8, t0 - 1, cx + 8, t0 + 3, core)
        else:
            rect(d, cx + 2, t0 + 3, cx + 5, t0 + 4, SUIT_SHADE)
            px(d, cx + 6, t0 + 5, blade)
            px(d, cx + 7, t0 + 6, blade)
    # Legs
    l0 = t1 + 1
    ya = min(foot, l0 + 4)
    rect(d, cx - 2 + leg_a, l0, cx - 1 + leg_a, ya - 1, SUIT_SHADE)
    rect(d, cx - 2 + leg_a, ya - 1, cx + leg_a, ya, BOOT)
    rect(d, cx + 1 + leg_b, l0, cx + 2 + leg_b, ya - 1, SUIT)
    rect(d, cx + 1 + leg_b, ya - 1, cx + 3 + leg_b, ya, BOOT)
    # Scarf streaming left, rising with speed
    sy = t0 + 1 - scarf_rise
    arect(d, cx - 5, sy, cx - 2, sy + 1, SCARF)
    arect(d, cx - 7, sy + 1 - (1 if scarf_rise else 0), cx - 5, sy + 2, SCARF)
    arect(d, cx - 8, sy + 2 - scarf_rise, cx - 7, sy + 3 - scarf_rise, SCARF_SHADE)
    _finish(img, rot, dissolve, flash)
    return img


def _finish(img, rot, dissolve, flash):
    """Outline, then the optional whole-frame effects: a flash to white (hurt),
    a deterministic pixel dissolve (death / respawn) and a nearest-neighbour
    rotation (spin). All deterministic so the sheet is reproducible."""
    _accessory(ImageDraw.Draw(img))
    if flash:
        pix = img.load()
        for y in range(img.size[1]):
            for x in range(img.size[0]):
                if pix[x, y][3]:
                    pix[x, y] = (255, 255, 255, 255)
    _outline(img)
    if dissolve > 0.0:
        pix = img.load()
        for y in range(img.size[1]):
            for x in range(img.size[0]):
                # Ordered-noise threshold: stable, no RNG state.
                n = ((x * 7 + y * 13 + x * y * 3) % 17) / 17.0
                if pix[x, y][3] and n < dissolve:
                    pix[x, y] = CLEAR
    if rot:
        rotated = img.rotate(rot, resample=Image.NEAREST, center=(CELL_W // 2, 12))
        img.paste(CLEAR, (0, 0, img.size[0], img.size[1]))
        img.paste(rotated, (0, 0))


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


# (name, fps, loop, frames) - frame kwargs feed draw_player. One row per
# animation; the names are the contract with PlayerVisuals (docs/ART.md).
_RUN = [
    dict(leg_a=-2, leg_b=2, arm=1, lean=1, scarf_rise=1, bob=0),
    dict(leg_a=-1, leg_b=1, arm=1, lean=1, scarf_rise=1, bob=1),
    dict(leg_a=0, leg_b=0, arm=0, lean=1, scarf_rise=1, bob=1),
    dict(leg_a=1, leg_b=-1, arm=-1, lean=1, scarf_rise=1, bob=0),
    dict(leg_a=2, leg_b=-2, arm=-1, lean=1, scarf_rise=1, bob=0),
    dict(leg_a=1, leg_b=-1, arm=-1, lean=1, scarf_rise=1, bob=1),
    dict(leg_a=0, leg_b=0, arm=0, lean=1, scarf_rise=1, bob=1),
    dict(leg_a=-1, leg_b=1, arm=1, lean=1, scarf_rise=1, bob=0),
]
ANIMS = [
    ("idle", 6, True, [
        dict(bob=0, visor_glint=True), dict(bob=0), dict(bob=1, scarf_rise=1),
        dict(bob=1, scarf_rise=1), dict(bob=1), dict(bob=0)]),
    ("breathe", 6, False, [
        dict(bob=0, look=0), dict(bob=0, look=-1, visor_glint=True),
        dict(bob=0, look=-1), dict(bob=0, look=0, visor_glint=True)]),
    ("run", 14, True, _RUN),
    ("skid", 10, True, [dict(pose="skid"), dict(pose="skid", bob=1)]),
    ("jump", 8, False, [
        dict(leg_a=-1, leg_b=1, arm=-1, scarf_rise=0, bob=-1),
        dict(leg_a=-1, leg_b=1, arm=-1, scarf_rise=1, bob=-2)]),
    ("apex", 1, False, [dict(leg_a=0, leg_b=0, arm=0, scarf_rise=1, bob=-1)]),
    ("fall", 8, True, [
        dict(leg_a=1, leg_b=-1, arm=1, scarf_rise=2, bob=0),
        dict(leg_a=2, leg_b=-1, arm=1, scarf_rise=3, bob=0)]),
    ("land", 16, False, [dict(squash=2, bob=0), dict(squash=1, bob=0), dict(bob=0)]),
    ("wall", 8, True, [dict(pose="wall"), dict(pose="wall", bob=1)]),
    ("walljump", 14, False, [
        dict(leg_a=-1, leg_b=1, arm=-1, lean=-1, bob=-1),
        dict(leg_a=-2, leg_b=2, arm=-1, lean=0, scarf_rise=1, bob=-2),
        dict(leg_a=-1, leg_b=1, arm=0, lean=1, scarf_rise=1, bob=-1)]),
    ("dash", 20, True, [
        dict(lean=2, leg_a=-2, leg_b=2, arm=2, scarf_rise=2),
        dict(lean=2, leg_a=-2, leg_b=2, arm=2, scarf_rise=3, bob=1),
        dict(lean=2, leg_a=-2, leg_b=2, arm=2, scarf_rise=2)]),
    ("slide", 12, True, [dict(pose="slide"), dict(pose="slide", bob=1)]),
    ("pound", 14, True, [dict(pose="pound"), dict(pose="pound", bob=1), dict(pose="pound")]),
    ("spin", 24, True, [dict(pose="tuck", rot=60 * i) for i in range(6)]),
    ("grapple", 10, True, [dict(pose="grapple"), dict(pose="grapple", bob=1)]),
    ("ledge", 10, False, [dict(pose="hang"), dict(pose="hang", bob=1), dict(pose="pull")]),
    ("attack", 24, False, [
        dict(slash=1, lean=-1), dict(slash=2, lean=2, leg_a=-1, leg_b=1),
        dict(slash=3, lean=1)]),
    ("hurt", 12, False, [dict(pose="hurt", flash=True), dict(pose="hurt")]),
    ("death", 14, False, [
        dict(pose="hurt", flash=True), dict(pose="hurt"), dict(pose="flat"),
        dict(pose="flat", dissolve=0.15), dict(pose="flat", dissolve=0.35),
        dict(pose="flat", dissolve=0.55), dict(pose="flat", dissolve=0.78),
        dict(pose="flat", dissolve=0.95)]),
    ("respawn", 14, False, [
        dict(dissolve=0.95), dict(dissolve=0.8), dict(dissolve=0.6),
        dict(dissolve=0.4), dict(dissolve=0.2, visor_glint=True), dict(bob=0, visor_glint=True)]),
    ("dead", 1, False, [dict(pose="flat")]),
]


def build_player_sheet():
    global ACC
    rows = len(ANIMS)
    cols = max(len(a[3]) for a in ANIMS)
    table = {"cell": [CELL_W, CELL_H], "anims": {}}
    for r, (name, fps, loop, frames) in enumerate(ANIMS):
        table["anims"][name] = {"row": r, "frames": len(frames), "fps": fps, "loop": loop}
    sheet = None
    for acc in ("pack", "antenna", "scarf", "none"):
        ACC = acc
        sheet = Image.new("RGBA", (cols * CELL_W, rows * CELL_H), CLEAR)
        for r, (name, fps, loop, frames) in enumerate(ANIMS):
            for c, kw in enumerate(frames):
                sheet.paste(draw_player(**kw), (c * CELL_W, r * CELL_H))
        # The default sheet is the backpack; the others carry their name.
        fname = "player_sheet.png" if acc == "pack" else "player_sheet_%s.png" % acc
        sheet.save(os.path.join(OUT, fname))
    ACC = "pack"
    with open(os.path.join(OUT, "player_sheet.json"), "w") as f:
        json.dump(table, f, indent=2)
    return sheet


# --- chase NPCs: the Warden (boss) and its Sparks (minions) ------------------------

WARD_ARMOR = (112, 30, 48, 255)
WARD_PLATE = (176, 62, 80, 255)
WARD_DARK = (58, 14, 28, 255)
VISOR_AMBER = (255, 214, 96, 255)
THRUST = (255, 150, 70, 255)
THRUST_HOT = (255, 236, 160, 255)
NPC_OUTLINE = (18, 6, 12, 255)


def _npc_outline(img):
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
                    o[x, y] = NPC_OUTLINE
                    break
    img.paste(out)


def draw_warden(frame):
    """28x38 hovering sentinel, facing right. Frames 0-3 bob and flicker."""
    img = Image.new("RGBA", (28, 38), CLEAR)
    d = ImageDraw.Draw(img)
    bob = (0, 1, 1, 0)[frame % 4]
    # Hover cone and thruster flame
    for i, w in enumerate((12, 10, 8, 6, 4)):
        y = 26 + bob + i
        rect(d, 14 - w // 2, y, 14 + w // 2 - 1, y, WARD_ARMOR if i % 2 == 0 else WARD_DARK)
    flame = (2, 3, 2, 4)[frame % 4]
    rect(d, 13, 31 + bob, 14, 31 + bob + flame, THRUST)
    rect(d, 13, 31 + bob, 14, 31 + bob + max(flame - 2, 0), THRUST_HOT)
    # Torso
    rect(d, 7, 13 + bob, 20, 25 + bob, WARD_ARMOR)
    rect(d, 7, 13 + bob, 20, 14 + bob, WARD_PLATE)
    rect(d, 7, 24 + bob, 20, 25 + bob, WARD_DARK)
    rect(d, 12, 17 + bob, 15, 20 + bob, WARD_DARK)           # chest port
    rect(d, 13, 18 + bob, 14, 19 + bob, VISOR_AMBER if frame % 2 == 0 else THRUST)
    # Pauldrons
    rect(d, 2, 11 + bob, 7, 17 + bob, WARD_PLATE)
    rect(d, 2, 16 + bob, 7, 17 + bob, WARD_ARMOR)
    rect(d, 20, 11 + bob, 25, 17 + bob, WARD_PLATE)
    rect(d, 20, 16 + bob, 25, 17 + bob, WARD_ARMOR)
    # Helm
    rect(d, 9, 3 + bob, 18, 12 + bob, WARD_ARMOR)
    rect(d, 10, 2 + bob, 17, 2 + bob, WARD_ARMOR)
    rect(d, 9, 3 + bob, 18, 3 + bob, WARD_PLATE)
    # Visor slit: the part that glows
    rect(d, 10, 7 + bob, 17, 8 + bob, WARD_DARK)
    rect(d, 11, 7 + bob, 16, 8 + bob, VISOR_AMBER)
    if frame % 4 == 2:
        rect(d, 11, 7 + bob, 13, 8 + bob, THRUST_HOT)
    # Horns
    rect(d, 8, 0 + bob, 9, 3 + bob, WARD_PLATE)
    rect(d, 18, 0 + bob, 19, 3 + bob, WARD_PLATE)
    _npc_outline(img)
    return img


def draw_spark(frame):
    """16x20 small hunter: a domed drone with one big eye and a flickering tail."""
    img = Image.new("RGBA", (16, 20), CLEAR)
    d = ImageDraw.Draw(img)
    bob = (0, 1, 0, -1)[frame % 4]
    # Dome body, built row by row
    for i, (x0, x1) in enumerate(((5, 10), (3, 12), (2, 13), (2, 13), (2, 13), (3, 12), (4, 11))):
        y = 4 + bob + i
        rect(d, x0, y, x1, y, WARD_ARMOR if i > 1 else WARD_PLATE)
    # The eye
    rect(d, 5, 7 + bob, 10, 9 + bob, WARD_DARK)
    rect(d, 6, 7 + bob, 9, 9 + bob, VISOR_AMBER)
    px(d, 7 + (frame % 2), 8 + bob, THRUST_HOT)
    # Fins
    rect(d, 0, 8 + bob, 2, 10 + bob, WARD_PLATE)
    rect(d, 13, 8 + bob, 15, 10 + bob, WARD_PLATE)
    # Tail flicker
    for i in range(3):
        c = THRUST if (i + frame) % 2 == 0 else THRUST_HOT
        px(d, 7 + (i % 2), 12 + bob + i + 1, c)
        px(d, 8, 12 + bob + i + 1, THRUST)
    _npc_outline(img)
    return img


def build_npc_sheets():
    for name, fn, size in (("warden_sheet", draw_warden, (28, 38)), ("spark_sheet", draw_spark, (16, 20))):
        sheet = Image.new("RGBA", (size[0] * 4, size[1]), CLEAR)
        for f in range(4):
            sheet.paste(fn(f), (f * size[0], 0))
        sheet.save(os.path.join(OUT, name + ".png"))
        with open(os.path.join(OUT, name + ".json"), "w") as fh:
            json.dump({"cell": list(size), "frames": 4, "fps": 8}, fh, indent=2)


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


def build_cutscene_art():
    """Art for the 45 s opening (docs/design/STORYBOARD.md). All placeholder,
    all deterministic. Sizes are in art pixels on the 320x180 cutscene grid."""
    import random

    rng = random.Random(21)

    # -- planet limb 320x60: dithered bands with an amber terminator glow --
    pl = Image.new("RGBA", (320, 60), CLEAR)
    px_ = pl.load()
    bands = [(20, 44, 96), (28, 58, 120), (38, 76, 146), (60, 104, 170)]
    for y in range(60):
        # arc: the limb curves down at the edges
        for x in range(320):
            edge = int(((x - 160) / 160.0) ** 2 * 26)
            top = 6 + edge
            if y < top:
                continue
            depth = y - top
            band = min(depth // 9, len(bands) - 1)
            c = bands[band]
            if depth % 9 < 2 and (x + y) % 2 == 0 and band > 0:
                c = bands[band - 1]
            px_[x, y] = c + (255,)
        # amber atmosphere line just above the surface
    for x in range(320):
        edge = int(((x - 160) / 160.0) ** 2 * 26)
        top = 6 + edge
        for k, col in enumerate(((255, 211, 120), (214, 126, 32))):
            if 0 <= top - 1 - k < 60:
                px_[x, top - 1 - k] = col + (255,)
    pl.save(os.path.join(OUT, "cs_planet.png"))

    # -- Dawnchaser side view 40x16 --
    sh = Image.new("RGBA", (40, 16), CLEAR)
    d = ImageDraw.Draw(sh)
    white, grey, red, win = (236, 240, 248, 255), (150, 160, 184, 255), (224, 64, 72, 255), (120, 210, 255, 255)
    rect(d, 8, 4, 30, 11, white)
    rect(d, 8, 9, 30, 11, grey)
    rect(d, 30, 5, 34, 10, white)
    rect(d, 34, 6, 37, 9, red)
    rect(d, 24, 5, 28, 8, win)
    rect(d, 25, 6, 26, 7, (255, 255, 255, 255))
    rect(d, 4, 3, 8, 12, red)
    rect(d, 10, 1, 17, 3, grey)
    rect(d, 10, 12, 17, 14, grey)
    rect(d, 2, 6, 4, 9, (255, 211, 120, 255))
    _outline(sh)
    sh.save(os.path.join(OUT, "cs_ship.png"))

    # -- ship wreck pieces 20x12 x3 (hull, fin, nose) --
    for name, cols in (("hull", (white, grey)), ("fin", (red, (160, 40, 50, 255))), ("nose", (red, white))):
        pc = Image.new("RGBA", (20, 12), CLEAR)
        d = ImageDraw.Draw(pc)
        rect(d, 3, 2, 16, 9, cols[0])
        rect(d, 3, 7, 16, 9, cols[1])
        for _ in range(4):  # jagged broken edge
            px_c = (rng.randint(2, 17), rng.randint(1, 10))
            d.point(px_c, fill=CLEAR)
        _outline(pc)
        pc.save(os.path.join(OUT, f"cs_wreck_{name}.png"))

    # -- cockpit 320x180: console + round window; lights are drawn in code --
    ck = Image.new("RGBA", (320, 180), (10, 14, 30, 255))
    d = ImageDraw.Draw(ck)
    rect(d, 0, 120, 319, 179, (22, 28, 52, 255))
    rect(d, 0, 118, 319, 121, (60, 74, 120, 255))
    # window
    cx, cy, r = 160, 62, 52
    for y in range(180):
        for x in range(320):
            if (x - cx) ** 2 + (y - cy) ** 2 <= r * r:
                ck.putpixel((x, y), (6, 8, 22, 255))
    for _ in range(40):
        a = rng.random() * 6.28
        rr = rng.random() * (r - 3)
        import math
        ck.putpixel((int(cx + math.cos(a) * rr), int(cy + math.sin(a) * rr)), (200, 220, 255, 255))
    for t in range(r - 2, r + 3):  # rim
        for a in range(0, 720):
            ang = a / 720 * 6.2832
            x, y = int(cx + math.cos(ang) * t), int(cy + math.sin(ang) * t)
            if 0 <= x < 320 and 0 <= y < 180 and t >= r:
                ck.putpixel((x, y), (74, 90, 140, 255))
    # console details
    for i in range(10):
        rect(d, 20 + i * 28, 132, 36 + i * 28, 140, (34, 42, 74, 255))
        rect(d, 22 + i * 28, 134, 25 + i * 28, 137, (60, 74, 120, 255))
    rect(d, 140, 150, 180, 175, (30, 36, 64, 255))  # stick base
    ck.save(os.path.join(OUT, "cs_cockpit.png"))

    # -- Trevor bust 48x64, 2 frames (blink), facing right --
    bust = Image.new("RGBA", (96, 64), CLEAR)
    for f in range(2):
        b = Image.new("RGBA", (48, 64), CLEAR)
        d = ImageDraw.Draw(b)
        rect(d, 8, 36, 40, 63, SUIT)            # shoulders / torso
        rect(d, 8, 54, 40, 63, SUIT_SHADE)
        rect(d, 14, 8, 34, 34, SUIT)            # helmet
        rect(d, 14, 26, 34, 34, SUIT_SHADE)
        rect(d, 18, 12, 34, 28, (14, 24, 52, 255))   # visor dark
        rect(d, 20, 14, 32, 26, (60, 130, 200, 255))
        rect(d, 22, 15, 25, 18, VISOR_GLINT)
        if f == 1:   # blink: a dark bar across the eyes line
            rect(d, 20, 20, 32, 22, (14, 24, 52, 255))
        arect(d, 36, 40, 42, 50, SCARF)           # scarf-cable
        _outline(b)
        bust.paste(b, (f * 48, 0))
    bust.save(os.path.join(OUT, "cs_trevor_bust.png"))

    # -- PIP diamond 8x8 x3 pulse frames --
    pip = Image.new("RGBA", (24, 8), CLEAR)
    for f, (core, halo) in enumerate((((255, 211, 120), (214, 126, 32)), ((255, 240, 180), (255, 179, 71)), ((255, 211, 120), (214, 126, 32)))):
        d = ImageDraw.Draw(pip)
        ox = f * 8
        for dy, half in ((1, 0), (2, 1), (3, 2), (4, 2), (5, 1), (6, 0)):
            rect(d, ox + 3 - half, dy, ox + 4 + half, dy, halo + (255,))
        rect(d, ox + 3, 3, ox + 4, 4, core + (255,))
    pip.save(os.path.join(OUT, "cs_pip.png"))

    # -- the Spire: 128x360 tileable-ish vertical strip --
    sp = Image.new("RGBA", (128, 360), CLEAR)
    d = ImageDraw.Draw(sp)
    y = 0
    while y < 360:
        w = rng.choice((40, 52, 64, 76))
        h = rng.choice((22, 30, 40))
        x0 = 64 - w // 2
        rect(d, x0, y, x0 + w, min(359, y + h), (42, 47, 74, 255))
        rect(d, x0, y, x0 + 2, min(359, y + h), (74, 82, 128, 255))     # lit left face
        rect(d, x0 + w - 2, y, x0 + w, min(359, y + h), (26, 30, 52, 255))
        for _ in range(w // 8):                                           # windows
            wx, wy = rng.randint(x0 + 4, x0 + w - 6), rng.randint(y + 3, max(y + 4, y + h - 5))
            c = (255, 211, 120, 255) if rng.random() > 0.35 else (138, 150, 208, 255)
            rect(d, wx, wy, wx + 1, wy + 1, c)
        y += h
    sp.save(os.path.join(OUT, "cs_spire.png"))

    # -- dock platform 96x24 with amber lamps --
    dk = Image.new("RGBA", (96, 24), CLEAR)
    d = ImageDraw.Draw(dk)
    rect(d, 0, 6, 95, 23, (58, 66, 104, 255))
    rect(d, 0, 6, 95, 8, (138, 150, 208, 255))
    for i in range(0, 96, 16):
        rect(d, i, 12, i + 1, 23, (36, 42, 70, 255))
    for lx in (6, 46, 86):
        rect(d, lx, 2, lx + 2, 5, (255, 211, 120, 255))
    _outline(dk)
    dk.save(os.path.join(OUT, "cs_dock.png"))

    # -- gate 40x64: tall door, socket ring, amber keyhole --
    gt = Image.new("RGBA", (40, 64), CLEAR)
    d = ImageDraw.Draw(gt)
    rect(d, 4, 4, 35, 63, (60, 52, 96, 255))
    rect(d, 8, 8, 31, 63, (24, 18, 50, 255))
    rect(d, 6, 4, 33, 7, (130, 110, 210, 255))
    for i in range(10):  # socket ring of 10 dots
        import math as m2
        a = i / 10 * 6.2832
        rect(d, int(20 + m2.cos(a) * 9) , int(30 + m2.sin(a) * 9), int(20 + m2.cos(a) * 9) + 1, int(30 + m2.sin(a) * 9) + 1, (255, 211, 120, 255))
    rect(d, 19, 28, 20, 33, (255, 211, 120, 255))
    _outline(gt)
    gt.save(os.path.join(OUT, "cs_gate.png"))


if __name__ == "__main__":
    s = build_player_sheet()
    print("player_sheet.png", s.size)
    build_stone_tile()
    build_npc_sheets()
    print("stone_tile.png (16, 16)")
    print("logo.png", build_logo().size)
    build_story_sprites()
    build_cutscene_art()
    print("story + cutscene sprites")
