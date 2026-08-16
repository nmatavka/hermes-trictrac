import Config

config :hermes_trictrac, HermesTrictracWeb.Endpoint,
  url: [host: "localhost"],
  render_errors: [
    formats: [html: HermesTrictracWeb.ErrorHTML, json: HermesTrictracWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: HermesTrictrac.PubSub

config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

config :phoenix, :json_library, Jason

config :hermes_trictrac, :dice_impl, HermesTrictrac.Rules.Dice.CryptoRandom
config :hermes_trictrac, :client_id_scope, :tab

config :hermes_trictrac, :trictrac_model_bot,
  project_dir: Path.expand("../trictrac_zero", __DIR__),
  script: Path.expand("../trictrac_zero/scripts/frontend_bot.jl", __DIR__),
  session_dir:
    Path.expand("../trictrac_zero/sessions/trictrac-classique-sparse-v4-arena96x16", __DIR__),
  name: "TricTracZero"

config :hermes_trictrac, :brade_model_bot,
  project_dir: Path.expand("../trictrac_zero", __DIR__),
  script: Path.expand("../trictrac_zero/scripts/frontend_brade_bot.jl", __DIR__),
  session_dir: Path.expand("../trictrac_zero/sessions/brade-sparse-v1-arena96x16", __DIR__),
  name: "BradeZero"

config :hermes_trictrac, :race_model_bot,
  project_dir: Path.expand("../trictrac_zero", __DIR__),
  script: Path.expand("../trictrac_zero/scripts/frontend_race_bot.jl", __DIR__),
  session_dirs: %{},
  name: "RaceZero"

config :esbuild,
  version: "0.25.1",
  hermes_trictrac: [
    args: ~w(
        js/app.js
        --bundle
        --target=es2020
        --outdir=../priv/static/assets
        --public-path=/assets
        --loader:.svg=file
        --loader:.png=file
        --loader:.jpg=file
        --loader:.gif=file
        --loader:.ico=file
        --loader:.mp3=file
        --loader:.ttf=file
        --external:/fonts/*
      ),
    cd: Path.expand("../assets", __DIR__)
  ]

import_config "#{config_env()}.exs"
