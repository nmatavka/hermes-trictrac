defmodule HermesTrictrac.MaintenanceTest do
  use ExUnit.Case, async: false

  alias HermesTrictrac.{GameServer, Maintenance}

  test "resets only active Bräde tables for the parallel-play correction" do
    brade_table = "brade-reset-#{System.unique_integer([:positive])}"
    backgammon_table = "backgammon-keep-#{System.unique_integer([:positive])}"

    start_table(brade_table, "brade")
    start_table(backgammon_table, "backgammon")

    on_exit(fn ->
      stop_table(brade_table)
      stop_table(backgammon_table)
    end)

    join_table(brade_table, "brade")
    join_table(backgammon_table, "backgammon")

    assert {:ok, _} =
             GameServer.submit_match_options(
               brade_table,
               %{"matchLength" => "3"},
               "nick",
               "brade-host"
             )

    assert {:ok, _} =
             GameServer.chat(
               brade_table,
               %{"data" => %{"text" => "This game uses the old route."}},
               "nick",
               "brade-host"
             )

    before_reset = GameServer.peek(brade_table)
    assert before_reset["pending_match_options"] == nil
    assert length(before_reset["chat"]) == 1

    assert [^brade_table] = Maintenance.reset_brade_tables()

    brade_snapshot = GameServer.peek(brade_table)
    backgammon_snapshot = GameServer.peek(backgammon_table)

    assert brade_snapshot["variant"]["id"] == "brade"
    assert brade_snapshot["players"]["host"]["name"] == "nick"
    assert brade_snapshot["players"]["guest"]["name"] == "jane"
    assert brade_snapshot["pending_match_options"]["rule"] == "Brade"
    assert brade_snapshot["chat"] == []
    assert Enum.at(brade_snapshot["board"]["points"], 23)["pieces"] == List.duplicate("white", 15)
    assert Enum.at(brade_snapshot["board"]["points"], 0)["pieces"] == List.duplicate("black", 15)

    assert backgammon_snapshot["variant"]["id"] == "backgammon"
    assert backgammon_snapshot["players"]["host"]["name"] == "nick"
    assert backgammon_snapshot["players"]["guest"]["name"] == "jane"
  end

  defp start_table(name, variant) do
    assert {:ok, _pid} = GameServer.start(name, variant)
  end

  defp join_table(name, variant) do
    assert {:ok, _} = GameServer.join(name, "nick", "#{variant}-host", variant)
    assert {:ok, _} = GameServer.join(name, "jane", "#{variant}-guest", variant)
  end

  defp stop_table(name) do
    case GenServer.whereis(GameServer.reg(name)) do
      nil -> :ok
      pid -> DynamicSupervisor.terminate_child(HermesTrictrac.GameSup, pid)
    end
  end
end
