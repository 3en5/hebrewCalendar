"""Drawing and timing for the user guide's short videos.

A video is a title card and then scenes. Each scene is one real app
screen (from capture_guide_videos_test.dart) with effects on the marks the
capture recorded: an orange frame that pulses, a yellow marker swept over
text (right to left, as Hebrew is read), a speech bubble pointing at a mark,
and a finger that presses the "tap" mark before the next screen comes in,
swipes across the "swipe" mark, or is held down on a mark.
make_guide_videos.py says what each video shows; this file draws it.
"""

import math
import os
import subprocess

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
FONTS = os.path.join(ROOT, "assets/fonts")

W, H = 720, 1600          # the video, 2/3 of the 1080x2400 captures
SCALE = W / 1080
FPS = 30
FADE = 0.35               # seconds of crossfade between screens

ORANGE = (232, 131, 58)   # the app's add button, AppTheme.addButtonColor
INK = (33, 33, 33)
MARKER = (255, 224, 102)  # the next-event marker's yellow
WHITE = (255, 255, 255)


def font(weight, size):
    return ImageFont.truetype(os.path.join(FONTS, f"Rubik-{weight}.ttf"), size)


def ease(x):
    """Smooth 0..1 (ease in and out)."""
    x = max(0.0, min(1.0, x))
    return x * x * (3 - 2 * x)


def pop(x):
    """0..1 with a small overshoot, for things that appear."""
    x = max(0.0, min(1.0, x))
    return 1 + 2.2 * (x - 1) ** 3 + 1.2 * (x - 1) ** 2 if x < 1 else 1.0


def box_of(marks, name, pad=10):
    l, t, r, b = (v * SCALE for v in marks[name])
    return [l - pad, t - pad, r + pad, b + pad]


# ---- effects, each drawn on an RGBA overlay at time t into its scene ----

def dim(overlay, boxes, alpha):
    """Darkens the screen outside [boxes] a little."""
    if alpha <= 0:
        return
    shade = Image.new("L", (W, H), int(alpha))
    hole = ImageDraw.Draw(shade)
    for b in boxes:
        hole.rounded_rectangle(b, radius=18, fill=0)
    overlay.alpha_composite(Image.merge("RGBA", (
        Image.new("L", (W, H), 0),) * 3 + (shade,)))


def frame(draw, box, t):
    """An orange frame that closes in on [box], then breathes."""
    k = ease(t / 0.35)
    if k <= 0:
        return
    grow = (1 - k) * 36
    l, top, r, b = box
    width = 5 + (1.5 * (1 + math.sin(t * 5)) if k >= 1 else 0)
    draw.rounded_rectangle(
        [l - grow, top - grow, r + grow, b + grow], radius=18,
        outline=ORANGE + (int(255 * k),), width=int(round(width)))


def marker(overlay, box, t):
    """A highlighter stroke swept right to left over [box]."""
    k = ease(t / 0.6)
    if k <= 0:
        return
    l, top, r, b = box
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(layer).rounded_rectangle(
        [r - (r - l) * k, top + 4, r, b - 4], radius=10, fill=MARKER + (120,))
    overlay.alpha_composite(layer)


def wrap(text, fnt, width):
    lines, line = [], ""
    for word in text.split():
        trial = f"{line} {word}".strip()
        if line and fnt.getlength(trial, direction="rtl") > width:
            lines.append(line)
            line = word
        else:
            line = trial
    return lines + [line] if line else lines


def bubble(overlay, text, target, where, t):
    """A white speech bubble with [text]; its tail points at [target]
    (a box) when given. [where] "top"/"bottom" when there is no target,
    else "auto" puts it on the roomier side of the target."""
    if t <= 0:
        return
    k = min(1.0, pop(t / 0.35))
    fnt = font("Medium", 34)
    lines = wrap(text, fnt, W - 150)
    line_h = 50
    bw = max(fnt.getlength(s, direction="rtl") for s in lines) + 60
    bh = line_h * len(lines) + 36
    if target is not None:
        cx = (target[0] + target[2]) / 2
        above = (target[1] + target[3]) / 2 > H * 0.45 if where == "auto" \
            else where == "top"
        y = target[1] - bh - 46 if above else target[3] + 46
    else:
        cx = W / 2
        above = False
        y = 150 if where == "top" else H - bh - 190
    x = min(max(cx - bw / 2, 24), W - 24 - bw)
    y = min(max(y, 24), H - 24 - bh)
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    rect = [x, y, x + bw, y + bh]
    shadow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle(
        [x + 4, y + 8, x + bw + 4, y + bh + 8], radius=26, fill=(0, 0, 0, 90))
    layer.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(10)))
    if target is not None:
        tx = min(max(cx, x + 40), x + bw - 40)
        tip_y = target[1] - 8 if above else target[3] + 8
        base_y = y + bh - 2 if above else y + 2
        d.polygon([(tx - 22, base_y), (tx + 22, base_y), (tx, tip_y)],
                  fill=WHITE, outline=ORANGE)
    d.rounded_rectangle(rect, radius=26, fill=WHITE, outline=ORANGE, width=4)
    if target is not None:  # cover the tail's seam with the bubble
        d.rectangle([tx - 19, base_y - 4, tx + 19, base_y + 2], fill=WHITE)
    for i, s in enumerate(lines):
        d.text((x + bw / 2, y + 18 + line_h * i + line_h / 2), s, font=fnt,
               fill=INK, anchor="mm", direction="rtl")
    # Pop in from the side of the tail.
    sw, sh = max(1, int(W * k)), max(1, int(H * k))
    ox = cx - cx * k
    oy = (rect[3] if above else rect[1]) * (1 - k)
    scaled = layer.resize((sw, sh))
    if t < 0.2:
        scaled.putalpha(scaled.getchannel("A").point(lambda a: a * t / 0.2))
    overlay.alpha_composite(scaled, (int(ox), int(oy)))


def finger(overlay, box, t, press_at):
    """A fingertip that comes to the middle of [box] and presses it."""
    cx, cy = (box[0] + box[2]) / 2, (box[1] + box[3]) / 2
    appear = ease((t - (press_at - 0.5)) / 0.3)
    if appear <= 0:
        return
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    since = t - press_at
    if since >= 0:  # the press ripple
        ring = 40 + since * 260
        fade = max(0.0, 1 - since / 0.45)
        d.ellipse([cx - ring, cy - ring, cx + ring, cy + ring],
                  outline=ORANGE + (int(220 * fade),), width=6)
    r = 38 * (0.82 if 0 <= since < 0.18 else 1.0)
    dy = (1 - appear) * 120
    d.ellipse([cx - r, cy - r + dy, cx + r, cy + r + dy],
              fill=(255, 255, 255, int(150 * appear)),
              outline=(60, 60, 60, int(200 * appear)), width=4)
    overlay.alpha_composite(layer)


def swipe(overlay, box, t, start, rightward):
    """A fingertip that slides across [box] from [start], with a trail."""
    k = ease((t - start) / 0.7)
    if t < start - 0.3 or t > start + 1.1:
        return
    appear = ease((t - start + 0.3) / 0.3) * (1 - ease((t - start - 0.8) / 0.3))
    cy = (box[1] + box[3]) / 2
    a, b = box[0] + 90, box[2] - 90
    if not rightward:
        a, b = b, a
    cx = a + (b - a) * k
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    if k > 0:
        d.line([(a, cy), (cx, cy)], fill=ORANGE + (int(150 * appear),),
               width=14)
    d.ellipse([cx - 38, cy - 38, cx + 38, cy + 38],
              fill=(255, 255, 255, int(150 * appear)),
              outline=(60, 60, 60, int(200 * appear)), width=4)
    overlay.alpha_composite(layer)


def press(overlay, box, t):
    """A fingertip held down on [box] for the whole scene."""
    cx, cy = (box[0] + box[2]) / 2, (box[1] + box[3]) / 2
    pulse = 46 + 10 * (1 + math.sin(t * 6))
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    d.ellipse([cx - pulse, cy - pulse, cx + pulse, cy + pulse],
              outline=ORANGE + (170,), width=5)
    d.ellipse([cx - 32, cy - 32, cx + 32, cy + 32],
              fill=(255, 255, 255, 140), outline=(60, 60, 60, 200), width=4)
    overlay.alpha_composite(layer)


# ---- the video ----

def load(raw, name):
    return Image.open(os.path.join(raw, name + ".png")).convert("RGBA").resize(
        (W, H), Image.LANCZOS)


def title_card(base, title, t, dur):
    """The first screen blurred, with the topic's name."""
    img = base.filter(ImageFilter.GaussianBlur(14))
    veil = Image.new("RGBA", (W, H), (20, 30, 60, 150))
    img = Image.alpha_composite(img, veil)
    d = ImageDraw.Draw(img)
    k = pop(t / 0.5)
    big = font("Bold", 56)
    lines = wrap(title, big, W - 100)
    top = H / 2 - 40 - 36 * (len(lines) - 1)
    for i, line in enumerate(lines):
        d.text((W / 2, top + 72 * i + (1 - k) * 40), line, font=big,
               fill=WHITE + (int(255 * min(1, k)),), anchor="mm",
               direction="rtl")
    d.text((W / 2, top + 72 * len(lines) + 20), "לוח עברי · מדריך",
           font=font("Regular", 32),
           fill=MARKER, anchor="mm", direction="rtl")
    if t > dur - FADE:  # into the first scene
        return Image.blend(img, base, ease((t - dur + FADE) / FADE))
    return img


def scene_frame(img, scene, marks, t):
    out = img.copy()
    overlay = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    m = marks.get(scene["img"], {})
    fx = scene.get("fx", [])
    start = 0.45
    boxes = [box_of(m, name) for kind, name in fx if kind == "frame"]
    if boxes:
        dim(overlay, boxes, 70 * ease((t - start) / 0.4))
    draw = ImageDraw.Draw(overlay)
    for kind, name in fx:
        if kind == "frame":
            frame(draw, box_of(m, name), t - start)
        elif kind == "marker":
            marker(overlay, box_of(m, name, pad=4), t - start - 0.2)
    if "bubble" in scene:
        text, target, where = scene["bubble"]
        bubble(overlay, text, box_of(m, target) if target else None, where,
               t - start - 0.15)
    if "swipe" in scene:
        swipe(overlay, box_of(m, "swipe", pad=0), t, scene["dur"] - 1.2,
              scene["swipe"] == "right")
    if "press" in scene:
        press(overlay, box_of(m, scene["press"], pad=0), t)
    if scene.get("tap"):
        finger(overlay, box_of(m, "tap", pad=0), t, scene["dur"] - 0.45)
    return Image.alpha_composite(out, overlay)


def render(video, raw, marks, out_mp4, poster=None):
    """Writes [video] ({"title", "scenes"}) to [out_mp4] with ffmpeg."""
    scenes = video["scenes"]
    images = {s["img"]: load(raw, s["img"]) for s in scenes}
    enc = subprocess.Popen(
        ["ffmpeg", "-y", "-loglevel", "error", "-f", "rawvideo",
         "-pix_fmt", "rgb24", "-s", f"{W}x{H}", "-r", str(FPS), "-i", "-",
         "-c:v", "libx264", "-preset", "slow", "-crf", "27",
         "-pix_fmt", "yuv420p", "-movflags", "+faststart", out_mp4],
        stdin=subprocess.PIPE)

    def emit(img):
        enc.stdin.write(img.convert("RGB").tobytes())

    first = images[scenes[0]["img"]]
    intro = 1.8
    for i in range(int(intro * FPS)):
        card = title_card(first, video["title"], i / FPS, intro)
        if poster and i == int(0.9 * FPS):
            card.convert("RGB").save(poster, quality=85)
        emit(card)
    prev = None
    for s in scenes:
        img = images[s["img"]]
        for i in range(int(s["dur"] * FPS)):
            t = i / FPS
            f = scene_frame(img, s, marks, t)
            if prev is not None and t < FADE:
                f = Image.blend(prev, f, ease(t / FADE))
            emit(f)
        prev = scene_frame(img, s, marks, s["dur"])
    for _ in range(int(1.0 * FPS)):  # hold the end
        emit(prev)
    enc.stdin.close()
    if enc.wait() != 0:
        raise RuntimeError(f"ffmpeg failed for {out_mp4}")
