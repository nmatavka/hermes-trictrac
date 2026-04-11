defmodule HermesTrictrac.RuntimeConfigTest do
  use ExUnit.Case, async: false

  @env_var "HERMES_TRICTRAC_CLIENT_ID_SCOPE"

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

  defp runtime_client_id_scope do
    runtime_config_path()
    |> Config.Reader.read!(env: :test)
    |> Enum.reduce(nil, fn
      {:hermes_trictrac, values}, acc when is_list(values) ->
        Keyword.get(values, :client_id_scope, acc)

      _, acc ->
        acc
    end)
  end

  defp runtime_config_path do
    Path.expand("../../config/runtime.exs", __DIR__)
  end

  defp restore_env(nil), do: System.delete_env(@env_var)
  defp restore_env(value), do: System.put_env(@env_var, value)
end
