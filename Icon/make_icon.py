"""Draws the Keyboard Viewer app icon and writes Icon/AppIcon.png and Icon/AppIcon.icns.

A graphite keyboard on a light macOS-style rounded square. Caps Lock (the Hyper
key) is lit in blue, and a few keys are tinted with the overlay's colours
(blue = app, green = keys, orange = mouse).

Run from anywhere:  python3 Icon/make_icon.py   (needs Pillow)
"""
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

S = 2048            # draw at 2x, downsample to 1024 for smooth edges
OUT = Path(__file__).resolve().parent


def px(v):
    return int(round(v * S / 1024))


def lerp(a, b, t):
    return tuple(int(round(x + (y - x) * t)) for x, y in zip(a, b))


def vertical_gradient(size, top, bottom):
    w, h = size
    grad = Image.new("RGB", (1, h))
    for y in range(h):
        grad.putpixel((0, y), lerp(top, bottom, y / max(h - 1, 1)))
    return grad.resize((w, h))


def rounded_mask(size, radius):
    m = Image.new("L", size, 0)
    ImageDraw.Draw(m).rounded_rectangle((0, 0, size[0] - 1, size[1] - 1), radius, fill=255)
    return m


def paste_shadow(canvas, box, radius, offset, blur, opacity):
    x0, y0, x1, y1 = box
    layer = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    ImageDraw.Draw(layer).rounded_rectangle(
        (x0, y0 + offset, x1, y1 + offset), radius, fill=(0, 0, 0, int(255 * opacity))
    )
    canvas.alpha_composite(layer.filter(ImageFilter.GaussianBlur(blur)))


# Simplified keyboard: five rows, each 11 units wide. Widths in key units;
# a tint name marks highlighted keys.
ROWS = [
    [(1, None)] * 11,
    [(1.5, None), (1, None), (1, "app"), (1, None), (1, None), (1, None),
     (1, None), (1, None), (1, None), (1.5, None)],
    [(1.75, "hyper"), (1, None), (1, None), (1, None), (1, None),
     (1, "keys"), (1, "keys"), (1, "keys"), (2.25, None)],
    [(2.25, None), (1, None), (1, None), (1, "mouse"), (1, None), (1, None), (1, None), (2.75, None)],
    [(1, None), (1, None), (1.25, None), (4.5, None), (1.25, None), (1, None), (1, None)],
]

KEY = (74, 80, 92)            # plain keycap
KEY_TOP = (88, 95, 108)       # lighter top face
BODY_TOP, BODY_BOTTOM = (50, 55, 64), (33, 37, 44)
TINTS = {
    "hyper": (59, 130, 246),  # solid blue: Hyper held
    "app": (59, 130, 246),
    "keys": (52, 199, 89),
    "mouse": (255, 149, 0),
}


def draw_icon():
    canvas = Image.new("RGBA", (S, S), (0, 0, 0, 0))

    # Background tile: Apple's icon grid puts an 824 pt rounded square in a 1024 canvas.
    inset, tile = px(100), px(824)
    tile_box = (inset, inset, inset + tile, inset + tile)
    paste_shadow(canvas, tile_box, px(185), px(10), px(18), 0.28)
    bg = vertical_gradient((tile, tile), (250, 251, 253), (214, 219, 228)).convert("RGBA")
    canvas.paste(bg, tile_box[:2], rounded_mask((tile, tile), px(185)))

    # Keyboard body
    u, g, pad = px(52), px(7.5), px(24)
    units = 11
    kb_w = units * u + (units - 1) * g + 2 * pad
    kb_h = 5 * u + 4 * g + 2 * pad
    kx = (S - kb_w) // 2
    ky = (S - kb_h) // 2 + px(14)
    body_box = (kx, ky, kx + kb_w, ky + kb_h)
    paste_shadow(canvas, body_box, px(40), px(22), px(26), 0.35)
    body = vertical_gradient((kb_w, kb_h), BODY_TOP, BODY_BOTTOM).convert("RGBA")
    canvas.paste(body, body_box[:2], rounded_mask((kb_w, kb_h), px(40)))

    d = ImageDraw.Draw(canvas)
    r = px(9)
    y = ky + pad
    for row in ROWS:
        x = kx + pad
        for w, tint in row:
            kw = w * u + (w - 1) * g
            box = (x, y, x + kw, y + u)
            if tint == "hyper":
                base, top = (37, 99, 235), TINTS["hyper"]
            elif tint:
                base = lerp(KEY, TINTS[tint], 0.55)
                top = lerp(KEY_TOP, TINTS[tint], 0.65)
            else:
                base, top = KEY, KEY_TOP
            # Keycap: darker skirt, lighter top face inset toward the top.
            d.rounded_rectangle(box, r, fill=base)
            d.rounded_rectangle(
                (box[0] + px(4), box[1] + px(3), box[2] - px(4), box[3] - px(8)), r - px(2), fill=top
            )
            x += kw + g
        y += u + g

    # Hyper glow around Caps Lock
    caps_x0 = kx + pad
    caps_y0 = ky + pad + 2 * (u + g)
    caps_w = 1.75 * u + 0.75 * g
    glow = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    ImageDraw.Draw(glow).rounded_rectangle(
        (caps_x0 - px(6), caps_y0 - px(6), caps_x0 + caps_w + px(6), caps_y0 + u + px(6)),
        r + px(6), fill=(59, 130, 246, 110),
    )
    glow = glow.filter(ImageFilter.GaussianBlur(px(10)))
    canvas = Image.alpha_composite(canvas, glow)
    # redraw caps key on top of the glow so it stays crisp
    d = ImageDraw.Draw(canvas)
    cbox = (caps_x0, caps_y0, caps_x0 + caps_w, caps_y0 + u)
    d.rounded_rectangle(cbox, r, fill=(37, 99, 235))
    d.rounded_rectangle(
        (cbox[0] + px(4), cbox[1] + px(3), cbox[2] - px(4), cbox[3] - px(8)), r - px(2), fill=(59, 130, 246)
    )

    return canvas.resize((1024, 1024), Image.LANCZOS)


if __name__ == "__main__":
    icon = draw_icon()
    icon.save(OUT / "AppIcon.png")
    sizes = [16, 32, 64, 128, 256, 512, 1024]
    icon.save(OUT / "AppIcon.icns", append_images=[icon.resize((s, s), Image.LANCZOS) for s in sizes])
    print("wrote", OUT / "AppIcon.png", "and", OUT / "AppIcon.icns")
