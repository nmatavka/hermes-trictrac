import Config

config :hermes_trictrac, HermesTrictracWeb.Endpoint,
  http: [ip: {0, 0, 0, 0}, port: 4000],
  secret_key_base: "srsgAtljdoJ36z+VGabQfKmLq6rnBP+bbNCCPfhxYfJd9X62yKd28GHb9j1CYlR4",
  code_reloader: true,
  debug_errors: true,
  check_origin: false,
  watchers: [
    esbuild: {Esbuild, :install_and_run, [:hermes_trictrac, ~w(--sourcemap=inline --watch)]}
  ]

config :hermes_trictrac, HermesTrictracWeb.Endpoint,
  live_reload: [
    patterns: [
      ~r{priv/static/.*(js|css|png|jpeg|jpg|gif|svg)$}E,
      ~r{priv/gettext/.*(po)$}E,
      ~r{lib/hermes_trictrac_web/(controllers|components)/.*\.(ex|heex)$}E,
      ~r{lib/hermes_trictrac_web/router\.ex$}E
    ]
  ]

config :logger, :console, format: "[$level] $message\n"

config :phoenix, :stacktrace_depth, 20
