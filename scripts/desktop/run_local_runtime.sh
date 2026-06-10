#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BUNDLE_ARG="${1:-$ROOT_DIR/.desktop/bundle}"
BUNDLE_ROOT="$(cd "$BUNDLE_ARG" && pwd)"
RUNTIME_ROOT="$BUNDLE_ROOT/runtime/hermes_trictrac"

export HERMES_TRICTRAC_LOCAL_DESKTOP=1
export HERMES_TRICTRAC_DESKTOP_BUNDLE_ROOT="$BUNDLE_ROOT"
export HERMES_TRICTRAC_IDENTITY_MODE=manual
export HERMES_TRICTRAC_CLIENT_ID_SCOPE=tab
export PHX_SERVER=true
export PHX_HOST="${PHX_HOST:-127.0.0.1}"
export PHX_URL_SCHEME="${PHX_URL_SCHEME:-http}"
export PORT="${PORT:-4050}"

exec "$RUNTIME_ROOT/bin/hermes_trictrac" start
