#!/usr/bin/env python3
"""Generate and validate the Near Field identity assets.

The coordinates in this file are the single source of truth for SVG, Android,
preview, and generated Flutter geometry. No app runtime dependency is added.

Usage:
  python3 tool/generate_near_field_logo.py --target branding
  python3 tool/generate_near_field_logo.py --target android
  python3 tool/generate_near_field_logo.py --target flutter
  python3 tool/generate_near_field_logo.py --target all
  python3 tool/generate_near_field_logo.py --check
"""

from __future__ import annotations

import argparse
import math
import re
import xml.etree.ElementTree as ET
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable, Sequence

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
BRANDING = ROOT / "branding"
PREVIEWS = BRANDING / "previews"
RES = ROOT / "android" / "app" / "src" / "main" / "res"
FLUTTER_OUT = ROOT / "lib" / "widgets" / "near_field_mark.dart"

VIEWBOX = 108.0
SAFE_CENTER = (54.0, 54.0)
SAFE_RADIUS = 33.0

# The initial clock/NFC construction was optically left-heavy. Keep its original
# proportions but shift the complete mark so its actual dot bounds center at the
# 108-unit canvas center (rather than centering the clock hub alone).
SYMBOL_OFFSET_X = 3.95

# Wordmark uses a larger, more open dot grid than alarm numerals. It remains
# recognisably dotted while preserving individual letterforms at app scale.
WORDMARK_CELL = 6.0
WORDMARK_RADIUS_RATIO = 0.36
STACKED_WIDTH = 216.0
STACKED_HEIGHT = 236.0

COLORS = {
    "canvas": "#E4E8EB",
    "surface": "#F8F8F6",
    "ink": "#181B1A",
    "red": "#D71920",
    "red_bright": "#FF4A4F",
    "white": "#FFFFFF",
}
APPROVED_COLORS = {value.upper() for value in COLORS.values()}


@dataclass(frozen=True)
class Dot:
    x: float
    y: float
    r: float
    role: str = "ink"


# 5x7 glyphs copied from the app's DotMatrixText construction. Only the letters
# needed by NEAR FIELD are retained here, keeping the logo source deliberately
# small and auditable.
GLYPHS: dict[str, Sequence[str]] = {
    " ": ("000", "000", "000", "000", "000", "000", "000"),
    "A": ("01110", "10001", "10001", "11111", "10001", "10001", "10001"),
    "D": ("11110", "10001", "10001", "10001", "10001", "10001", "11110"),
    "E": ("11111", "10000", "10000", "11110", "10000", "10000", "11111"),
    "F": ("11111", "10000", "10000", "11110", "10000", "10000", "10000"),
    "I": ("11111", "00100", "00100", "00100", "00100", "00100", "11111"),
    "L": ("10000", "10000", "10000", "10000", "10000", "10000", "11111"),
    "N": ("10001", "11001", "10101", "10011", "10001", "10001", "10001"),
    "R": ("11110", "10001", "10001", "11110", "10100", "10010", "10001"),
}


def _polar(cx: float, cy: float, radius: float, angle_degrees: float) -> tuple[float, float]:
    angle = math.radians(angle_degrees)
    return cx + math.cos(angle) * radius, cy + math.sin(angle) * radius


def symbol_dots() -> list[Dot]:
    """Original clock + NFC construction, entirely inside adaptive safe zone."""
    dots: list[Dot] = []

    # Clock: 16-point implied ring with an open 112.5-degree sector at 3 o'clock.
    clock_center = (47.0, 54.0)
    for index in range(16):
        angle = -90.0 + index * 22.5
        if -45.0 <= angle <= 45.0:
            continue
        x, y = _polar(*clock_center, 23.5, angle)
        dots.append(Dot(x, y, 2.3, "ink"))

    # Dotted hour and minute hands. Slightly smaller dots retain separation at 16px.
    dots.extend(
        [
            Dot(47.0, 49.0, 1.75, "ink"),
            Dot(47.0, 44.0, 1.75, "ink"),
            Dot(47.0, 39.0, 1.75, "ink"),
            Dot(50.2, 50.8, 1.75, "ink"),
            Dot(53.4, 47.6, 1.75, "ink"),
            Dot(56.6, 44.4, 1.75, "ink"),
        ]
    )

    # NFC: three dotted arcs continue through the open clock sector.
    wave_center = (55.0, 54.0)
    for radius, angles in (
        (8.0, (-55.0, 0.0, 55.0)),
        (15.0, (-60.0, -30.0, 0.0, 30.0, 60.0)),
        (22.0, (-62.0, -41.333, -20.667, 0.0, 20.667, 41.333, 62.0)),
    ):
        for angle in angles:
            x, y = _polar(*wave_center, radius, angle)
            dots.append(Dot(x, y, 1.9, "ink"))

    # Red hub is last so it remains visually crisp if assets are rasterized.
    dots.append(Dot(*clock_center, 2.6, "accent"))

    # Center the complete visual bounds, not merely the clock hub. NFC arcs
    # extend the mark rightward, so this shift is necessary in launchers and
    # the in-app empty state alike.
    return [Dot(dot.x + SYMBOL_OFFSET_X, dot.y, dot.r, dot.role) for dot in dots]


def notification_dots() -> list[Dot]:
    """Reduced 24x24 status-bar construction; all dots are monochrome."""
    dots: list[Dot] = []
    center = (9.0, 12.0)
    for index in range(12):
        angle = -90.0 + index * 30.0
        if -30.0 <= angle <= 30.0:
            continue
        x, y = _polar(*center, 6.2, angle)
        dots.append(Dot(x, y, 0.9))
    dots.extend((Dot(9.0, 10.0, 0.75), Dot(9.0, 8.1, 0.75), Dot(10.7, 10.3, 0.75)))
    for radius, angles in ((3.2, (-45.0, 0.0, 45.0)), (5.4, (-50.0, -25.0, 0.0, 25.0, 50.0))):
        for angle in angles:
            x, y = _polar(12.3, 12.0, radius, angle)
            dots.append(Dot(x, y, 0.72))
    return dots


def glyph_dots(
    text: str,
    x: float,
    y: float,
    cell: float,
    radius_ratio: float = WORDMARK_RADIUS_RATIO,
) -> list[Dot]:
    dots: list[Dot] = []
    cursor = x
    for char in text.upper():
        glyph = GLYPHS[char]
        for row, bits in enumerate(glyph):
            for column, bit in enumerate(bits):
                if bit == "1":
                    dots.append(
                        Dot(
                            cursor + (column + 0.5) * cell,
                            y + (row + 0.5) * cell,
                            cell * radius_ratio,
                        )
                    )
        # One cell between glyphs; a three-column blank glyph gives the word gap.
        cursor += (len(glyph[0]) + 1) * cell
    return dots


def dot_bounds(dots: Sequence[Dot]) -> tuple[float, float, float, float]:
    """Bounds include radius so optical centering matches the rendered mark."""
    return (
        min(dot.x - dot.r for dot in dots),
        max(dot.x + dot.r for dot in dots),
        min(dot.y - dot.r for dot in dots),
        max(dot.y + dot.r for dot in dots),
    )


def translate_dots(dots: Iterable[Dot], x: float, y: float) -> list[Dot]:
    return [Dot(dot.x + x, dot.y + y, dot.r, dot.role) for dot in dots]


def centered_word_dots(text: str, center_x: float, top_y: float) -> list[Dot]:
    """Build one independently centered, readable 5×7 word row."""
    raw = glyph_dots(text, 0, 0, WORDMARK_CELL)
    left, right, _, _ = dot_bounds(raw)
    return translate_dots(raw, center_x - (left + right) / 2, top_y)


def stacked_wordmark_layout() -> tuple[list[Dot], list[Dot], list[Dot]]:
    """Absolute 216×236 layout: centered mark then distinct readable word rows."""
    symbol = translate_dots(symbol_dots(), (STACKED_WIDTH - VIEWBOX) / 2, 6.0)
    near = centered_word_dots("NEAR", STACKED_WIDTH / 2, 120.0)
    field = centered_word_dots("FIELD", STACKED_WIDTH / 2, 176.0)
    return symbol, near, field


def role_color(role: str, palette: str) -> str:
    if palette == "dark":
        return COLORS["red_bright"] if role == "accent" else COLORS["surface"]
    if palette == "mono":
        return COLORS["ink"]
    return COLORS["red"] if role == "accent" else COLORS["ink"]


def fmt(value: float) -> str:
    text = f"{value:.3f}".rstrip("0").rstrip(".")
    return text if text else "0"


def circles_svg(dots: Iterable[Dot], palette: str, transform: str | None = None) -> str:
    body = []
    if transform:
        body.append(f'  <g transform="{transform}">')
        indent = "    "
    else:
        indent = "  "
    for dot in dots:
        body.append(
            f'{indent}<circle cx="{fmt(dot.x)}" cy="{fmt(dot.y)}" '
            f'r="{fmt(dot.r)}" fill="{role_color(dot.role, palette)}"/>'
        )
    if transform:
        body.append("  </g>")
    return "\n".join(body)


def svg_document(width: float, height: float, body: str, title: str, background: str | None = None) -> str:
    background_element = ""
    if background:
        background_element = (
            f'  <rect width="{fmt(width)}" height="{fmt(height)}" '
            f'rx="24" fill="{background}"/>\n'
        )
    return (
        '<?xml version="1.0" encoding="UTF-8"?>\n'
        f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {fmt(width)} {fmt(height)}" '
        f'role="img" aria-labelledby="title">\n'
        f'  <title id="title">{title}</title>\n'
        f"{background_element}{body}\n"
        "</svg>\n"
    )


def write(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8")


def generate_symbol_svgs() -> None:
    dots = symbol_dots()
    write(
        BRANDING / "near_field_symbol.svg",
        svg_document(
            VIEWBOX,
            VIEWBOX,
            circles_svg(dots, "dark"),
            "Near Field dotted clock and NFC symbol",
            COLORS["ink"],
        ),
    )
    write(
        BRANDING / "near_field_symbol_light.svg",
        svg_document(
            VIEWBOX,
            VIEWBOX,
            circles_svg(dots, "light"),
            "Near Field dotted clock and NFC symbol, light surface variant",
        ),
    )
    write(
        BRANDING / "near_field_symbol_monochrome.svg",
        svg_document(
            VIEWBOX,
            VIEWBOX,
            circles_svg(dots, "mono"),
            "Near Field monochrome dotted clock and NFC symbol",
        ),
    )


def generate_wordmark_svgs() -> None:
    # Horizontal lockup: optical symbol centering plus a more open word grid.
    horizontal_symbol = translate_dots(symbol_dots(), 10.0, 10.0)
    horizontal_word = glyph_dots("NEAR FIELD", 125.0, 42.0, WORDMARK_CELL)
    horizontal_body = "\n".join(
        (
            circles_svg(horizontal_symbol, "light"),
            circles_svg(horizontal_word, "mono"),
        )
    )
    write(
        BRANDING / "near_field_wordmark_horizontal.svg",
        svg_document(
            500,
            128,
            horizontal_body,
            "Near Field horizontal dotted wordmark",
        ),
    )

    # Stacked lockup uses independently centered rows — never split a combined
    # string by an arbitrary x coordinate.
    symbol, near, field = stacked_wordmark_layout()
    stacked_body = "\n".join(
        (
            circles_svg(symbol, "light"),
            circles_svg(near, "mono"),
            circles_svg(field, "mono"),
        )
    )
    write(
        BRANDING / "near_field_wordmark_stacked.svg",
        svg_document(
            STACKED_WIDTH,
            STACKED_HEIGHT,
            stacked_body,
            "Near Field stacked dotted wordmark",
        ),
    )


def _hex(value: str) -> tuple[int, int, int, int]:
    value = value.lstrip("#")
    return int(value[0:2], 16), int(value[2:4], 16), int(value[4:6], 16), 255


def draw_symbol(
    image: Image.Image,
    box: tuple[float, float, float, float],
    palette: str,
    background: str | None = None,
    mask: str | None = None,
) -> None:
    draw = ImageDraw.Draw(image)
    left, top, right, bottom = box
    scale = min((right - left) / VIEWBOX, (bottom - top) / VIEWBOX)
    ox = left + ((right - left) - VIEWBOX * scale) / 2
    oy = top + ((bottom - top) - VIEWBOX * scale) / 2

    if background:
        fill = _hex(background)
        if mask == "circle":
            draw.ellipse(box, fill=fill)
        elif mask == "squircle":
            draw.rounded_rectangle(box, radius=(right - left) * 0.28, fill=fill)
        elif mask == "rounded":
            draw.rounded_rectangle(box, radius=(right - left) * 0.18, fill=fill)
        elif mask == "teardrop":
            # Approximation used only for a mask-loss preview.
            draw.rounded_rectangle(box, radius=(right - left) * 0.25, fill=fill)
            draw.polygon(
                [(right, top), (right, top + (bottom - top) * 0.47), (left + (right - left) * 0.53, top)],
                fill=fill,
            )
        else:
            draw.rounded_rectangle(box, radius=(right - left) * 0.22, fill=fill)

    for dot in symbol_dots():
        color = _hex(role_color(dot.role, palette))
        cx = ox + dot.x * scale
        cy = oy + dot.y * scale
        radius = dot.r * scale
        draw.ellipse((cx - radius, cy - radius, cx + radius, cy + radius), fill=color)


def draw_dots(
    image: Image.Image,
    dots: Iterable[Dot],
    scale: float,
    offset: tuple[float, float],
    palette: str = "mono",
) -> None:
    draw = ImageDraw.Draw(image)
    for dot in dots:
        cx = offset[0] + dot.x * scale
        cy = offset[1] + dot.y * scale
        radius = dot.r * scale
        draw.ellipse(
            (cx - radius, cy - radius, cx + radius, cy + radius),
            fill=_hex(role_color(dot.role, palette)),
        )


def generate_previews() -> None:
    PREVIEWS.mkdir(parents=True, exist_ok=True)
    font = ImageFont.load_default()

    sizes = (16, 24, 32, 48, 96, 192)
    sheet = Image.new("RGBA", (760, 270), _hex(COLORS["canvas"]))
    draw = ImageDraw.Draw(sheet)
    x = 24
    for size in sizes:
        y = 35 + (192 - size) / 2
        draw_symbol(sheet, (x, y, x + size, y + size), "dark", COLORS["ink"], "rounded")
        draw.text((x, 238), f"{size}px", font=font, fill=_hex(COLORS["ink"]))
        x += size + 30
    sheet.save(PREVIEWS / "icon_sizes.png")

    masks = ("circle", "squircle", "rounded", "teardrop")
    masks_sheet = Image.new("RGBA", (760, 220), _hex(COLORS["canvas"]))
    draw = ImageDraw.Draw(masks_sheet)
    for index, mask in enumerate(masks):
        x = 25 + index * 185
        draw_symbol(
            masks_sheet,
            (x, 24, x + 150, 174),
            "dark",
            COLORS["ink"],
            mask,
        )
        draw.text((x + 45, 190), mask, font=font, fill=_hex(COLORS["ink"]))
    masks_sheet.save(PREVIEWS / "adaptive_masks.png")

    identity = Image.new("RGBA", (1200, 720), _hex(COLORS["canvas"]))
    draw = ImageDraw.Draw(identity)
    draw.rounded_rectangle((40, 40, 350, 350), radius=48, fill=_hex(COLORS["ink"]))
    draw_symbol(identity, (90, 90, 300, 300), "dark")
    draw_symbol(identity, (410, 90, 620, 300), "light")
    draw_symbol(identity, (730, 90, 940, 300), "mono")

    # Horizontal lockup preview.
    horizontal_symbol = translate_dots(symbol_dots(), 10.0, 10.0)
    horizontal = glyph_dots("NEAR FIELD", 125.0, 42.0, WORDMARK_CELL)
    draw_dots(identity, horizontal_symbol, 1.1, (42, 438), "light")
    draw_dots(identity, horizontal, 1.45, (220, 458), "mono")

    # Stacked lockup preview uses the exact absolute layout used by the SVG and
    # Flutter painter: centered rows, larger dots, and generous row spacing.
    stacked_symbol, near, field = stacked_wordmark_layout()
    draw_dots(identity, stacked_symbol, 0.72, (906, 405), "light")
    draw_dots(identity, near, 0.72, (906, 405), "mono")
    draw_dots(identity, field, 0.72, (906, 405), "mono")
    identity.save(PREVIEWS / "identity_sheet.png")

    # Notification mark at mdpi and xxxhdpi-equivalent scales on dark chips.
    notification_sheet = Image.new("RGBA", (360, 180), _hex(COLORS["canvas"]))
    draw = ImageDraw.Draw(notification_sheet)
    for index, size in enumerate((24, 96)):
        x = 35 + index * 160
        y = (180 - size) / 2
        draw.rounded_rectangle(
            (x - 12, y - 12, x + size + 12, y + size + 12),
            radius=12,
            fill=_hex(COLORS["ink"]),
        )
        scale = size / 24
        draw_dots(
            notification_sheet,
            notification_dots(),
            scale,
            (x, y),
            "light",
        )
        draw.text(
            (x, y + size + 16),
            "24dp" if size == 24 else "24dp @4x",
            font=font,
            fill=_hex(COLORS["ink"]),
        )
    notification_sheet.save(PREVIEWS / "notification_sizes.png")


def vector_path(dots: Iterable[Dot], role: str | None = None) -> str:
    """Android VectorDrawable pathData containing one closed arc-circle per dot."""
    commands: list[str] = []
    for dot in dots:
        if role is not None and dot.role != role:
            continue
        # Two 180-degree arcs form a circle; relative moves keep data compact.
        commands.append(
            f"M {fmt(dot.x - dot.r)},{fmt(dot.y)} "
            f"a {fmt(dot.r)},{fmt(dot.r)} 0 1,0 {fmt(dot.r * 2)},0 "
            f"a {fmt(dot.r)},{fmt(dot.r)} 0 1,0 -{fmt(dot.r * 2)},0 z"
        )
    return " ".join(commands)


def vector_xml(
    width_dp: int,
    height_dp: int,
    viewport_width: float,
    viewport_height: float,
    paths: Sequence[tuple[str, str]],
) -> str:
    path_xml = "\n".join(
        f'    <path android:fillColor="{color}" android:pathData="{path}" />'
        for color, path in paths
    )
    return (
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<vector xmlns:android="http://schemas.android.com/apk/res/android"\n'
        f'    android:width="{width_dp}dp"\n'
        f'    android:height="{height_dp}dp"\n'
        f'    android:viewportWidth="{fmt(viewport_width)}"\n'
        f'    android:viewportHeight="{fmt(viewport_height)}">\n'
        f"{path_xml}\n"
        "</vector>\n"
    )


def generate_android_vectors() -> None:
    dots = symbol_dots()
    ink_dots = [dot for dot in dots if dot.role == "ink"]
    accent = [dot for dot in dots if dot.role == "accent"]

    write(
        RES / "drawable" / "ic_launcher_foreground.xml",
        vector_xml(
            108,
            108,
            108,
            108,
            (
                (COLORS["surface"], vector_path(ink_dots)),
                (COLORS["red_bright"], vector_path(accent)),
            ),
        ),
    )
    write(
        RES / "drawable" / "ic_launcher_monochrome.xml",
        vector_xml(108, 108, 108, 108, (("#FFFFFFFF", vector_path(dots)),)),
    )
    write(
        RES / "drawable" / "splash_icon.xml",
        vector_xml(
            108,
            108,
            108,
            108,
            (
                (COLORS["ink"], vector_path(ink_dots)),
                (COLORS["red"], vector_path(accent)),
            ),
        ),
    )

    notification = notification_dots()
    write(
        RES / "drawable" / "ic_stat_near_field.xml",
        vector_xml(24, 24, 24, 24, (("#FFFFFFFF", vector_path(notification)),)),
    )


def generate_legacy_pngs() -> None:
    # Android launcher icon pixel sizes by density.
    legacy_sizes = {
        "mdpi": 48,
        "hdpi": 72,
        "xhdpi": 96,
        "xxhdpi": 144,
        "xxxhdpi": 192,
    }
    foreground_sizes = {
        "mdpi": 108,
        "hdpi": 162,
        "xhdpi": 216,
        "xxhdpi": 324,
        "xxxhdpi": 432,
    }
    splash_sizes = {
        "mdpi": 96,
        "hdpi": 144,
        "xhdpi": 192,
        "xxhdpi": 288,
        "xxxhdpi": 384,
    }

    for density, size in legacy_sizes.items():
        directory = RES / f"mipmap-{density}"
        directory.mkdir(parents=True, exist_ok=True)
        for name, mask in (("ic_launcher.png", "rounded"), ("ic_launcher_round.png", "circle")):
            image = Image.new("RGBA", (size, size), (0, 0, 0, 0))
            draw_symbol(image, (0, 0, size, size), "dark", COLORS["ink"], mask)
            image.save(directory / name)

    # Keep density-specific adaptive foreground PNGs for older resource tooling,
    # even though API 26+ XML now points at the vector source.
    for density, size in foreground_sizes.items():
        directory = RES / f"mipmap-{density}"
        image = Image.new("RGBA", (size, size), (0, 0, 0, 0))
        draw_symbol(image, (0, 0, size, size), "dark")
        image.save(directory / "ic_launcher_foreground.png")

    # Pre-Android-12 layer-list uses this transparent symbol on gray.
    for density, size in splash_sizes.items():
        directory = RES / f"drawable-{density}"
        directory.mkdir(parents=True, exist_ok=True)
        image = Image.new("RGBA", (size, size), (0, 0, 0, 0))
        draw_symbol(image, (0, 0, size, size), "light")
        image.save(directory / "splash_icon.png")


def _generate_flutter_widget_legacy() -> None:
    dots = symbol_dots()
    dot_lines = "\n".join(
        f"  _BrandDot({fmt(dot.x)}, {fmt(dot.y)}, {fmt(dot.r)}, "
        f"accent: {'true' if dot.role == 'accent' else 'false'}),"
        for dot in dots
    )
    near_word = centered_word_dots("NEAR", STACKED_WIDTH / 2, 120.0)
    field_word = centered_word_dots("FIELD", STACKED_WIDTH / 2, 176.0)
    stacked_symbol, _, _ = stacked_wordmark_layout()
    stacked_symbol_lines = "\n".join(
        f"  _BrandDot({fmt(dot.x)}, {fmt(dot.y)}, {fmt(dot.r)}, "
        f"accent: {'true' if dot.role == 'accent' else 'false'}),"
        for dot in stacked_symbol
    )
    near_word_lines = "\n".join(
        f"  _BrandDot({fmt(dot.x)}, {fmt(dot.y)}, {fmt(dot.r)}),"
        for dot in near_word
    )
    field_word_lines = "\n".join(
        f"  _BrandDot({fmt(dot.x)}, {fmt(dot.y)}, {fmt(dot.r)}),"
        for dot in field_word
    )
    source = f'''// GENERATED by tool/generate_near_field_logo.py. Do not edit by hand.\nimport 'package:flutter/material.dart';\n\nimport '../theme/nothing_colors.dart';\n\n/// Original Near Field dotted clock + NFC brand mark.\n///\n/// Geometry is shared with the SVG and Android assets through the generator.\nclass NearFieldMark extends StatelessWidget {{\n  const NearFieldMark({{\n    super.key,\n    this.size = 108,\n    this.onDark = false,\n    this.monochrome = false,\n    this.semanticLabel = 'Near Field',\n  }});\n\n  final double size;\n  final bool onDark;\n  final bool monochrome;\n  final String semanticLabel;\n\n  @override\n  Widget build(BuildContext context) {{\n    return Semantics(\n      image: true,\n      label: semanticLabel,\n      child: ExcludeSemantics(\n        child: SizedBox.square(\n          dimension: size,\n          child: CustomPaint(\n            painter: _NearFieldMarkPainter(\n              onDark: onDark,\n              monochrome: monochrome,\n            ),\n          ),\n        ),\n      ),\n    );\n  }}\n}}\n\n/// Stacked symbol + NEAR / FIELD dotted wordmark for sparse brand surfaces.\nclass NearFieldStackedWordmark extends StatelessWidget {{\n  const NearFieldStackedWordmark({{\n    super.key,\n    this.width = 160,\n    this.onDark = false,\n  }});\n\n  final double width;\n  final bool onDark;\n\n  @override\n  Widget build(BuildContext context) {{\n    return Semantics(\n      image: true,\n      label: 'Near Field',\n      child: ExcludeSemantics(\n        child: SizedBox(\n          width: width,\n          height: width * ({STACKED_HEIGHT} / {STACKED_WIDTH}),\n          child: CustomPaint(painter: _NearFieldWordmarkPainter(onDark: onDark)),\n        ),\n      ),\n    );\n  }}\n}}\n\nclass _NearFieldMarkPainter extends CustomPainter {{\n  const _NearFieldMarkPainter({{required this.onDark, required this.monochrome}});\n  final bool onDark;\n  final bool monochrome;\n\n  @override\n  void paint(Canvas canvas, Size size) {{\n    final scale = size.shortestSide / 108;\n    final paint = Paint()..isAntiAlias = true;\n    for (final dot in _symbolDots) {{\n      paint.color = monochrome\n          ? (onDark ? NothingColors.surface : NothingColors.ink)\n          : dot.accent\n              ? (onDark ? NothingColors.redBright : NothingColors.red)\n              : (onDark ? NothingColors.surface : NothingColors.ink);\n      canvas.drawCircle(Offset(dot.x * scale, dot.y * scale), dot.radius * scale, paint);\n    }}\n  }}\n\n  @override\n  bool shouldRepaint(covariant _NearFieldMarkPainter old) =>\n      onDark != old.onDark || monochrome != old.monochrome;\n}}\n\nclass _NearFieldWordmarkPainter extends CustomPainter {{\n  const _NearFieldWordmarkPainter({{required this.onDark}});\n  final bool onDark;\n\n  @override\n  void paint(Canvas canvas, Size size) {{\n    final scale = size.width / 160;\n    final paint = Paint()\n      ..isAntiAlias = true\n      ..color = onDark ? NothingColors.surface : NothingColors.ink;\n\n    canvas.save();\n    canvas.translate(26 * scale, 0);\n    canvas.scale(scale * 0.98);\n    for (final dot in _symbolDots) {{\n      paint.color = dot.accent\n          ? (onDark ? NothingColors.redBright : NothingColors.red)\n          : (onDark ? NothingColors.surface : NothingColors.ink);\n      canvas.drawCircle(Offset(dot.x, dot.y), dot.radius, paint);\n    }}\n    canvas.restore();\n\n    paint.color = onDark ? NothingColors.surface : NothingColors.ink;\n    // Generated word coordinates represent "NEAR FIELD". Split at x=120 and\n    // stack the two words to retain the compact identity lockup.\n    for (final dot in _wordDots) {{\n      final bool field = dot.x >= 125;\n      final sourceX = field ? dot.x - 125 : dot.x;\n      final xOffset = field ? 16.5 : 31.5;\n      final yOffset = field ? 137.0 : 108.0;\n      canvas.drawCircle(\n        Offset((xOffset + sourceX * 0.86) * scale, (yOffset + dot.y * 0.86) * scale),\n        dot.radius * 0.86 * scale,\n        paint,\n      );\n    }}\n  }}\n\n  @override\n  bool shouldRepaint(covariant _NearFieldWordmarkPainter old) => onDark != old.onDark;\n}}\n\nclass _BrandDot {{\n  const _BrandDot(this.x, this.y, this.radius, {{this.accent = false}});\n  final double x;\n  final double y;\n  final double radius;\n  final bool accent;\n}}\n\nconst _symbolDots = <_BrandDot>[\n{dot_lines}\n];\n\nconst _wordDots = <_BrandDot>[\n{word_lines}\n];\n'''
    write(FLUTTER_OUT, source)


def write_spec() -> None:
    write(
        BRANDING / "near_field_logo_spec.md",
        f"""# Near Field Logo Specification

## Concept

An original dotted alarm clock opens at three o'clock and continues into three
near-field communication waves. Dotted hour/minute hands meet at one red hub.
The construction references the application's dot-matrix language without
reproducing a Nothing trademark.

## Master geometry

- View box: `0 0 108 108`
- Adaptive safe area: circle centered at `(54, 54)`, radius `33`
- Clock visual bounds: centered at `(54, 54)` after a +`3.95` x correction for NFC-wave mass
- Clock hub: `(50.95, 54)`
- Clock perimeter radius: `23.5`
- NFC origin: `(58.95, 54)`
- NFC radii: `8`, `15`, `22`
- Hub radius: `2.6`
- Perimeter dot radius: `2.3`
- Wordmark: 5×7 cells at `6` units, with a `36%` dot radius and independently centered stacked rows

## Palette

| Role | Value |
|---|---|
| Canvas | `{COLORS['canvas']}` |
| Surface / dark dots | `{COLORS['surface']}` |
| Ink | `{COLORS['ink']}` |
| Red on light | `{COLORS['red']}` |
| Bright red on ink | `{COLORS['red_bright']}` |

## Clear space and sizing

- Minimum clear space: one hub diameter (`5.2` master units) around the symbol.
- Minimum digital size: `24px` for the full-color symbol.
- Below `24px`, use the simplified notification mark or monochrome symbol.
- Do not add strokes, shadows, gradients, or replace circles with rounded squares.
- Do not recolor individual non-hub dots.

## Variants

- `near_field_symbol.svg`: ink tile, off-white dots, bright-red hub.
- `near_field_symbol_light.svg`: transparent, ink dots, standard-red hub.
- `near_field_symbol_monochrome.svg`: transparent, one-color mark.
- Horizontal wordmark: symbol followed by `NEAR FIELD` on one baseline.
- Stacked wordmark: symbol above `NEAR` / `FIELD`.

## Regeneration

All generated brand, Android, and Flutter assets derive from:

```sh
python3 tool/generate_near_field_logo.py --target all
python3 tool/generate_near_field_logo.py --check
```

Do not edit generated geometry by hand.
""",
    )


def validate_svg(path: Path, expected_viewbox: str) -> list[str]:
    errors: list[str] = []
    try:
        root = ET.parse(path).getroot()
    except (ET.ParseError, OSError) as error:
        return [f"{path}: cannot parse: {error}"]
    if root.attrib.get("viewBox") != expected_viewbox:
        errors.append(f"{path}: expected viewBox {expected_viewbox}, got {root.attrib.get('viewBox')}")
    forbidden = {"text", "image", "use", "foreignObject", "style"}
    for element in root.iter():
        name = element.tag.rsplit("}", 1)[-1]
        if name in forbidden:
            errors.append(f"{path}: forbidden <{name}> element")
        for key, value in element.attrib.items():
            if "font" in key.lower() or "font" in value.lower():
                errors.append(f"{path}: font dependency in {key}")
            for color in re.findall(r"#[0-9A-Fa-f]{6}", value):
                if color.upper() not in APPROVED_COLORS:
                    errors.append(f"{path}: unapproved color {color}")
    return errors


def validate_geometry() -> list[str]:
    errors: list[str] = []
    dots = symbol_dots()
    for index, dot in enumerate(dots):
        distance = math.hypot(dot.x - SAFE_CENTER[0], dot.y - SAFE_CENTER[1]) + dot.r
        if distance > SAFE_RADIUS + 0.01:
            errors.append(f"symbol dot {index} exceeds safe zone: {distance:.3f} > {SAFE_RADIUS}")
    left, right, top, bottom = dot_bounds(dots)
    if abs((left + right) / 2 - SAFE_CENTER[0]) > 0.01:
        errors.append(
            f"symbol bounds are not centered: {(left + right) / 2:.3f} != {SAFE_CENTER[0]}"
        )
    if abs((top + bottom) / 2 - SAFE_CENTER[1]) > 0.01:
        errors.append(
            f"symbol bounds are not vertically centered: {(top + bottom) / 2:.3f} != {SAFE_CENTER[1]}"
        )
    # Different-size dots may intentionally sit close, but must never overlap.
    for i, first in enumerate(dots):
        for j, second in enumerate(dots[i + 1 :], i + 1):
            distance = math.hypot(first.x - second.x, first.y - second.y)
            if distance + 0.001 < first.r + second.r:
                errors.append(f"symbol dots {i}/{j} overlap by {first.r + second.r - distance:.3f}")
    symbol, near, field = stacked_wordmark_layout()
    near_left, near_right, near_top, near_bottom = dot_bounds(near)
    field_left, field_right, field_top, field_bottom = dot_bounds(field)
    if abs((near_left + near_right) / 2 - STACKED_WIDTH / 2) > 0.01:
        errors.append("NEAR row is not centered in stacked wordmark")
    if abs((field_left + field_right) / 2 - STACKED_WIDTH / 2) > 0.01:
        errors.append("FIELD row is not centered in stacked wordmark")
    if field_top - near_bottom < 12.0:
        errors.append("stacked wordmark rows are too close to read independently")
    if field_bottom > STACKED_HEIGHT:
        errors.append("stacked wordmark extends beyond its view box")
    return errors


def validate_android() -> list[str]:
    """Structural checks on generated Android resources."""
    errors: list[str] = []

    vectors = {
        RES / "drawable" / "ic_launcher_foreground.xml": 108,
        RES / "drawable" / "ic_launcher_monochrome.xml": 108,
        RES / "drawable" / "splash_icon.xml": 108,
        RES / "drawable" / "ic_stat_near_field.xml": 24,
    }
    android_ns = "{http://schemas.android.com/apk/res/android}"
    for path, viewport in vectors.items():
        if not path.exists():
            errors.append(f"missing vector: {path}")
            continue
        try:
            root = ET.parse(path).getroot()
        except (ET.ParseError, OSError) as error:
            errors.append(f"{path}: cannot parse: {error}")
            continue
        if root.tag.rsplit("}", 1)[-1] != "vector":
            errors.append(f"{path}: root is not <vector>")
        if root.attrib.get(f"{android_ns}viewportWidth") != fmt(float(viewport)):
            errors.append(f"{path}: unexpected viewportWidth")
        paths = [element for element in root.iter() if element.tag.rsplit("}", 1)[-1] == "path"]
        if not paths:
            errors.append(f"{path}: no <path> data")
        # The notification icon must be a single-color alpha mask: white only,
        # no red hub, so Android tinting cannot invert meaning.
        if path.name == "ic_stat_near_field.xml":
            for element in paths:
                color = element.attrib.get(f"{android_ns}fillColor", "").upper()
                if color not in {"#FFFFFFFF", "#FFFFFF"}:
                    errors.append(f"{path}: notification fill must be white, got {color}")

    # API 33 adaptive icons must carry the themed monochrome layer.
    for name in ("ic_launcher.xml", "ic_launcher_round.xml"):
        path = RES / "mipmap-anydpi-v33" / name
        if not path.exists():
            errors.append(f"missing themed adaptive icon: {path}")
            continue
        text = path.read_text(encoding="utf-8")
        if "<monochrome" not in text:
            errors.append(f"{path}: missing <monochrome> layer")

    # Legacy launcher raster set at every density, exact pixel sizes.
    legacy_sizes = {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}
    for density, size in legacy_sizes.items():
        for name in ("ic_launcher.png", "ic_launcher_round.png"):
            path = RES / f"mipmap-{density}" / name
            if not path.exists():
                errors.append(f"missing launcher raster: {path}")
                continue
            with Image.open(path) as image:
                if image.size != (size, size):
                    errors.append(f"{path}: expected {size}px, got {image.size[0]}px")

    # Splash: pre-Android-12 layer-list plus Android 12+ system splash attrs.
    for path in (
        RES / "drawable" / "launch_background.xml",
        RES / "drawable-v21" / "launch_background.xml",
    ):
        if not path.exists() or "@drawable/splash_icon" not in path.read_text(encoding="utf-8"):
            errors.append(f"{path}: splash icon not referenced")
    v31 = RES / "values-v31" / "styles.xml"
    if not v31.exists() or "windowSplashScreenAnimatedIcon" not in v31.read_text(encoding="utf-8"):
        errors.append(f"{v31}: missing Android 12+ splash icon attribute")

    return errors


def validate_outputs() -> None:
    required = {
        BRANDING / "near_field_symbol.svg": "0 0 108 108",
        BRANDING / "near_field_symbol_light.svg": "0 0 108 108",
        BRANDING / "near_field_symbol_monochrome.svg": "0 0 108 108",
        BRANDING / "near_field_wordmark_horizontal.svg": "0 0 500 128",
        BRANDING / "near_field_wordmark_stacked.svg": "0 0 216 236",
    }
    errors = validate_geometry()
    for path, viewbox in required.items():
        errors.extend(validate_svg(path, viewbox))
    for path in (
        PREVIEWS / "icon_sizes.png",
        PREVIEWS / "adaptive_masks.png",
        PREVIEWS / "identity_sheet.png",
        PREVIEWS / "notification_sizes.png",
    ):
        if not path.exists() or path.stat().st_size == 0:
            errors.append(f"missing preview: {path}")
    errors.extend(validate_android())
    if errors:
        raise SystemExit("Logo validation failed:\n- " + "\n- ".join(errors))
    print(
        f"Logo validation passed: {len(symbol_dots())} symbol dots, "
        f"{len(notification_dots())} notification dots, safe radius {SAFE_RADIUS}"
    )


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--target", choices=("branding", "android", "flutter", "all"))
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    if not args.target and not args.check:
        parser.error("choose --target or --check")

    if args.target in ("branding", "all"):
        generate_symbol_svgs()
        generate_wordmark_svgs()
        generate_previews()
        write_spec()
    if args.target in ("android", "all"):
        generate_android_vectors()
        generate_legacy_pngs()
    if args.target in ("flutter", "all"):
        generate_flutter_widget()
    if args.check:
        validate_outputs()


# The real entry point follows the v2 Flutter renderer definition below.



# v2 Flutter renderer. It deliberately uses separate absolute layout groups for
# the stacked lockup instead of slicing a combined string by x-coordinate.
def generate_flutter_widget() -> None:
    dots = symbol_dots()
    symbol_lines = "\n".join(
        f"  _BrandDot({fmt(dot.x)}, {fmt(dot.y)}, {fmt(dot.r)}, "
        f"accent: {'true' if dot.role == 'accent' else 'false'}),"
        for dot in dots
    )
    stacked_symbol, near_word, field_word = stacked_wordmark_layout()
    stacked_symbol_lines = "\n".join(
        f"  _BrandDot({fmt(dot.x)}, {fmt(dot.y)}, {fmt(dot.r)}, "
        f"accent: {'true' if dot.role == 'accent' else 'false'}),"
        for dot in stacked_symbol
    )
    near_word_lines = "\n".join(
        f"  _BrandDot({fmt(dot.x)}, {fmt(dot.y)}, {fmt(dot.r)}),"
        for dot in near_word
    )
    field_word_lines = "\n".join(
        f"  _BrandDot({fmt(dot.x)}, {fmt(dot.y)}, {fmt(dot.r)}),"
        for dot in field_word
    )

    source = f'''// GENERATED by tool/generate_near_field_logo.py. Do not edit by hand.
import 'package:flutter/material.dart';

import '../theme/nothing_colors.dart';

/// Original Near Field dotted clock + NFC brand mark.
///
/// Its 108-unit geometry is generated from the same coordinate source as the
/// SVG and Android assets, including the optical centering correction.
class NearFieldMark extends StatelessWidget {{
  const NearFieldMark({{
    super.key,
    this.size = 108,
    this.onDark = false,
    this.monochrome = false,
    this.semanticLabel = 'Near Field',
  }});

  final double size;
  final bool onDark;
  final bool monochrome;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {{
    return Semantics(
      image: true,
      label: semanticLabel,
      child: ExcludeSemantics(
        child: SizedBox.square(
          dimension: size,
          child: CustomPaint(
            painter: _NearFieldMarkPainter(
              onDark: onDark,
              monochrome: monochrome,
            ),
          ),
        ),
      ),
    );
  }}
}}

/// A readable two-row dotted Near Field wordmark for sparse brand surfaces.
/// The words are separate centered rows, not a split combined-dot string.
class NearFieldStackedWordmark extends StatelessWidget {{
  const NearFieldStackedWordmark({{
    super.key,
    this.width = 184,
    this.onDark = false,
  }});

  final double width;
  final bool onDark;

  @override
  Widget build(BuildContext context) {{
    return Semantics(
      image: true,
      label: 'Near Field',
      child: ExcludeSemantics(
        child: SizedBox(
          width: width,
          height: width * ({STACKED_HEIGHT} / {STACKED_WIDTH}),
          child: CustomPaint(painter: _NearFieldWordmarkPainter(onDark: onDark)),
        ),
      ),
    );
  }}
}}

class _NearFieldMarkPainter extends CustomPainter {{
  const _NearFieldMarkPainter({{required this.onDark, required this.monochrome}});

  final bool onDark;
  final bool monochrome;

  @override
  void paint(Canvas canvas, Size size) {{
    final scale = size.shortestSide / {VIEWBOX};
    final paint = Paint()..isAntiAlias = true;
    for (final dot in _symbolDots) {{
      paint.color = monochrome
          ? (onDark ? NothingColors.surface : NothingColors.ink)
          : dot.accent
              ? (onDark ? NothingColors.redBright : NothingColors.red)
              : (onDark ? NothingColors.surface : NothingColors.ink);
      canvas.drawCircle(
        Offset(dot.x * scale, dot.y * scale),
        dot.radius * scale,
        paint,
      );
    }}
  }}

  @override
  bool shouldRepaint(covariant _NearFieldMarkPainter old) =>
      onDark != old.onDark || monochrome != old.monochrome;
}}

class _NearFieldWordmarkPainter extends CustomPainter {{
  const _NearFieldWordmarkPainter({{required this.onDark}});

  final bool onDark;

  @override
  void paint(Canvas canvas, Size size) {{
    final scale = size.width / {STACKED_WIDTH};
    final paint = Paint()..isAntiAlias = true;

    for (final dot in _stackedSymbolDots) {{
      paint.color = dot.accent
          ? (onDark ? NothingColors.redBright : NothingColors.red)
          : (onDark ? NothingColors.surface : NothingColors.ink);
      canvas.drawCircle(
        Offset(dot.x * scale, dot.y * scale),
        dot.radius * scale,
        paint,
      );
    }}

    paint.color = onDark ? NothingColors.surface : NothingColors.ink;
    for (final dot in _nearWordDots) {{
      canvas.drawCircle(
        Offset(dot.x * scale, dot.y * scale),
        dot.radius * scale,
        paint,
      );
    }}
    for (final dot in _fieldWordDots) {{
      canvas.drawCircle(
        Offset(dot.x * scale, dot.y * scale),
        dot.radius * scale,
        paint,
      );
    }}
  }}

  @override
  bool shouldRepaint(covariant _NearFieldWordmarkPainter old) =>
      onDark != old.onDark;
}}

class _BrandDot {{
  const _BrandDot(this.x, this.y, this.radius, {{this.accent = false}});

  final double x;
  final double y;
  final double radius;
  final bool accent;
}}

const _symbolDots = <_BrandDot>[
{symbol_lines}
];

const _stackedSymbolDots = <_BrandDot>[
{stacked_symbol_lines}
];

const _nearWordDots = <_BrandDot>[
{near_word_lines}
];

const _fieldWordDots = <_BrandDot>[
{field_word_lines}
];
'''
    write(FLUTTER_OUT, source)


if __name__ == "__main__":
    main()
