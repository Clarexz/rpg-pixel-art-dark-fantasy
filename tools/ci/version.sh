#!/usr/bin/env bash
# Lee la versión de project.godot (application/config/version, ej. "0.3.1")
# y la escribe en export_presets.cfg (version/name y version/code).
#
# Uso:
#   tools/ci/version.sh                 -> release oficial   (0.3.1,            code 30199)
#   tools/ci/version.sh <area> <N>      -> build de prueba   (0.3.1-enemigos.4, code 30104)
#
# version/code = (MAJOR*10000 + MINOR*100 + PATCH) * 100 + N
#   N = número del build de prueba (1..98); el release oficial usa 99.
# Así un build de prueba de 0.3.1 se instala encima de 0.3.0, y el release
# oficial 0.3.1 se instala encima de todos los builds de prueba de 0.3.1.
# Android exige que version/code siempre suba para instalar una actualización.
set -euo pipefail
cd "$(dirname "$0")/../.."

AREAS="mecanicas mundo lore enemigos sprites ui-ux"
AREA="${1:-}"
N="${2:-}"

VERSION=$(sed -n 's/^config\/version="\(.*\)"$/\1/p' project.godot)
if ! [[ "$VERSION" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
  echo "config/version en project.godot debe ser X.Y.Z (es '$VERSION')" >&2
  exit 1
fi
BASE=$(( BASH_REMATCH[1] * 10000 + BASH_REMATCH[2] * 100 + BASH_REMATCH[3] ))

if [ -z "$AREA" ]; then
  NAME="$VERSION"
  CODE=$(( BASE * 100 + 99 ))
else
  if ! [[ " $AREAS " == *" $AREA "* ]]; then
    echo "Área '$AREA' no válida. Usa una de: $AREAS" >&2
    exit 1
  fi
  if ! [[ "$N" =~ ^[0-9]+$ ]] || [ "$N" -lt 1 ] || [ "$N" -gt 98 ]; then
    echo "El número del build de prueba debe ir de 1 a 98 (es '$N'). Sube la versión en project.godot." >&2
    exit 1
  fi
  NAME="$VERSION-$AREA.$N"
  CODE=$(( BASE * 100 + N ))
fi

sed -i "s/^version\/name=.*/version\/name=\"$NAME\"/; s/^version\/code=.*/version\/code=$CODE/" export_presets.cfg
echo "base=$VERSION"
echo "version=$NAME"
echo "code=$CODE"
