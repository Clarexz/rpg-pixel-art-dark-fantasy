#!/usr/bin/env bash
# Lee la versión de project.godot (application/config/version, ej. "0.3.1")
# y la escribe en export_presets.cfg (version/name y version/code).
# version/code = MAJOR*10000 + MINOR*100 + PATCH  ->  0.3.1 = 301
# Android exige que version/code siempre suba para instalar una actualización.
set -euo pipefail
cd "$(dirname "$0")/../.."

VERSION=$(sed -n 's/^config\/version="\(.*\)"$/\1/p' project.godot)
if ! [[ "$VERSION" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
  echo "config/version en project.godot debe ser X.Y.Z (es '$VERSION')" >&2
  exit 1
fi
CODE=$(( BASH_REMATCH[1] * 10000 + BASH_REMATCH[2] * 100 + BASH_REMATCH[3] ))

sed -i "s/^version\/name=.*/version\/name=\"$VERSION\"/; s/^version\/code=.*/version\/code=$CODE/" export_presets.cfg
echo "version=$VERSION"
echo "code=$CODE"
