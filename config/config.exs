import Config

config :backgammon, BackgammonWeb.Endpoint,
  url: [host: "localhost"],
  render_errors: [
    formats: [html: BackgammonWeb.ErrorHTML, json: BackgammonWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Backgammon.PubSub

config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

config :phoenix, :json_library, Jason

config :backgammon, :dice_impl, Backgammon.Rules.Dice.CryptoRandom

config :esbuild,
  version: "0.25.1",
  backgammon: [
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
      ),
    cd: Path.expand("../assets", __DIR__)
  ]

import_config "#{config_env()}.exs"
