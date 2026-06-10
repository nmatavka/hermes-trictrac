#!/bin/bash
set -euo pipefail

exec docker run --rm -i --network none \
  -v /root/backgammon:/root/backgammon \
  -w /root/backgammon \
  elixir:1.19.5-otp-28 \
  elixir "$@"
