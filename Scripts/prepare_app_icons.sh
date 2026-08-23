#!/usr/bin/env bash
#
# prepare_app_icons.sh
#
# Post-processes a generated 1024x1024 PNG app icon into the Asset Catalogs
# for BOTH the main happyFamily app and the HappyFamilyAppClips target.
#
# Usage:
#   ./scripts/prepare_app_icons.sh /path/to/generated-icon.png
#
# What it does:
#   1. Push any baked rounded corners / border off-canvas (full-bleed fix).
#   2. Enforce a true 1024x1024 square.
#   3. Guarantee NO alpha channel (App Store rejects transparent icons); if
#      alpha is present it is flattened onto the brand background.
#   4. Installs the icon into both AppIcon appiconsets.
#
# Requirements: macOS `sips` (built-in) and ImageMagick `magick` (for flatten).
set -euo pipefail

SRC="${1:?usage: $0 /path/to/generated-icon.png}"
BRAND_BG=${BRAND_BG:-"#FF7A59"} # warm coral — update to the exact brand background

MAIN_SET="Resources/Assets.xcassets/AppIcon.appiconset"
CLIP_SET="HappyFamilyAppClips/Assets.xcassets/AppIcon.appiconset"
INT_DST="/tmp/appicon-fullbleed.png"

[ -f "$SRC" ] || { echo "error: source icon not found: $SRC"; exit 1; }

# 1&2. Full-bleed fix + normalize to 1024x1024.
sips -z 1126 1126 "$SRC" --out /tmp/appicon-up.png >/dev/null
sips -c 1024 1024 /tmp/appicon-up.png --out "$INT_DST" >/dev/null

# 3. Guarantee no alpha.
if sips -g hasAlpha "$INT_DST" | grep -q "hasAlpha: yes"; then
  echo "→ source has alpha; flattening onto ${BRAND_BG}"
  magick "$INT_DST" -background "$BRAND_BG" -alpha remove -alpha off "$INT_DST"
fi
sips -s format png "$INT_DST" --out "$INT_DST" >/dev/null

# 4. Install into both asset catalogs.
cp "$INT_DST" "$MAIN_SET/AppIcon.png"
cp "$INT_DST" "$CLIP_SET/AppIcon.png"
echo "✔ installed AppIcon.png into:"
echo "   $MAIN_SET"
echo "   $CLIP_SET"
for f in "$MAIN_SET/AppIcon.png" "$CLIP_SET/AppIcon.png"; do
  sips -g pixelWidth -g pixelHeight -g hasAlpha "$f" | tr '\n' ' '; echo
done