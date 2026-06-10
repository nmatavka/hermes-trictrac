defmodule HermesTrictrac.RuntimeConfigTest do
  use ExUnit.Case, async: false

  @env_var "HERMES_TRICTRAC_CLIENT_ID_SCOPE"
  @identity_env_var "HERMES_TRICTRAC_IDENTITY_MODE"
  @desktop_env_var "HERMES_TRICTRAC_LOCAL_DESKTOP"
  @bundle_root_env_var "HERMES_TRICTRAC_DESKTOP_BUNDLE_ROOT"
  @secret_env_var "SECRET_KEY_BASE"
  @host_env_var "PHX_HOST"
  @port_env_var "PORT"

  test "runtime config resolves browser scope from the environment" do
    original = System.get_env(@env_var)

    on_exit(fn ->
      restore_env(original)
    end)

    System.put_env(@env_var, "browser")

    assert runtime_client_id_scope() == :browser
  end

  test "runtime config falls back to tab when the environment is unset or invalid" do
    original = System.get_env(@env_var)

    on_exit(fn ->
      restore_env(original)
    end)

    System.delete_env(@env_var)
    assert runtime_client_id_scope() == :tab

    System.put_env(@env_var, "something-else")
    assert runtime_client_id_scope() == :tab
  end

  test "runtime config defaults identity mode to manual outside prod" do
    original = System.get_env(@identity_env_var)

    on_exit(fn ->
      restore_named_env(@identity_env_var, original)
    end)

    System.delete_env(@identity_env_var)
    assert runtime_identity_mode() == :manual
  end

  test "runtime config accepts the Bluesky identity override from the environment" do
    original = System.get_env(@identity_env_var)

    on_exit(fn ->
      restore_named_env(@identity_env_var, original)
    end)

    System.put_env(@identity_env_var, "bluesky_oauth")
    assert runtime_identity_mode() == :bluesky_oauth
  end

  test "desktop mode defaults prod runtime to manual localhost settings" do
    originals =
      capture_env([
        @desktop_env_var,
        @identity_env_var,
        @secret_env_var,
        @host_env_var,
        @port_env_var
      ])

    on_exit(fn ->
      restore_env_map(originals)
    end)

    System.put_env(@desktop_env_var, "1")
    System.delete_env(@identity_env_var)
    System.delete_env(@secret_env_var)
    System.delete_env(@host_env_var)
    System.delete_env(@port_env_var)

    config = runtime_config(:prod)
    endpoint = endpoint_config(config)

    assert app_config(config, :identity_mode) == :manual
    assert app_config(config, :desktop_mode) == true
    assert endpoint[:server] == true
    assert endpoint[:url] == [host: "127.0.0.1", port: 4050, scheme: "http"]
    assert endpoint[:http] == [ip: {127, 0, 0, 1}, port: 4050]
    assert endpoint[:check_origin] == false
    assert is_binary(endpoint[:secret_key_base])
  end

  test "desktop bundle root is used for packaged TricTracZero assets when present" do
    originals =
      capture_env([
        @desktop_env_var,
        @bundle_root_env_var,
        "HERMES_TRICTRAC_BOT_PROJECT_DIR",
        "HERMES_TRICTRAC_BOT_SCRIPT",
        "HERMES_TRICTRAC_BOT_SESSION_DIR",
        "HERMES_TRICTRAC_BOT_JULIA"
      ])

    tmp_root =
      Path.join(
        System.tmp_dir!(),
        "hermes-desktop-runtime-config-#{System.unique_integer([:positive])}"
      )

    bundle_root = Path.join(tmp_root, "bundle")

    script_path =
      Path.join([bundle_root, "support", "trictrac_zero", "scripts", "frontend_bot.jl"])

    session_dir =
      Path.join([
        bundle_root,
        "support",
        "trictrac_zero",
        "sessions",
        "trictrac-classique-sparse-v4-arena96x16"
      ])

    julia_path = Path.join([bundle_root, "support", "julia", "bin", "julia"])

    File.mkdir_p!(Path.dirname(script_path))
    File.mkdir_p!(session_dir)
    File.mkdir_p!(Path.dirname(julia_path))
    File.write!(script_path, "# bundled")
    File.write!(julia_path, "#!/bin/sh\n")

    on_exit(fn ->
      File.rm_rf(tmp_root)
      restore_env_map(originals)
    end)

    System.put_env(@desktop_env_var, "1")
    System.put_env(@bundle_root_env_var, bundle_root)
    System.delete_env("HERMES_TRICTRAC_BOT_PROJECT_DIR")
    System.delete_env("HERMES_TRICTRAC_BOT_SCRIPT")
    System.delete_env("HERMES_TRICTRAC_BOT_SESSION_DIR")
    System.delete_env("HERMES_TRICTRAC_BOT_JULIA")

    config = runtime_config(:test)
    bot_config = app_config(config, :trictrac_model_bot)

    assert bot_config[:project_dir] == Path.join(bundle_root, "support/trictrac_zero")
    assert bot_config[:script] == script_path
    assert bot_config[:session_dir] == session_dir
    assert bot_config[:julia] == julia_path
  end

  defp runtime_client_id_scope do
    app_config(runtime_config(:test), :client_id_scope)
  end

  defp runtime_identity_mode do
    app_config(runtime_config(:test), :identity_mode)
  end

  defp runtime_config(env) do
    Config.Reader.read!(runtime_config_path(), env: env)
  end

  defp app_config(config, key) do
    config
    |> Enum.reduce(nil, fn
      {:hermes_trictrac, values}, acc when is_list(values) ->
        Keyword.get(values, key, acc)

      _, acc ->
        acc
    end)
  end

  defp endpoint_config(config) do
    config
    |> Enum.reduce([], fn
      {:hermes_trictrac, values}, acc when is_list(values) ->
        case Keyword.get(values, HermesTrictracWeb.Endpoint) do
          endpoint_values when is_list(endpoint_values) -> Keyword.merge(acc, endpoint_values)
          _other -> acc
        end

      _, acc ->
        acc
    end)
  end

  defp runtime_config_path do
    Path.expand("../../config/runtime.exs", __DIR__)
  end

  defp restore_env(nil), do: System.delete_env(@env_var)
  defp restore_env(value), do: System.put_env(@env_var, value)

  defp capture_env(names) do
    Map.new(names, fn name -> {name, System.get_env(name)} end)
  end

  defp restore_env_map(env_map) do
    Enum.each(env_map, fn {name, value} -> restore_named_env(name, value) end)
  end

  defp restore_named_env(name, nil), do: System.delete_env(name)
  defp restore_named_env(name, value), do: System.put_env(name, value)
end
