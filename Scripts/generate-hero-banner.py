#!/usr/bin/env python3

from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter
import random


ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "Resources" / "HeroBanner.png"
W, H = 1600, 760


def gradient(size, top, bottom):
    img = Image.new("RGBA", size)
    draw = ImageDraw.Draw(img)
    for y in range(size[1]):
        t = y / (size[1] - 1)
        color = tuple(int(top[i] * (1 - t) + bottom[i] * t) for i in range(3)) + (255,)
        draw.line((0, y, size[0], y), fill=color)
    return img


def add_stars(img):
    draw = ImageDraw.Draw(img)
    random.seed(42)
    for _ in range(90):
        x = random.randint(30, W - 30)
        y = random.randint(30, H // 2)
        r = random.randint(2, 5)
        a = random.randint(70, 180)
        draw.ellipse((x - r, y - r, x + r, y + r), fill=(235, 250, 255, a))


def add_glow(img, bbox, color, blur):
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    draw.ellipse(bbox, fill=color)
    layer = layer.filter(ImageFilter.GaussianBlur(blur))
    img.alpha_composite(layer)


def main():
    OUT.parent.mkdir(parents=True, exist_ok=True)
    base = gradient((W, H), (8, 16, 26), (15, 34, 50))

    top_haze = gradient((W, H), (30, 110, 135), (8, 16, 26))
    top_haze.putalpha(50)
    base.alpha_composite(top_haze)

    add_stars(base)
    add_glow(base, (930, 46, 1280, 396), (71, 214, 200, 78), 50)
    add_glow(base, (1030, 90, 1380, 440), (78, 113, 255, 52), 70)

    moon = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    md = ImageDraw.Draw(moon)
    md.ellipse((1180, 80, 1340, 240), fill=(246, 244, 224, 255))
    md.ellipse((1238, 58, 1382, 202), fill=(9, 18, 30, 255))
    moon = moon.filter(ImageFilter.GaussianBlur(0.4))
    base.alpha_composite(moon)

    landscape = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ld = ImageDraw.Draw(landscape)
    ld.polygon([(0, 620), (220, 460), (420, 540), (690, 390), (970, 550), (1240, 440), (1600, 620), (1600, 760), (0, 760)], fill=(11, 24, 34, 255))
    ld.polygon([(0, 660), (260, 530), (540, 610), (880, 470), (1170, 600), (1490, 520), (1600, 570), (1600, 760), (0, 760)], fill=(9, 19, 28, 255))
    base.alpha_composite(landscape)

    desk = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    dd = ImageDraw.Draw(desk)
    dd.rounded_rectangle((160, 370, 1030, 620), radius=36, fill=(15, 27, 38, 255))
    dd.rounded_rectangle((210, 320, 980, 560), radius=28, fill=(18, 35, 48, 255))
    dd.rounded_rectangle((250, 360, 940, 515), radius=18, fill=(20, 48, 60, 255))
    dd.rounded_rectangle((280, 388, 910, 486), radius=16, fill=(27, 87, 97, 255))
    dd.line((370, 570, 820, 570), fill=(38, 63, 74, 255), width=22)
    dd.rectangle((518, 570, 574, 660), fill=(28, 44, 52, 255))
    dd.rounded_rectangle((430, 654, 664, 690), radius=18, fill=(28, 44, 52, 255))
    base.alpha_composite(desk)

    screen_glow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    sg = ImageDraw.Draw(screen_glow)
    sg.rounded_rectangle((290, 396, 900, 478), radius=18, fill=(92, 242, 224, 65))
    screen_glow = screen_glow.filter(ImageFilter.GaussianBlur(18))
    base.alpha_composite(screen_glow)

    waveform = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    wd = ImageDraw.Draw(waveform)
    points = [
        (320, 448), (380, 420), (435, 462), (490, 408), (550, 462),
        (610, 392), (675, 460), (730, 426), (785, 452), (850, 404)
    ]
    wd.line(points, fill=(170, 255, 235, 255), width=10, joint="curve")
    for x, y in points[1:-1:2]:
        wd.ellipse((x - 8, y - 8, x + 8, y + 8), fill=(255, 210, 90, 255))
    base.alpha_composite(waveform)

    ring = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    rd = ImageDraw.Draw(ring)
    rd.arc((980, 190, 1400, 610), start=205, end=510, fill=(81, 231, 212, 255), width=22)
    rd.arc((1035, 245, 1345, 555), start=210, end=500, fill=(132, 255, 229, 210), width=10)
    base.alpha_composite(ring)
    add_glow(base, (995, 205, 1380, 590), (81, 231, 212, 70), 40)

    chip = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    cd = ImageDraw.Draw(chip)
    cd.rounded_rectangle((1030, 320, 1310, 392), radius=24, fill=(12, 30, 44, 220))
    cd.rounded_rectangle((1030, 412, 1450, 484), radius=24, fill=(12, 30, 44, 220))
    cd.rounded_rectangle((1030, 504, 1360, 576), radius=24, fill=(12, 30, 44, 220))
    base.alpha_composite(chip)

    veil = gradient((W, H), (0, 0, 0), (0, 0, 0))
    veil.putalpha(36)
    base.alpha_composite(veil)

    base.save(OUT)
    print(OUT)


if __name__ == "__main__":
    main()
