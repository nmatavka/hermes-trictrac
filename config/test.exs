import Config

config :hermes_trictrac, HermesTrictracWeb.Endpoint,
  secret_key_base: "srsgAtljdoJ36z+VGabQfKmLq6rnBP+bbNCCPfhxYfJd9X62yKd28GHb9j1CYlR4",
  http: [port: 4002],
  server: false

config :logger, level: :warning
