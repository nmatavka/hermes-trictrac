defmodule HermesTrictracWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :hermes_trictrac

  @session_options [
    store: :cookie,
    key: "_hermes_trictrac_key",
    signing_salt: "pUHC3+hm",
    same_site: "Lax"
  ]

  socket "/socket", HermesTrictracWeb.UserSocket,
    websocket: true,
    longpoll: false

  plug Plug.Static,
    at: "/",
    from: :hermes_trictrac,
    gzip: false,
    only: HermesTrictracWeb.static_paths()

  if code_reloading? do
    socket "/phoenix/live_reload/socket", Phoenix.LiveReloader.Socket
    plug Phoenix.LiveReloader
    plug Phoenix.CodeReloader
  end

  plug Plug.RequestId
  plug Plug.Logger

  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()

  plug Plug.MethodOverride
  plug Plug.Head

  plug Plug.Session, @session_options

  plug HermesTrictracWeb.Router
end
