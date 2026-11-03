#!/usr/bin/env bash
# Build the frontend: add content hashes to asset file names, output to frontend/dist/
set -euo pipefail

SRC=frontend
OUT=frontend/dist
VERSION="${GITHUB_SHA:-local}"

rm -rf "$OUT"
mkdir -p "$OUT"
cp "$SRC/index.html" "$OUT/index.html"

for file in app.js style.css; do
  hash=$(sha256sum "$SRC/$file" | cut -c1-8)
  name="${file%.*}.${hash}.${file##*.}"   # app.js → app.3f8a1c2d.js
  cp "$SRC/$file" "$OUT/$name"
  sed -i "s|\"$file\"|\"$name\"|" "$OUT/index.html"
done

# Stamp the version (first 7 chars of the commit SHA) so we can tell what is live
sed -i "s|__VERSION__|${VERSION:0:7}|" "$OUT/index.html"

echo "Built frontend into $OUT:"
ls -1 "$OUT"
