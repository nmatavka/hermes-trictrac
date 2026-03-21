#!/bin/bash

set -euo pipefail

export MIX_ENV=prod
export PHX_SERVER=true
export PORT="${PORT:-4793}"

echo "Building..."

mkdir -p ~/.config

mix deps.get
mix compile
mix assets.deploy

echo "Generating release..."
mix release

#echo "Stopping old copy of app, if any..."
#_build/prod/rel/draw/bin/practice stop || true

echo "Starting app..."

_build/prod/rel/backgammon/bin/backgammon foreground
