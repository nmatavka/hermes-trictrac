#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

exec docker run --rm -i --network none \
  -v "${REPO_ROOT}:${REPO_ROOT}" \
  -w "${REPO_ROOT}" \
  elixir:1.19.5-otp-28 \
  elixir "$@"
