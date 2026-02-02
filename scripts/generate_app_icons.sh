#!/bin/bash
set -euo pipefail

# Usage: ./generate_app_icons.sh [source_png]
# Example: ./generate_app_icons.sh Flag_of_Haiti.svg.png

SRC="${1:-Flag_of_Haiti.svg.png}"
ICONSET_DIR="Assets.xcassets/AppIcon.appiconset"

if [ ! -f "$SRC" ]; then
  echo "Source file not found: $SRC"
  echo "Place your source PNG in the CreoleTranslator-iOS folder and re-run, or provide an absolute path."
  exit 1
fi

TIMESTAMP=$(date +%Y%m%d-%H%M%S)
BACKUP_DIR="$ICONSET_DIR.backup-$TIMESTAMP"
mkdir -p "$BACKUP_DIR"
cp -a "$ICONSET_DIR/"* "$BACKUP_DIR/" || true

echo "Backed up existing AppIcon.appiconset files to $BACKUP_DIR"

# Resize using macOS sips. If SRC is an SVG (rasterized PNG name), sips will rasterize it.
# Filenames must match those in Contents.json in the asset catalog.

sips -z 20 20 "$SRC" --out "$ICONSET_DIR/Icon-App-20x20@1x.png"
sips -z 40 40 "$SRC" --out "$ICONSET_DIR/Icon-App-20x20@2x.png"
sips -z 60 60 "$SRC" --out "$ICONSET_DIR/Icon-App-20x20@3x.png"

sips -z 29 29 "$SRC" --out "$ICONSET_DIR/Icon-App-29x29@1x.png"
sips -z 58 58 "$SRC" --out "$ICONSET_DIR/Icon-App-29x29@2x.png"
sips -z 87 87 "$SRC" --out "$ICONSET_DIR/Icon-App-29x29@3x.png"

sips -z 40 40 "$SRC" --out "$ICONSET_DIR/Icon-App-40x40@1x.png"
sips -z 80 80 "$SRC" --out "$ICONSET_DIR/Icon-App-40x40@2x.png"
sips -z 120 120 "$SRC" --out "$ICONSET_DIR/Icon-App-40x40@3x.png"

sips -z 120 120 "$SRC" --out "$ICONSET_DIR/Icon-App-60x60@2x.png"
sips -z 180 180 "$SRC" --out "$ICONSET_DIR/Icon-App-60x60@3x.png"

sips -z 76 76 "$SRC" --out "$ICONSET_DIR/Icon-App-76x76@1x.png"
sips -z 152 152 "$SRC" --out "$ICONSET_DIR/Icon-App-76x76@2x.png"

sips -z 167 167 "$SRC" --out "$ICONSET_DIR/Icon-App-83.5x83.5@2x.png"

sips -z 1024 1024 "$SRC" --out "$ICONSET_DIR/Icon-App-1024x1024@1x.png"

# Final listing
echo "Generated icons in $ICONSET_DIR:"
ls -1 "$ICONSET_DIR" | sed -n '1,200p'

echo "\nValidation: Contents.json must reference these filenames. If Xcode shows missing images, open the asset and inspect filenames."

echo "Done."