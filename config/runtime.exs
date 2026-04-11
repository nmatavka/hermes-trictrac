import Config

client_id_scope =
  case System.get_env("HERMES_TRICTRAC_CLIENT_ID_SCOPE") do
    "browser" -> :browser
    "tab" -> :tab
    _ -> :tab
  end

config :hermes_trictrac, :client_id_scope, client_id_scope

if System.get_env("PHX_SERVER") do
  config :hermes_trictrac, HermesTrictracWeb.Endpoint, server: true
end

if config_env() == :prod do
  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by running: mix phx.gen.secret
      """

  host = System.get_env("PHX_HOST") || "example.com"
  port = String.to_integer(System.get_env("PORT") || "4000")
  url_scheme = System.get_env("PHX_URL_SCHEME") || "https"

  url_port =
    case System.get_env("PHX_URL_PORT") do
      nil -> if url_scheme == "https", do: 443, else: 80
      value -> String.to_integer(value)
    end

  config :hermes_trictrac, HermesTrictracWeb.Endpoint,
    url: [host: host, port: url_port, scheme: url_scheme],
    http: [ip: {0, 0, 0, 0, 0, 0, 0, 0}, port: port],
    secret_key_base: secret_key_base
end
