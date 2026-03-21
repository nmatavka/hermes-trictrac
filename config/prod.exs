import Config

config :backgammon, BackgammonWeb.Endpoint,
  cache_static_manifest: "priv/static/cache_manifest.json"

config :logger, level: :info
