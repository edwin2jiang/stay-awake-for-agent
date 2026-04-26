#!/usr/bin/env python3

from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter


ROOT = Path(__file__).resolve().parent.parent
OUTPUT_DIR = ROOT / "Resources"
OUTPUT_PATH = OUTPUT_DIR / "AppIcon-1024.png"

SIZE = 1024


def vertical_gradient(size: int, top: tuple[int, int, int], bottom: tuple[int, int, int]) -> Image.Image:
    gradient = Image.new("RGBA", (size, size))
    draw = ImageDraw.Draw(gradient)
    for y in range(size):
        t = y / (size - 1)
        color = tuple(int(top[i] * (1 - t) + bottom[i] * t) for i in range(3)) + (255,)
        draw.line((0, y, size, y), fill=color)
    return gradient


def add_glow(base: Image.Image, bbox: tuple[int, int, int, int], color: tuple[int, int, int, int], blur: int) -> None:
    glow = Image.new("RGBA", base.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(glow)
    draw.ellipse(bbox, fill=color)
    glow = glow.filter(ImageFilter.GaussianBlur(blur))
    base.alpha_composite(glow)


def draw_icon() -> Image.Image:
    canvas = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    background = vertical_gradient(SIZE, (17, 21, 29), (10, 13, 18))

    panel_mask = Image.new("L", (SIZE, SIZE), 0)
    ImageDraw.Draw(panel_mask).rounded_rectangle((36, 36, SIZE - 36, SIZE - 36), radius=224, fill=255)
    rounded_background = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    rounded_background.paste(background, (0, 0), panel_mask)
    canvas.alpha_composite(rounded_background)

    highlight = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    highlight_draw = ImageDraw.Draw(highlight)
    highlight_draw.rounded_rectangle(
        (52, 52, SIZE - 52, SIZE - 52),
        radius=208,
        outline=(255, 255, 255, 18),
        width=3,
    )
    canvas.alpha_composite(highlight)

    add_glow(canvas, (208, 248, 816, 856), (34, 211, 187, 88), 96)
    add_glow(canvas, (260, 300, 764, 804), (84, 255, 197, 72), 64)

    ring = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    ring_draw = ImageDraw.Draw(ring)
    ring_draw.arc((202, 242, 822, 862), start=200, end=520, fill=(95, 255, 214, 255), width=54)
    ring_draw.arc((244, 284, 780, 820), start=210, end=510, fill=(12, 30, 34, 190), width=24)
    ring = ring.filter(ImageFilter.GaussianBlur(0.6))
    canvas.alpha_composite(ring)

    pulse = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    pulse_draw = ImageDraw.Draw(pulse)
    pulse_draw.arc((278, 318, 746, 786), start=235, end=485, fill=(158, 255, 226, 255), width=18)
    pulse_draw.arc((300, 340, 724, 764), start=248, end=472, fill=(86, 160, 145, 180), width=10)
    pulse = pulse.filter(ImageFilter.GaussianBlur(0.4))
    canvas.alpha_composite(pulse)

    core = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    core_draw = ImageDraw.Draw(core)
    core_draw.rounded_rectangle((396, 402, 628, 634), radius=64, fill=(18, 31, 34, 255))
    core_draw.rounded_rectangle((416, 422, 608, 614), radius=54, fill=(21, 52, 54, 255))
    core_draw.polygon(
        ((512, 452), (580, 520), (512, 588), (444, 520)),
        fill=(210, 255, 240, 255),
    )
    core_draw.polygon(
        ((512, 472), (560, 520), (512, 568), (464, 520)),
        fill=(71, 214, 182, 255),
    )
    canvas.alpha_composite(core)

    spark = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    spark_draw = ImageDraw.Draw(spark)
    spark_draw.polygon(
        ((516, 610), (462, 710), (520, 710), (494, 812), (592, 676), (536, 676)),
        fill=(255, 208, 96, 255),
    )
    spark = spark.filter(ImageFilter.GaussianBlur(0.3))
    canvas.alpha_composite(spark)
    add_glow(canvas, (396, 594, 640, 864), (255, 194, 82, 78), 42)

    moon = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    moon_draw = ImageDraw.Draw(moon)
    moon_draw.ellipse((684, 164, 832, 312), fill=(248, 250, 236, 255))
    moon_draw.ellipse((736, 144, 864, 272), fill=(15, 20, 28, 255))
    moon_draw.ellipse((724, 186, 754, 216), fill=(248, 250, 236, 90))
    moon_draw.ellipse((764, 220, 780, 236), fill=(248, 250, 236, 70))
    moon = moon.filter(ImageFilter.GaussianBlur(0.2))
    canvas.alpha_composite(moon)

    detail = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    detail_draw = ImageDraw.Draw(detail)
    detail_draw.arc((118, 118, 904, 904), start=122, end=154, fill=(255, 255, 255, 36), width=8)
    detail_draw.arc((130, 146, 894, 910), start=18, end=54, fill=(255, 255, 255, 28), width=7)
    detail_draw.line((314, 750, 404, 692), fill=(95, 255, 214, 120), width=10)
    detail_draw.line((620, 350, 714, 288), fill=(95, 255, 214, 120), width=10)
    canvas.alpha_composite(detail)

    return canvas


def main() -> None:
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    image = draw_icon()
    image.save(OUTPUT_PATH)
    print(OUTPUT_PATH)


if __name__ == "__main__":
    main()
