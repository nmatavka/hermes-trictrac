defmodule BackgammonWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :backgammon

  @session_options [
    store: :cookie,
    key: "_backgammon_key",
    signing_salt: "pUHC3+hm",
    same_site: "Lax"
  ]

  socket "/socket", BackgammonWeb.UserSocket,
    websocket: true,
    longpoll: false

  plug Plug.Static,
    at: "/",
    from: :backgammon,
    gzip: false,
    only: BackgammonWeb.static_paths()

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

  plug BackgammonWeb.Router
end
