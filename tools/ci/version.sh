#!/usr/bin/env bash
# Lee la versión de project.godot (application/config/version, ej. "0.3.1")
# y la escribe en export_presets.cfg (version/name y version/code).
#
# Uso:
#   tools/ci/version.sh                    -> release oficial  (0.3.0,            code 30999)
#   tools/ci/version.sh <area> <N> <S>     -> build de prueba  (0.3.0-enemigos.2, code 30000+S)
#
# N = número del build de prueba DENTRO de su área (enemigos.1, .2, .3...).
# S = número del build de prueba contando TODAS las áreas de esa versión (1..998).
# version/code = (MAJOR*10000 + MINOR*100 + PATCH) * 1000 + S   (oficial: S = 999)
# Así cada build de prueba se instala encima del anterior (de cualquier área), y el
# release oficial 0.3.0 se instala encima de todos los builds de prueba de 0.3.0.
# Android exige que version/code siempre suba para instalar una actualización.
set -euo pipefail
cd "$(dirname "$0")/../.."

AREAS="mecanicas mundo lore enemigos sprites ui-ux"
AREA="${1:-}"
N="${2:-}"
S="${3:-}"

VERSION=$(sed -n 's/^config\/version="\(.*\)"$/\1/p' project.godot)
if ! [[ "$VERSION" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
  echo "config/version en project.godot debe ser X.Y.Z (es '$VERSION')" >&2
  exit 1
fi
BASE=$(( BASH_REMATCH[1] * 10000 + BASH_REMATCH[2] * 100 + BASH_REMATCH[3] ))

if [ -z "$AREA" ]; then
  NAME="$VERSION"
  CODE=$(( BASE * 1000 + 999 ))
else
  if ! [[ " $AREAS " == *" $AREA "* ]]; then
    echo "Área '$AREA' no válida. Usa una de: $AREAS" >&2
    exit 1
  fi
  if ! [[ "$N" =~ ^[0-9]+$ ]] || [ "$N" -lt 1 ]; then
    echo "El número del build de prueba debe ser 1 o más (es '$N')." >&2
    exit 1
  fi
  if ! [[ "$S" =~ ^[0-9]+$ ]] || [ "$S" -lt 1 ] || [ "$S" -gt 998 ]; then
    echo "La cuenta total de builds de prueba debe ir de 1 a 998 (es '$S'). Sube la versión en project.godot." >&2
    exit 1
  fi
  NAME="$VERSION-$AREA.$N"
  CODE=$(( BASE * 1000 + S ))
fi

sed -i "s/^version\/name=.*/version\/name=\"$NAME\"/; s/^version\/code=.*/version\/code=$CODE/" export_presets.cfg
echo "base=$VERSION"
echo "version=$NAME"
echo "code=$CODE"
