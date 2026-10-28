#!/usr/bin/env bash
# 构建前端：给静态资源的文件名加上内容哈希，输出到 frontend/dist/
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

# 在页面中写入版本号（提交 SHA 的前 7 位），方便确认线上运行的是哪个版本
sed -i "s|__VERSION__|${VERSION:0:7}|" "$OUT/index.html"

echo "Built frontend into $OUT:"
ls -1 "$OUT"
