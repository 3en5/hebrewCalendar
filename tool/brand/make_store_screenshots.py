#!/usr/bin/env python3
"""Frames the raw app screens into KALFAPP-style Play Store screenshots.

Input: build/store_raw/*.png, captured from the real app widgets by
  flutter test tool/screenshots/capture_store_screens_test.dart
Output: distribution/listings/images/phoneScreenshots/NN.png (1080x1920),
uploaded by tool/upload_play_listing.py.

Each image: a light KALFAPP background (dark for the dark-mode screen), the
KALFAPP logo, a headline and one line of explanation in Rubik, and the screen
in a rounded phone frame that runs off the bottom edge.
Run from the repo root: python3 tool/brand/make_store_screenshots.py
"""

import os
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
RAW = os.path.join(ROOT, "build/store_raw")
OUT = os.path.join(ROOT, "distribution/listings/images/phoneScreenshots")
LOGO = os.path.join(ROOT, "assets/brand/kalfapp_logo.png")
BOLD = os.path.join(ROOT, "assets/fonts/Rubik-Bold.ttf")
REGULAR = os.path.join(ROOT, "assets/fonts/Rubik-Regular.ttf")

W, H = 1080, 1920
GRAD_FROM = (15, 143, 224)
GRAD_TO = (24, 185, 201)

# (raw screen, headline, explanation, dark background)
SHOTS = [
    ("1_month", "התאריך העברי במרכז",
     "חגים, פרשת השבוע וכל האירועים שלך במבט אחד", False),
    ("9_halacha", "הלכה יומית",
     "בכל יום הלכה מקיצור שולחן ערוך, מסיימים בשנה", False),
    ("3_editor", "חוזר לפי התאריך העברי",
     "ימי הולדת ואזכרות במקום הנכון בכל שנה, גם בשנה מעוברת", False),
    ("10_significant", "תאריך משמעותי",
     "מתאריך לועזי לאירוע שנתי עברי, כולל לפני או אחרי השקיעה", False),
    ("11_day", "זמני היום ושבת",
     "זריחה, סוף זמן קריאת שמע, שקיעה והדלקת נרות לפי העיר", False),
    ("2_week", "כל הפגישות של השבוע",
     "תצוגת שבוע ויום, עם צבע לכל אירוע", False),
    ("12_settings_more", "הכל מותאם לך",
     "גודל טקסט, עיר ומנהג והלכה יומית", False),
    ("6_month_dark", "נוח לעיניים גם בלילה",
     "מצב כהה בלחיצה אחת בהגדרות", True),
]


def vertical_gradient(top, bottom):
    im = Image.new("RGB", (W, H), top)
    d = ImageDraw.Draw(im)
    for y in range(H):
        t = y / (H - 1)
        d.line([(0, y), (W, y)], fill=tuple(int(top[i] * (1 - t) + bottom[i] * t) for i in range(3)))
    return im


def gradient_text(canvas, xy, text, font):
    """Centered RTL text filled with the KALFAPP blue-to-cyan gradient."""
    mask = Image.new("L", canvas.size, 0)
    ImageDraw.Draw(mask).text(xy, text, font=font, fill=255, anchor="mm", direction="rtl")
    box = mask.getbbox()
    fill = Image.new("RGB", canvas.size)
    fd = ImageDraw.Draw(fill)
    for x in range(box[0], box[2]):
        t = (x - box[0]) / max(1, box[2] - box[0] - 1)
        fd.line([(x, 0), (x, H)], fill=tuple(int(GRAD_FROM[i] * (1 - t) + GRAD_TO[i] * t) for i in range(3)))
    canvas.paste(fill, (0, 0), mask)


def fit_font(path, text, size, max_width):
    while size > 20:
        f = ImageFont.truetype(path, size)
        if f.getlength(text, direction="rtl") <= max_width:
            return f
        size -= 2
    return ImageFont.truetype(path, size)


def phone(screen, width):
    """[screen] in a rounded dark bezel, scaled to [width]."""
    bezel = 22
    inner_w = width - 2 * bezel
    inner_h = int(screen.height * inner_w / screen.width)
    shot = screen.convert("RGB").resize((inner_w, inner_h), Image.LANCZOS)
    radius = 70
    frame = Image.new("RGBA", (width, inner_h + 2 * bezel), (0, 0, 0, 0))
    d = ImageDraw.Draw(frame)
    d.rounded_rectangle([0, 0, frame.width - 1, frame.height - 1], radius=radius, fill=(28, 32, 40))
    mask = Image.new("L", shot.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, inner_w - 1, inner_h - 1], radius=radius - bezel, fill=255)
    frame.paste(shot, (bezel, bezel), mask)
    return frame


def compose(raw, headline, line, dark):
    if dark:
        bg = vertical_gradient((16, 24, 40), (10, 40, 70))
        ink, muted = (240, 246, 252), (170, 190, 210)
    else:
        bg = vertical_gradient((255, 255, 255), (222, 239, 252))
        ink, muted = (40, 52, 68), (96, 110, 128)
    canvas = bg.convert("RGBA")
    logo = Image.open(LOGO).convert("RGBA")
    logo = logo.resize((250, int(250 * logo.height / logo.width)), Image.LANCZOS)
    canvas.paste(logo, ((W - logo.width) // 2, 56), logo)
    head_font = fit_font(BOLD, headline, 84, W - 120)
    if dark:
        ImageDraw.Draw(canvas).text((W / 2, 250), headline, font=head_font, fill=ink,
                                    anchor="mm", direction="rtl")
    else:
        gradient_text(canvas, (W / 2, 250), headline, head_font)
    ImageDraw.Draw(canvas).text((W / 2, 340), line, font=fit_font(REGULAR, line, 42, W - 120),
                                fill=muted, anchor="mm", direction="rtl")
    device = phone(Image.open(os.path.join(RAW, raw + ".png")), 780)
    x, y = (W - device.width) // 2, 420
    shadow = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle([x + 10, y + 24, x + device.width - 10, y + device.height],
                                             radius=70, fill=(10, 40, 80, 90))
    canvas = Image.alpha_composite(canvas, shadow.filter(ImageFilter.GaussianBlur(28)))
    canvas.paste(device, (x, y), device)
    return canvas.convert("RGB")


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    for old in os.listdir(OUT):
        os.remove(os.path.join(OUT, old))
    for i, (raw, headline, line, dark) in enumerate(SHOTS, start=1):
        compose(raw, headline, line, dark).save(os.path.join(OUT, f"{i:02d}.png"), optimize=True)
    print(f"{len(SHOTS)} store screenshots written")
