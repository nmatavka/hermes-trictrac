import Config

config :backgammon, BackgammonWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4000],
  secret_key_base: "srsgAtljdoJ36z+VGabQfKmLq6rnBP+bbNCCPfhxYfJd9X62yKd28GHb9j1CYlR4",
  code_reloader: true,
  debug_errors: true,
  check_origin: false,
  watchers: [
    esbuild: {Esbuild, :install_and_run, [:backgammon, ~w(--sourcemap=inline --watch)]}
  ]

config :backgammon, BackgammonWeb.Endpoint,
  live_reload: [
    patterns: [
      ~r{priv/static/.*(js|css|png|jpeg|jpg|gif|svg)$},
      ~r{priv/gettext/.*(po)$},
      ~r{lib/backgammon_web/(controllers|components)/.*\.(ex|heex)$},
      ~r{lib/backgammon_web/router\.ex$}
    ]
  ]

config :logger, :console, format: "[$level] $message\n"

config :phoenix, :stacktrace_depth, 20
