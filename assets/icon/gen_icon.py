"""
SonLite icon generator — 1024×1024 PNG
Design: 5 frequency bars (EQ display) on a dark gradient background.
Modern, minimal, subtly audio-related.
"""
import math
from PIL import Image, ImageDraw, ImageFilter

SIZE = 1024
OUT = "icon.png"

# ── Background gradient (top-left dark indigo → bottom-right purple) ──────────

def make_gradient(size):
    img = Image.new("RGB", (size, size))
    px = img.load()
    # From #0D0124 (top-left) to #5C2890 (bottom-right)
    c0 = (13, 1, 36)
    c1 = (92, 40, 144)
    for y in range(size):
        for x in range(size):
            t = (x + y) / (2 * (size - 1))
            r = int(c0[0] + (c1[0] - c0[0]) * t)
            g = int(c0[1] + (c1[1] - c0[1]) * t)
            b = int(c0[2] + (c1[2] - c0[2]) * t)
            px[x, y] = (r, g, b)
    return img

# ── Rounded rectangle mask ─────────────────────────────────────────────────────

def make_round_mask(size, radius):
    mask = Image.new("L", (size, size), 0)
    d = ImageDraw.Draw(mask)
    d.rounded_rectangle([0, 0, size - 1, size - 1], radius=radius, fill=255)
    return mask

# ── Main ───────────────────────────────────────────────────────────────────────

bg = make_gradient(SIZE)
mask = make_round_mask(SIZE, radius=200)

result = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
result.paste(bg, mask=mask)

draw = ImageDraw.Draw(result)

# EQ bars — 5 bars, bell-curve heights, centered
cx, cy = SIZE // 2, SIZE // 2

BAR_W   = 76          # bar width
RADIUS  = 38          # corner radius (fully round caps)
STEP    = 100         # center-to-center spacing

# (x_offset_from_center, half_height)
bars = [
    (-200, 145),
    (-100, 210),
    (   0, 280),
    ( 100, 210),
    ( 200, 145),
]

WHITE = (255, 255, 255, 255)

# Subtle shadow under bars for depth
shadow_draw = ImageDraw.Draw(result)
for dx, hh in bars:
    x = cx + dx
    shadow_draw.rounded_rectangle(
        [x - BAR_W//2 + 6, cy - hh + 6, x + BAR_W//2 + 6, cy + hh + 6],
        radius=RADIUS,
        fill=(0, 0, 0, 60),
    )

# Bars (white, slightly transparent on outer ones)
alphas = [190, 220, 255, 220, 190]
for (dx, hh), alpha in zip(bars, alphas):
    x = cx + dx
    draw.rounded_rectangle(
        [x - BAR_W//2, cy - hh, x + BAR_W//2, cy + hh],
        radius=RADIUS,
        fill=(255, 255, 255, alpha),
    )

# Subtle highlight: lighter strip on top-left of each bar
for dx, hh in bars:
    x = cx + dx
    draw.rounded_rectangle(
        [x - BAR_W//2, cy - hh, x - BAR_W//2 + 18, cy + hh],
        radius=RADIUS,
        fill=(255, 255, 255, 50),
    )

# ── Save ───────────────────────────────────────────────────────────────────────
result.save(OUT)
print(f"Icon saved: {OUT}  ({SIZE}x{SIZE})")
