"""
Generates temporary anime-style (chibi) placeholder sprites into assets/sprites/.

Usage:   python3 tools/generate_placeholder_sprites.py
Needs:   pip install pillow

You do NOT need this script once you have real art: just drop your own PNG
files (same file names) into assets/sprites/. The game scales every sprite to
the size set in src/config.lua, so any resolution works.

How the art is made (so you can tweak colours / shapes):
  * every shape is drawn at 4x size, then shrunk -> smooth anti-aliased edges
  * Sprite.part() adds a coloured outline and a cel-shaded crescent to a shape
  * Sprite.finish() adds the dark "sticker" outline around the whole sprite
"""
import functools
import math
import os
import random

from PIL import Image, ImageChops, ImageDraw, ImageFilter

OUT_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "sprites")
K = 4                       # supersampling factor
OUTLINE = (45, 25, 60)      # colour of the outer sticker outline
WHITE = (255, 255, 255)


def darker(color, factor):
    return tuple(max(0, min(255, int(v * factor))) for v in color[:3])


def star_points(cx, cy, outer, inner, points=5):
    pts = []
    for i in range(points * 2):
        radius = outer if i % 2 == 0 else inner
        angle = -math.pi / 2 + i * math.pi / points
        pts.append((cx + math.cos(angle) * radius, cy + math.sin(angle) * radius))
    return pts


def mirror(pts, width=128):
    """Mirror a point list horizontally (for symmetrical parts)."""
    return [(width - x, y) for x, y in pts]


class Sprite:
    """A square canvas with small helpers for anime-style drawing.
    All coordinates are in final-image pixels (the 4x scaling is internal)."""

    def __init__(self, size=128):
        self.size = size
        self.px = size * K
        self.img = Image.new("RGBA", (self.px, self.px), (0, 0, 0, 0))

    # ---- masks (grayscale images, 255 = inside the shape) ----------------
    def _blank(self):
        return Image.new("L", (self.px, self.px), 0)

    def ellipse(self, x0, y0, x1, y1):
        m = self._blank()
        ImageDraw.Draw(m).ellipse([x0 * K, y0 * K, x1 * K, y1 * K], fill=255)
        return m

    def poly(self, pts):
        m = self._blank()
        ImageDraw.Draw(m).polygon([(x * K, y * K) for x, y in pts], fill=255)
        return m

    def rrect(self, x0, y0, x1, y1, radius):
        m = self._blank()
        ImageDraw.Draw(m).rounded_rectangle([x0 * K, y0 * K, x1 * K, y1 * K], radius * K, fill=255)
        return m

    @staticmethod
    def union(*masks):
        return functools.reduce(ImageChops.lighter, masks)

    @staticmethod
    def inside(mask, clip):
        """Part of `mask` that is also inside `clip`."""
        return ImageChops.multiply(mask, clip)

    # ---- painting --------------------------------------------------------
    def fill(self, mask, color, alpha=255):
        layer = Image.new("RGBA", self.img.size, tuple(color[:3]) + (255,))
        layer.putalpha(mask.point(lambda v: v * alpha // 255))
        self.img.alpha_composite(layer)

    def part(self, mask, color, shade=0.78, shift=(-6, -8), line=0.4):
        """Paint one shape: coloured outline, flat colour, cel-shade crescent."""
        if line:
            grow = 2 * int(1.3 * K) + 1
            ring = ImageChops.subtract(mask.filter(ImageFilter.MaxFilter(grow)), mask)
            self.fill(ring, darker(color, line))
        self.fill(mask, color)
        if shade:
            lit = ImageChops.offset(mask, int(shift[0] * K), int(shift[1] * K))
            crescent = ImageChops.subtract(mask, lit)
            tint = darker(color, shade)
            tint = (tint[0], tint[1], min(255, int(tint[2] * 1.08)))   # cooler shadows
            self.fill(crescent, tint)

    def line(self, pts, color, width):
        ImageDraw.Draw(self.img).line([(x * K, y * K) for x, y in pts],
                                      fill=tuple(color[:3]) + (255,), width=int(width * K), joint="curve")

    def dot(self, cx, cy, r, color):
        ImageDraw.Draw(self.img).ellipse([(cx - r) * K, (cy - r) * K, (cx + r) * K, (cy + r) * K],
                                         fill=tuple(color[:3]) + (255,))

    # ---- output ----------------------------------------------------------
    def finish(self, name, outline=True):
        out = Image.new("RGBA", self.img.size, (0, 0, 0, 0))
        if outline:
            alpha = self.img.split()[3]
            grown = alpha.filter(ImageFilter.MaxFilter(2 * 2 * K + 1))
            layer = Image.new("RGBA", self.img.size, OUTLINE + (255,))
            layer.putalpha(grown)
            out.alpha_composite(layer)
        out.alpha_composite(self.img)
        small = out.convert("RGBa").resize((self.size, self.size), Image.LANCZOS).convert("RGBA")
        small.save(os.path.join(OUT_DIR, name))
        print("wrote", name)


def anime_eye(s, cx, cy, w, h, iris):
    """Big glossy anime eye: white, two-tone iris, pupil, sparkle highlights, lash line."""
    white = s.ellipse(cx - w / 2, cy - h / 2, cx + w / 2, cy + h / 2)
    s.part(white, WHITE, shade=0.88, line=0.3)
    iris_mask = s.inside(s.ellipse(cx - w * 0.42, cy - h * 0.46, cx + w * 0.42, cy + h * 0.5), white)
    s.fill(iris_mask, darker(iris, 0.65))
    glow = s.inside(s.ellipse(cx - w * 0.34, cy - h * 0.05, cx + w * 0.34, cy + h * 0.5), white)
    s.fill(glow, tuple(min(255, v + 70) for v in iris))
    s.dot(cx, cy + h * 0.04, w * 0.17, (25, 20, 60))
    s.dot(cx - w * 0.13, cy - h * 0.2, w * 0.14, WHITE)       # big sparkle
    s.dot(cx + w * 0.14, cy + h * 0.2, w * 0.07, WHITE)       # small sparkle
    s.line([(cx - w / 2, cy - h * 0.05), (cx - w * 0.3, cy - h * 0.4), (cx, cy - h / 2),
            (cx + w * 0.3, cy - h * 0.4), (cx + w / 2, cy - h * 0.05)], (40, 25, 60), 2.2)


def blush(s, x0, y0, x1, y1):
    s.fill(s.ellipse(x0, y0, x1, y1), (255, 120, 150), alpha=120)


# ---------------------------------------------------------------------------
# Characters
# ---------------------------------------------------------------------------
def make_player():
    """Chibi magical girl: pink twin tails, red bow, blue-white dress."""
    s = Sprite()
    pink, skin = (255, 150, 200), (255, 228, 212)

    s.part(s.union(s.ellipse(12, 50, 42, 114), s.ellipse(20, 40, 44, 70)), pink)      # twin tails
    s.part(s.union(s.ellipse(86, 50, 116, 114), s.ellipse(84, 40, 108, 70)), pink)
    s.part(s.rrect(52, 112, 62, 124, 3), skin)                                          # legs
    s.part(s.rrect(66, 112, 76, 124, 3), skin)
    s.part(s.ellipse(48, 117, 64, 126), (130, 80, 110))                                 # boots
    s.part(s.ellipse(64, 117, 80, 126), (130, 80, 110))
    s.part(s.poly([(46, 88), (82, 88), (98, 120), (30, 120)]), (245, 246, 255))        # dress
    s.part(s.poly([(31, 112), (97, 112), (98, 121), (30, 121)]), (110, 150, 255))      # hem
    s.part(s.ellipse(34, 94, 48, 112), skin)                                            # hands
    s.part(s.ellipse(80, 94, 94, 112), skin)
    s.part(s.ellipse(56, 90, 72, 102), (255, 90, 120))                                   # chest ribbon
    s.part(s.ellipse(24, 10, 104, 82), pink)                                            # back hair
    s.part(s.ellipse(30, 28, 98, 96), skin, shade=0.88)                                 # face
    bangs = s.poly([(28, 52), (30, 34), (42, 18), (64, 12), (86, 18), (98, 34), (100, 52),
                    (92, 64), (86, 46), (78, 62), (68, 44), (60, 62), (50, 46), (42, 64), (34, 56)])
    s.part(bangs, pink)
    s.fill(s.inside(s.ellipse(40, 16, 90, 34), bangs), (255, 210, 232), alpha=150)      # hair shine
    anime_eye(s, 50, 76, 17, 22, (70, 110, 240))
    anime_eye(s, 78, 76, 17, 22, (70, 110, 240))
    blush(s, 34, 84, 46, 91)
    blush(s, 82, 84, 94, 91)
    s.line([(60, 89), (64, 92), (68, 89)], (150, 60, 80), 1.6)                          # smile
    s.part(s.poly([(34, 22), (20, 12), (20, 34)]), (255, 80, 110))                      # bow
    s.part(s.poly([(34, 22), (48, 12), (48, 34)]), (255, 80, 110))
    s.part(s.ellipse(29, 17, 39, 27), (255, 120, 140))
    s.part(s.poly(star_points(94, 24, 9, 4)), (255, 225, 90))                           # star clip
    s.finish("player.png")


def make_player_sheet():
    """Four-frame placeholder sheet made from the generated player art."""
    source = Image.open(os.path.join(OUT_DIR, "player.png")).convert("RGBA")
    sheet = Image.new("RGBA", (source.width * 4, source.height), (0, 0, 0, 0))
    for index in range(4):
        frame = source.copy()
        # Tiny pose offsets make the placeholder visibly animate until real art replaces it.
        frame = ImageChops.offset(frame, 0, -index * 2)
        if index * 2:
            frame.paste((0, 0, 0, 0), (0, source.height - index * 2, source.width, source.height))
        sheet.alpha_composite(frame, (index * source.width, 0))
    sheet.save(os.path.join(OUT_DIR, "player_sheet.png"))
    print("wrote player_sheet.png")


def make_slime():
    """Kawaii mint slime with a leaf on its head."""
    s = Sprite()
    body = s.union(s.ellipse(8, 46, 120, 120), s.ellipse(28, 22, 100, 86))
    s.part(body, (120, 225, 170), shade=0.74)
    s.fill(s.ellipse(24, 58, 42, 78), WHITE, alpha=150)                                 # shine
    s.dot(48, 50, 3, WHITE)
    for cx in (46, 82):
        s.part(s.ellipse(cx - 9, 68, cx + 9, 96), (40, 30, 70), shade=0, line=0)
        s.dot(cx - 3, 76, 4.5, WHITE)
        s.dot(cx + 3, 89, 2.2, WHITE)
    blush(s, 24, 90, 38, 98)
    blush(s, 90, 90, 104, 98)
    s.line([(58, 95), (61, 99), (64, 96), (67, 99), (70, 95)], (50, 90, 80), 1.6)
    s.part(s.poly([(64, 26), (56, 8), (78, 12)]), (90, 200, 110))                       # leaf
    s.finish("slime.png")


def make_bat():
    """Cute chibi bat-demon with big pink eyes and tiny fangs."""
    s = Sprite()
    wing = [(40, 52), (6, 36), (14, 60), (8, 78), (26, 70), (30, 88), (46, 78)]
    s.part(s.poly(wing), (105, 65, 165))
    s.part(s.poly(mirror(wing)), (105, 65, 165))
    ear = [(42, 40), (34, 8), (62, 32)]
    s.part(s.poly(ear), (170, 120, 235))
    s.part(s.poly(mirror(ear)), (170, 120, 235))
    s.fill(s.poly([(42, 34), (40, 18), (54, 31)]), (255, 170, 205))                     # inner ears
    s.fill(s.poly(mirror([(42, 34), (40, 18), (54, 31)])), (255, 170, 205))
    s.part(s.ellipse(30, 30, 98, 102), (170, 120, 235))
    s.fill(s.ellipse(46, 70, 82, 98), (220, 190, 252))                                  # belly
    anime_eye(s, 50, 62, 17, 22, (255, 90, 140))
    anime_eye(s, 78, 62, 17, 22, (255, 90, 140))
    blush(s, 34, 76, 46, 83)
    blush(s, 82, 76, 94, 83)
    s.part(s.poly([(56, 82), (60, 94), (64, 82)]), WHITE, shade=0, line=0.5)            # fangs
    s.part(s.poly([(64, 82), (68, 94), (72, 82)]), WHITE, shade=0, line=0.5)
    s.finish("bat.png")


def make_golem():
    """Chunky stone guardian with little red horns and glowing amber eyes."""
    s = Sprite()
    stone = (165, 165, 185)
    s.part(s.rrect(8, 58, 34, 106, 9), stone)                                           # arms
    s.part(s.rrect(94, 58, 120, 106, 9), stone)
    s.part(s.rrect(36, 100, 58, 122, 6), stone)                                         # legs
    s.part(s.rrect(70, 100, 92, 122, 6), stone)
    s.part(s.rrect(28, 50, 100, 112, 14), stone)                                        # body
    horn = [(44, 18), (44, 4), (58, 14)]
    s.part(s.poly(horn), (235, 75, 85))
    s.part(s.poly(mirror(horn)), (235, 75, 85))
    s.part(s.rrect(34, 12, 94, 62, 16), stone)                                          # head
    s.fill(s.ellipse(30, 52, 60, 68), (110, 175, 100))                                  # moss
    for cx in (52, 76):
        s.part(s.ellipse(cx - 7, 32, cx + 7, 48), (255, 210, 80), shade=0.8, line=0.3)
        s.dot(cx, 41, 2.5, (80, 40, 20))
        s.dot(cx - 2, 36, 2, WHITE)
    s.line([(42, 28), (58, 33)], (60, 60, 80), 2.2)                                     # angry brows
    s.line([(86, 28), (70, 33)], (60, 60, 80), 2.2)
    s.line([(58, 54), (70, 54)], (60, 60, 80), 2)
    ring = s.ellipse(50, 70, 78, 98)
    s.line([(64, 72), (64, 96)], (255, 200, 80), 2)                                     # glowing rune
    s.line([(54, 84), (74, 84)], (255, 200, 80), 2)
    s.line([(60, 64), (56, 76), (64, 84)], (80, 80, 100), 1.6)                          # crack
    del ring
    s.finish("golem.png")


# ---------------------------------------------------------------------------
# Effects / pickups
# ---------------------------------------------------------------------------
def make_glow(name, glow, core):
    """Glowing magic orb with a 4-point sparkle (used for bolt and orbit orbs)."""
    s = Sprite(64)
    blob = s.ellipse(12, 12, 52, 52).filter(ImageFilter.GaussianBlur(5 * K))
    s.fill(blob, glow)
    s.fill(s.ellipse(20, 20, 44, 44), glow)
    s.fill(s.poly(star_points(32, 32, 30, 4, 4)), core, alpha=210)
    s.fill(s.ellipse(25, 25, 39, 39), core)
    s.finish(name, outline=False)


def make_rocket():
    """Small orange rocket pointing right, with a blue exhaust flame."""
    s = Sprite(96)
    s.part(s.ellipse(18, 28, 78, 68), (245, 92, 70), shade=0.72)
    s.part(s.poly([(68, 28), (92, 48), (68, 68)]), (255, 178, 75), shade=0.78)
    s.part(s.ellipse(50, 38, 66, 54), (120, 220, 255), shade=0.8)
    s.part(s.poly([(25, 38), (5, 28), (14, 48)]), (80, 190, 255), shade=0.75)
    s.part(s.poly([(25, 58), (5, 68), (14, 48)]), (80, 190, 255), shade=0.75)
    s.part(s.poly([(20, 42), (2, 48), (20, 54)]), (255, 220, 80), shade=0.7)
    s.finish("rocket.png")


def make_gem():
    """Faceted crystal XP gem."""
    s = Sprite(64)
    s.part(s.poly([(32, 6), (54, 24), (46, 56), (18, 56), (10, 24)]), (70, 225, 175), shade=0.7)
    s.fill(s.poly([(32, 6), (54, 24), (32, 28), (10, 24)]), (170, 255, 225))            # top facet
    s.fill(s.poly([(32, 28), (54, 24), (46, 56)]), (45, 175, 140), alpha=200)           # side facet
    s.dot(24, 20, 3, WHITE)
    s.finish("gem.png")


def make_background():
    """Seamless grass tile with soft patches, blades and tiny flowers."""
    random.seed(11)
    size, scale = 128, 2
    px = size * scale
    img = Image.new("RGBA", (px, px), (46, 78, 60, 255))
    d = ImageDraw.Draw(img)

    def wrapped(draw_fn, x, y):          # draw at 9 offsets so the tile repeats seamlessly
        for ox in (-px, 0, px):
            for oy in (-px, 0, px):
                draw_fn(x + ox, y + oy)

    for _ in range(26):                  # soft patches
        x, y, r = random.randrange(px), random.randrange(px), random.randrange(18, 46)
        col = random.choice([(52, 86, 66, 255), (41, 70, 55, 255)])
        wrapped(lambda ox, oy: d.ellipse([ox - r, oy - r * 0.7, ox + r, oy + r * 0.7], fill=col), x, y)
    for _ in range(70):                  # grass blades
        x, y = random.randrange(px), random.randrange(px)
        col = random.choice([(66, 106, 78, 255), (34, 60, 48, 255)])
        wrapped(lambda ox, oy: d.polygon([(ox, oy), (ox + 3, oy), (ox + 1, oy - 9)], fill=col), x, y)
    for _ in range(9):                   # flowers
        x, y = random.randrange(px), random.randrange(px)
        petal = random.choice([(255, 235, 240, 255), (255, 190, 215, 255), (255, 240, 170, 255)])

        def flower(ox, oy, petal=petal):
            for a in range(5):
                ang = a * math.tau / 5
                px_, py_ = ox + math.cos(ang) * 4, oy + math.sin(ang) * 4
                d.ellipse([px_ - 2.5, py_ - 2.5, px_ + 2.5, py_ + 2.5], fill=petal)
            d.ellipse([ox - 2, oy - 2, ox + 2, oy + 2], fill=(255, 200, 70, 255))
        wrapped(flower, x, y)

    img.resize((size, size), Image.LANCZOS).save(os.path.join(OUT_DIR, "background.png"))
    print("wrote background.png")


if __name__ == "__main__":
    os.makedirs(OUT_DIR, exist_ok=True)
    make_player()
    make_player_sheet()
    make_slime()
    make_bat()
    make_golem()
    make_glow("bolt.png", (80, 200, 255), (255, 255, 255))
    make_rocket()
    make_glow("orb.png", (255, 140, 190), (255, 250, 230))
    make_gem()
    make_background()
