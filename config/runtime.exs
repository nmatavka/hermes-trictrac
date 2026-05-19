import Config

client_id_scope =
  case System.get_env("HERMES_TRICTRAC_CLIENT_ID_SCOPE") do
    "browser" -> :browser
    "tab" -> :tab
    _ -> :tab
  end

config :hermes_trictrac, :client_id_scope, client_id_scope

prod_env? = config_env() == :prod

identity_mode =
  case {System.get_env("HERMES_TRICTRAC_IDENTITY_MODE"), prod_env?} do
    {"manual", _} -> :manual
    {"bluesky_oauth", _} -> :bluesky_oauth
    {nil, true} -> :bluesky_oauth
    {nil, false} -> :manual
    _ -> :manual
  end

config :hermes_trictrac, :identity_mode, identity_mode

host = System.get_env("PHX_HOST") || if(prod_env?, do: "example.com", else: "127.0.0.1")
port = String.to_integer(System.get_env("PORT") || "4000")
url_scheme = System.get_env("PHX_URL_SCHEME") || if(prod_env?, do: "https", else: "http")

url_port =
  case System.get_env("PHX_URL_PORT") do
    nil ->
      cond do
        prod_env? and url_scheme == "https" -> 443
        prod_env? and url_scheme == "http" -> 80
        true -> port
      end

    value ->
      String.to_integer(value)
  end

config :hermes_trictrac, HermesTrictracWeb.Endpoint,
  url: [host: host, port: url_port, scheme: url_scheme]

localhost_host? =
  host in ["localhost", "127.0.0.1", "::1"] or String.ends_with?(host, ".localhost")

oauth_base_url =
  case {url_scheme, url_port} do
    {"https", 443} -> "https://#{host}/auth/bluesky"
    {"http", 80} -> "http://#{host}/auth/bluesky"
    _ -> "#{url_scheme}://#{host}:#{url_port}/auth/bluesky"
  end

oauth_private_key =
  System.get_env("HERMES_TRICTRAC_ATPROTO_OAUTH_PRIVATE_KEY") ||
    System.get_env("ATEX_OAUTH_PRIVATE_KEY") ||
    if(localhost_host?,
      do:
        "MIGHAgEAMBMGByqGSM49AgEGCCqGSM49AwEHBG0wawIBAQQgyIpxhuDm0i3mPkrk6UdX4Sd9Jsv6YtAmSTza+A2nArShRANCAAQLF1GLueOBZOVnKWfrcnoDOO9NSRqH2utmfGMz+Rce18MDB7Z6CwFWjEq2UFYNBI4MI5cMI0+m+UYAmj4OZm+m"
    )

oauth_key_id =
  System.get_env("HERMES_TRICTRAC_ATPROTO_OAUTH_KEY_ID") ||
    System.get_env("ATEX_OAUTH_KEY_ID") ||
    if(localhost_host?, do: "awooga")

if identity_mode == :bluesky_oauth and (is_nil(oauth_private_key) or is_nil(oauth_key_id)) do
  raise """
  Bluesky OAuth is enabled, but the ATProto OAuth key configuration is missing.
  Set HERMES_TRICTRAC_ATPROTO_OAUTH_PRIVATE_KEY and HERMES_TRICTRAC_ATPROTO_OAUTH_KEY_ID,
  or override HERMES_TRICTRAC_IDENTITY_MODE=manual for emergency fallback.
  """
end

config :atex, Atex.OAuth,
  base_url: oauth_base_url,
  is_localhost: localhost_host?,
  scopes: ~w(transition:generic),
  private_key: oauth_private_key,
  key_id: oauth_key_id

config :atex,
  plc_directory_url: System.get_env("ATEX_PLC_DIRECTORY_URL") || "https://plc.directory"

if service_did = System.get_env("HERMES_TRICTRAC_ATPROTO_SERVICE_DID") || System.get_env("ATEX_SERVICE_DID") do
  config :atex, service_did: service_did
end

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

  config :hermes_trictrac, HermesTrictracWeb.Endpoint,
    http: [ip: {0, 0, 0, 0, 0, 0, 0, 0}, port: port],
    secret_key_base: secret_key_base
end
