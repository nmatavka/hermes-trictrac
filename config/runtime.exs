import Config

truthy_env? = fn
  value when value in ["1", "true", "TRUE", "yes", "on"] -> true
  _other -> false
end

client_id_scope =
  case System.get_env("HERMES_TRICTRAC_CLIENT_ID_SCOPE") do
    "browser" -> :browser
    "tab" -> :tab
    _ -> :tab
  end

config :hermes_trictrac, :client_id_scope, client_id_scope

prod_env? = config_env() == :prod

desktop_mode? =
  System.get_env("HERMES_TRICTRAC_LOCAL_DESKTOP")
  |> truthy_env?.()

config :hermes_trictrac, :desktop_mode, desktop_mode?

desktop_bundle_root =
  case System.get_env("HERMES_TRICTRAC_DESKTOP_BUNDLE_ROOT") do
    nil -> nil
    path -> Path.expand(path)
  end

desktop_support_root = desktop_bundle_root && Path.join(desktop_bundle_root, "support")

support_path = fn parts ->
  if desktop_support_root do
    Path.join([desktop_support_root | List.wrap(parts)])
  end
end

first_existing = fn candidates, predicate ->
  candidates
  |> Enum.reject(&is_nil/1)
  |> Enum.find(predicate)
end

repo_trictrac_zero_dir = Path.expand("../trictrac_zero", __DIR__)

default_trictrac_zero_dir =
  first_existing.(
    [
      support_path.(["trictrac_zero"]),
      repo_trictrac_zero_dir
    ],
    &File.dir?/1
  ) || repo_trictrac_zero_dir

trictrac_zero_dir =
  System.get_env("HERMES_TRICTRAC_BOT_PROJECT_DIR") || default_trictrac_zero_dir

trictrac_bot_script =
  System.get_env("HERMES_TRICTRAC_BOT_SCRIPT") ||
    first_existing.(
      [
        support_path.(["trictrac_zero", "scripts", "frontend_bot.jl"]),
        Path.join(trictrac_zero_dir, "scripts/frontend_bot.jl")
      ],
      &File.regular?/1
    ) || Path.join(trictrac_zero_dir, "scripts/frontend_bot.jl")

default_session_dir =
  Path.join(trictrac_zero_dir, "sessions/trictrac-classique-sparse-v4-arena96x16")

trictrac_bot_session_dir =
  System.get_env("HERMES_TRICTRAC_BOT_SESSION_DIR") ||
    first_existing.(
      [
        support_path.(["trictrac_zero", "sessions", "trictrac-classique-sparse-v4-arena96x16"]),
        default_session_dir
      ],
      &File.dir?/1
    ) || default_session_dir

session_dirs =
  %{
    "classique" =>
      Path.join(trictrac_zero_dir, "sessions/trictrac-classique-sparse-v4-arena96x16"),
    "classique-margot" =>
      Path.join(trictrac_zero_dir, "sessions/trictrac-classique-margot-sparse-v4-arena96x16"),
    "aecrire" => Path.join(trictrac_zero_dir, "sessions/trictrac-aecrire-sparse-v4-arena96x16"),
    "toccategli" => Path.join(trictrac_zero_dir, "sessions/toccategli-sparse-v4-arena96x16")
  }
  |> Enum.filter(fn {_preset, path} -> File.dir?(path) end)
  |> Enum.into(%{})

bundled_julia =
  first_existing.(
    [
      support_path.(["julia", "bin", "julia"]),
      support_path.(["julia", "bin", "julia.exe"])
    ],
    &File.regular?/1
  )

trictrac_bot_julia =
  System.get_env("HERMES_TRICTRAC_BOT_JULIA") || bundled_julia || System.find_executable("julia") ||
    "julia"

trictrac_bot_name = System.get_env("HERMES_TRICTRAC_BOT_NAME") || "TricTracZero"

config :hermes_trictrac, :trictrac_model_bot,
  project_dir: trictrac_zero_dir,
  script: trictrac_bot_script,
  session_dir: trictrac_bot_session_dir,
  session_dirs: session_dirs,
  julia: trictrac_bot_julia,
  name: trictrac_bot_name

identity_mode =
  case {System.get_env("HERMES_TRICTRAC_IDENTITY_MODE"), prod_env?, desktop_mode?} do
    {"manual", _, _} -> :manual
    {"bluesky_oauth", _, _} -> :bluesky_oauth
    {nil, _, true} -> :manual
    {nil, true, false} -> :bluesky_oauth
    {nil, false, false} -> :manual
    _ -> :manual
  end

config :hermes_trictrac, :identity_mode, identity_mode

host =
  System.get_env("PHX_HOST") ||
    cond do
      desktop_mode? -> "127.0.0.1"
      prod_env? -> "example.com"
      true -> "127.0.0.1"
    end

port =
  (System.get_env("PORT") ||
     if(desktop_mode?, do: "4050", else: "4000"))
  |> String.to_integer()

url_scheme =
  System.get_env("PHX_URL_SCHEME") ||
    cond do
      desktop_mode? -> "http"
      prod_env? -> "https"
      true -> "http"
    end

url_port =
  case System.get_env("PHX_URL_PORT") do
    nil ->
      cond do
        desktop_mode? -> port
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

if service_did =
     System.get_env("HERMES_TRICTRAC_ATPROTO_SERVICE_DID") || System.get_env("ATEX_SERVICE_DID") do
  config :atex, service_did: service_did
end

if System.get_env("PHX_SERVER") || desktop_mode? do
  config :hermes_trictrac, HermesTrictracWeb.Endpoint, server: true
end

if config_env() == :prod do
  desktop_secret_key_base =
    System.get_env("HERMES_TRICTRAC_DESKTOP_SECRET_KEY_BASE") ||
      Base.encode64(:crypto.hash(:sha512, "hermes-trictrac-desktop-local-runtime"))

  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      if(desktop_mode?, do: desktop_secret_key_base) ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by running: mix phx.gen.secret
      """

  config :hermes_trictrac, HermesTrictracWeb.Endpoint,
    http: [ip: if(desktop_mode?, do: {127, 0, 0, 1}, else: {0, 0, 0, 0, 0, 0, 0, 0}), port: port],
    secret_key_base: secret_key_base,
    check_origin: if(desktop_mode?, do: false, else: true)
end
