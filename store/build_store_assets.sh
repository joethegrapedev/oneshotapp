#!/usr/bin/env bash
# Generates the Google Play store assets from the One Shot brand mark:
#   - icon-512.png          512x512 high-res listing icon (required)
#   - feature-1024x500.png  1024x500 feature graphic (required)
#   - mark.png              transparent brand mark (used to build the graphic)
#
# The mark (terracotta arch + dot on paper) mirrors the Android adaptive
# launcher icon. Drawn with ImageMagick native path ops rather than SVG
# rendering, because IM's built-in SVG renderer drops stroked `fill:none`
# paths (no rsvg delegate). The .svg sources are kept as the design reference.
#
# Requires ImageMagick 7 (`magick`). Fonts are macOS system paths; adjust
# FONT_SERIF / FONT_SANS on other platforms. Run from anywhere:
#   bash store/build_store_assets.sh
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR"

PAPER="#FBF7F0"
INK="#1E1B18"
INK_SOFT="#6B655E"
ACCENT="#C05C3A"
FONT_SERIF="/System/Library/Fonts/Supplemental/Georgia Bold.ttf"
FONT_SANS="/System/Library/Fonts/Helvetica.ttc"

# The mark, drawn at 512x512: an upward arch (single round-capped stroke) with a
# dot above. Shared by the icon and the transparent compositing mark.
draw_mark() { # $1 = background (color or "none")
  magick -size 512x512 canvas:"$1" \
    -stroke "$ACCENT" -strokewidth 30 -fill none \
    -draw "stroke-linecap round stroke-linejoin round path 'M150,322 C196,232 316,232 362,322'" \
    -stroke none -fill "$ACCENT" \
    -draw "circle 256,196 256,222" \
    "$2"
}

# 1. High-res listing icon (512x512): full-bleed paper + mark.
draw_mark "$PAPER" icon-512.png

# 2. Transparent mark, sized for the feature graphic.
draw_mark none mark-full.png
magick mark-full.png -resize 300x300 mark.png
rm -f mark-full.png

# 3. Feature graphic (1024x500): paper, terracotta top rule, mark left,
#    serif wordmark + short tagline.
magick -size 1024x500 canvas:"$PAPER" \
  -fill "$ACCENT" -draw "rectangle 0,0 1024,8" \
  mark.png -geometry +96+100 -composite \
  -font "$FONT_SERIF" -fill "$INK" -pointsize 96 \
  -annotate +430+250 "One Shot" \
  -font "$FONT_SANS" -fill "$INK_SOFT" -pointsize 30 \
  -annotate +434+300 "Share one entry. Read a stranger's." \
  feature-1024x500.png

echo "wrote: icon-512.png, mark.png, feature-1024x500.png"
identify -format "  %f  %wx%h  %m\n" icon-512.png feature-1024x500.png
