# Near Field Logo Specification

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
| Canvas | `#E4E8EB` |
| Surface / dark dots | `#F8F8F6` |
| Ink | `#181B1A` |
| Red on light | `#D71920` |
| Bright red on ink | `#FF4A4F` |

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
