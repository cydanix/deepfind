#!/bin/bash

set -euo pipefail

SRC=DeepFind.png
for SIZE in 16 32 64 128 256 512 1024; do
  sips -z $SIZE $SIZE "$SRC" --out icon_${SIZE}x${SIZE}.png
done

mkdir -p Icon.iconset
cp icon_16x16.png              Icon.iconset/icon_16x16.png
cp icon_32x32.png              Icon.iconset/icon_32x32.png
cp icon_64x64.png              Icon.iconset/icon_64x64.png
cp icon_128x128.png            Icon.iconset/icon_128x128.png
cp icon_256x256.png            Icon.iconset/icon_256x256.png
cp icon_512x512.png            Icon.iconset/icon_512x512.png
# and the @2x variants for Retina:
cp icon_32x32.png              Icon.iconset/icon_16x16@2x.png
cp icon_64x64.png              Icon.iconset/icon_32x32@2x.png
cp icon_256x256.png            Icon.iconset/icon_128x128@2x.png
cp icon_512x512.png            Icon.iconset/icon_256x256@2x.png
cp icon_1024x1024.png          Icon.iconset/icon_512x512@2x.png

iconutil -c icns Icon.iconset -o ../DeepFind.icns
