#!/usr/bin/env bash
# Corre el juego sin ventana unos segundos y falla si Godot reporta errores
# de script o de carga. Es nuestra "prueba de humo" antes de exportar.
set -uo pipefail
cd "$(dirname "$0")/../.."
GODOT=${GODOT:-godot}
FRAMES=${FRAMES:-300}

LOG=$(mktemp)
"$GODOT" --headless --path . --quit-after "$FRAMES" 2>&1 | tee "$LOG"
if grep -qE "SCRIPT ERROR|^ERROR:|Parse Error|Failed to load" "$LOG"; then
  echo "::error::El smoke test encontró errores (ver log arriba)."
  exit 1
fi
echo "Smoke test OK ($FRAMES frames sin errores)."
