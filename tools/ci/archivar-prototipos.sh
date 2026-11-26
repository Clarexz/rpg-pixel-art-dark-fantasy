#!/usr/bin/env bash
# Archiva los releases del prototipo (v0.0.1 a v0.6.3) para reiniciar la serie en v0.1.0.
# Por cada uno: crea el tag proto-vX.Y.Z en el mismo commit, mueve el release a ese tag,
# lo renombra "proto-vX.Y.Z (Prototipo)" y lo marca como pre-release. Luego borra el tag
# viejo vX.Y.Z. No se borra ningún APK.
#
# Es idempotente: solo toca un tag vX.Y.Z si todavía apunta al commit del prototipo, así que
# nunca toca los releases nuevos (por ejemplo el v0.1.0 nuevo). Lo corre el CI en main.
# Requiere GH_TOKEN con permiso contents: write y GITHUB_REPOSITORY.
set -euo pipefail
R="repos/$GITHUB_REPOSITORY"

while read -r TAG SHA; do
  [ -z "$TAG" ] && continue
  CUR=$(gh api "$R/git/ref/tags/$TAG" --jq .object.sha 2>/dev/null || true)
  if [ "$CUR" != "$SHA" ]; then
    echo "$TAG: ya archivado o es de la serie nueva, no se toca."
    continue
  fi
  NEW="proto-$TAG"
  gh api "$R/git/ref/tags/$NEW" > /dev/null 2>&1 || \
    gh api -X POST "$R/git/refs" -f ref="refs/tags/$NEW" -f sha="$SHA" > /dev/null
  ID=$(gh api "$R/releases/tags/$TAG" --jq .id 2>/dev/null || true)
  if [ -n "$ID" ]; then
    gh api -X PATCH "$R/releases/$ID" -f tag_name="$NEW" -f name="$NEW (Prototipo)" \
      -F prerelease=true -f make_latest=false > /dev/null
  fi
  gh api -X DELETE "$R/git/refs/tags/$TAG"
  echo "$TAG -> $NEW (Prototipo)"
done <<'LIST'
v0.0.1 386683cd4162265261bd82d40a09ec550bfafa03
v0.1.0 9db37049ac2bfac675da83536d13e6db113e8ec0
v0.2.0 b3c20bcc46cc724e935b8fc8b632b5ed4e0a5358
v0.3.0 b5f32c2de5977da2d361821bfa1d20e4512ebfc5
v0.4.0 740eab3065403b6d5e816aeb5a5ab4898d24222e
v0.5.0 5c2337a72a5149b958858d18ba03b24d2f905512
v0.6.1 695f1648a7e00ceaec58376062d5d77daea231ac
v0.6.2 ce456a0b1ff632aef955f6ba5152fe1f92cc890e
v0.6.3 e287ff473fa7e701cb9855b01899cf8db595d7b3
LIST
