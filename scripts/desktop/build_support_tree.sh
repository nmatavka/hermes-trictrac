#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUTPUT_ROOT="${1:-$ROOT_DIR/.desktop/bundle}"
RUNTIME_OUTPUT="$OUTPUT_ROOT/runtime"
SUPPORT_OUTPUT="$OUTPUT_ROOT/support"

echo "Building Hermes release and desktop support tree..."

cd "$ROOT_DIR"

export MIX_ENV=prod
export HERMES_TRICTRAC_LOCAL_DESKTOP=1
export HERMES_TRICTRAC_IDENTITY_MODE=manual
export PHX_HOST="${PHX_HOST:-127.0.0.1}"
export PHX_URL_SCHEME="${PHX_URL_SCHEME:-http}"
export PORT="${PORT:-4050}"

mix deps.get
mix compile
mix assets.deploy
mix release --overwrite
mix hermes.generate.desktop_catalog

rm -rf "$OUTPUT_ROOT"
mkdir -p "$RUNTIME_OUTPUT" "$SUPPORT_OUTPUT/ui" "$SUPPORT_OUTPUT/images"

cp -R "$ROOT_DIR/_build/prod/rel/hermes_trictrac" "$RUNTIME_OUTPUT/"
cp -R "$ROOT_DIR/trictrac_zero" "$SUPPORT_OUTPUT/trictrac_zero"
cp -R "$ROOT_DIR/shared/ui/generated" "$SUPPORT_OUTPUT/ui/"
cp -R "$ROOT_DIR/assets/static/images/6besh" "$SUPPORT_OUTPUT/images/"

if [ -n "${HERMES_TRICTRAC_BUNDLED_JULIA_DIR:-}" ]; then
  echo "Copying bundled Julia from $HERMES_TRICTRAC_BUNDLED_JULIA_DIR"
  cp -R "$HERMES_TRICTRAC_BUNDLED_JULIA_DIR" "$SUPPORT_OUTPUT/julia"
fi

echo "Desktop support tree written to $OUTPUT_ROOT"
