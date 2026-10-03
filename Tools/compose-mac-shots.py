#!/usr/bin/env python3
"""Composes the Mac App Store screenshots (2880x1800) from the off-screen renders of Tools/mac-store-shots.sh.

  compose-mac-shots.py <raw-dir> <out-dir> <lang: it|en>
"""
import sys
from PIL import Image, ImageDraw, ImageFilter, ImageFont

RAW, OUT, LANG = sys.argv[1], sys.argv[2], sys.argv[3]
W, H, K = 2880, 1800, 0.8          # renders are 3x: K brings them to 2.4x
BG, INK, MUTED, ACCENT = (242, 242, 244), (28, 28, 30), (110, 110, 118), (217, 119, 46)
TEXT = {
    "it": [("Note, link e file a un clic dalla barra dei menu", "File Markdown in una cartella che scegli tu. Nessun database, nessun account.",
            "Riunione di progetto"),
           ("Nascondi fino a una data, o fatti ricordare", "Ogni elemento può sparire dalla lista fino a quando serve, e tornare con una notifica.",
            "Preferenze")],
    "en": [("Notes, links and files one click away in the menu bar", "Markdown files in a folder you choose. No database, no account.",
            "Project meeting"),
           ("Hide until a date, or get a reminder", "Any item can leave the list until you need it, and come back with a notification.",
            "Preferences")],
}[LANG]


def font(size, weight="Bold"):
    f = ImageFont.truetype("/System/Library/Fonts/SFNS.ttf", size)
    f.set_variation_by_name(weight)
    return f


def canvas(title, subtitle):
    im = Image.new("RGB", (W, H), BG)
    d = ImageDraw.Draw(im)
    for y in range(40, H, 48):          # dot grid, as on the design system canvas
        for x in range(40, W, 48):
            d.ellipse([x - 2, y - 2, x + 2, y + 2], fill=(222, 222, 226))
    d.text((200, 130), title, font=font(92), fill=INK)
    end = d.textlength(title, font=font(92))
    d.rectangle([200 + end + 14, 130 + 78, 200 + end + 14 + 22, 130 + 100], fill=ACCENT)
    d.text((200, 262), subtitle, font=font(44, "Regular"), fill=MUTED)
    return im


def window(path, title=None):
    """Rounded card with a soft shadow; with `title` it gets a window title bar."""
    raw = Image.open(path).convert("RGBA")
    src = Image.new("RGBA", raw.size, (246, 246, 246, 255))   # the render has no window background
    src.alpha_composite(raw)
    src = src.convert("RGB")
    src = src.resize((round(src.width * K), round(src.height * K)), Image.LANCZOS)
    bar = round(28 * 3 * K) if title else 0
    w, h, r = src.width, src.height + bar, round(10 * 3 * K)
    body = Image.new("RGB", (w, h), (246, 246, 246))
    body.paste(src, (0, bar))
    if title:
        d = ImageDraw.Draw(body)
        for i, c in enumerate([(255, 95, 87), (254, 188, 46), (40, 200, 64)]):
            cx = 30 + i * 48
            d.ellipse([cx, bar // 2 - 14, cx + 28, bar // 2 + 14], fill=c)
        f = font(31, "Semibold")
        d.text(((w - d.textlength(title, font=f)) / 2, bar / 2 - 20), title, font=f, fill=(70, 70, 74))
        d.line([0, bar - 1, w, bar - 1], fill=(222, 222, 224), width=2)
    mask = Image.new("L", (w, h), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, w - 1, h - 1], r, fill=255)
    pad = 120
    out = Image.new("RGBA", (w + 2 * pad, h + 2 * pad), (0, 0, 0, 0))
    shadow = Image.new("L", out.size, 0)
    ImageDraw.Draw(shadow).rounded_rectangle([pad, pad + 24, pad + w, pad + h + 24], r, fill=80)
    out.putalpha(shadow.filter(ImageFilter.GaussianBlur(36)))
    out.paste(body, (pad, pad), mask)
    ImageDraw.Draw(out).rounded_rectangle([pad, pad, pad + w - 1, pad + h - 1], r, outline=(0, 0, 0, 40), width=2)
    return out, pad


def place(im, items, top=440, gap=110):
    wins = [window(*it) for it in items]
    total = sum(w.width - 2 * p for w, p in wins) + gap * (len(wins) - 1)
    x = (W - total) // 2
    for win, pad in wins:
        im.paste(win, (x - pad, top - pad), win)
        x += win.width - 2 * pad + gap


one = canvas(*TEXT[0][:2])
place(one, [(f"{RAW}/list.png",), (f"{RAW}/editor.png", TEXT[0][2])])
one.save(f"{OUT}/{LANG}-mac-1-notes-2880x1800.png")
two = canvas(*TEXT[1][:2])
place(two, [(f"{RAW}/schedule.png",), (f"{RAW}/settings.png", TEXT[1][2])])
two.save(f"{OUT}/{LANG}-mac-2-schedule-2880x1800.png")
