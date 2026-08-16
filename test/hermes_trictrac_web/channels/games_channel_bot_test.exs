defmodule HermesTrictracWeb.GamesChannelBotTest do
  use HermesTrictracWeb.ChannelCase, async: false

  import ExUnit.CaptureLog

  alias HermesTrictrac.GameServer
  alias HermesTrictrac.Rules.Engine
  alias HermesTrictrac.Rules.Trictrac.Classique
  alias HermesTrictracWeb.UserSocket

  defmodule FakeTrictracBot do
    def model_name, do: "FakeTricTracZero"
    def model_name(_preset), do: "FakeTricTracZero"
    def ready, do: :ok
    def ready(_preset), do: :ok

    def choose_action(serialized_state) do
      case serialized_state["legal_actions"] do
        [action | _] -> {:ok, action}
        _ -> {:error, "No legal actions available in fake bot."}
      end
    end

    def choose_action(_preset, serialized_state), do: choose_action(serialized_state)
  end

  defmodule FakeRaceBot do
    def model_name(preset), do: "Fake#{String.capitalize(preset)}Zero"
    def ready(_preset), do: :ok
    def warmup(_preset), do: :ok

    def choose_action(_preset, serialized_state) do
      case serialized_state["legal_actions"] do
        [action | _] -> {:ok, action}
        _ -> {:error, "No legal actions available in fake race bot."}
      end
    end
  end

  defmodule PresetAwareFakeTrictracBot do
    def model_name, do: "PresetAwareFakeTricTracZero"
    def model_name(_preset), do: "PresetAwareFakeTricTracZero"
    def ready, do: :ok
    def ready(_preset), do: :ok

    def choose_action(_serialized_state) do
      {:error, "choose_action/1 should not be used when choose_action/2 is available"}
    end

    def choose_action(_preset, serialized_state) do
      case serialized_state["legal_actions"] do
        [action | _] -> {:ok, action}
        _ -> {:error, "No legal actions available in preset-aware fake bot."}
      end
    end
  end

  defmodule SpyFakeTrictracBot do
    def model_name, do: "SpyFakeTricTracZero"
    def model_name(_preset), do: "SpyFakeTricTracZero"
    def ready, do: :ok
    def ready(_preset), do: :ok

    def choose_action(serialized_state) do
      notify(serialized_state)

      case serialized_state["legal_actions"] do
        [action | _] -> {:ok, action}
        _ -> {:error, "No legal actions available in spy fake bot."}
      end
    end

    def choose_action(_preset, serialized_state), do: choose_action(serialized_state)

    defp notify(serialized_state) do
      case Application.get_env(:hermes_trictrac, :trictrac_model_bot_test_pid) do
        pid when is_pid(pid) -> send(pid, {:choose_action_called, serialized_state})
        _ -> :ok
      end
    end
  end

  defmodule RollPauseFakeTrictracBot do
    def model_name, do: "RollPauseFakeTricTracZero"
    def model_name(_preset), do: "RollPauseFakeTricTracZero"
    def ready, do: :ok
    def ready(_preset), do: :ok

    def choose_action(serialized_state) do
      call_count = Process.get({__MODULE__, :call_count}, 0) + 1
      Process.put({__MODULE__, :call_count}, call_count)

      if call_count == 1 do
        case serialized_state["legal_actions"] do
          [action | _] -> {:ok, action}
          _ -> {:error, "No legal actions available in roll-pause fake bot."}
        end
      else
        notify(serialized_state)

        receive do
          :continue_bot -> {:error, "Paused after exposing the bot dice."}
        after
          1_000 -> {:error, "Timed out while waiting to resume the roll-pause fake bot."}
        end
      end
    end

    def choose_action(_preset, serialized_state), do: choose_action(serialized_state)

    defp notify(serialized_state) do
      case Application.get_env(:hermes_trictrac, :trictrac_model_bot_test_pid) do
        pid when is_pid(pid) -> send(pid, {:bot_paused_after_roll, serialized_state})
        _ -> :ok
      end
    end
  end

  defmodule InvalidActionFakeTrictracBot do
    def model_name, do: "InvalidActionFakeTricTracZero"
    def model_name(_preset), do: "InvalidActionFakeTricTracZero"
    def ready, do: :ok
    def ready(_preset), do: :ok
    def choose_action(_serialized_state), do: {:ok, %{"type" => "special", "id" => "CONFIRM"}}
    def choose_action(_preset, serialized_state), do: choose_action(serialized_state)
  end

  defmodule TimeoutExitFakeTrictracBot do
    def model_name, do: "TimeoutExitFakeTricTracZero"
    def model_name(_preset), do: "TimeoutExitFakeTricTracZero"
    def ready, do: :ok
    def ready(_preset), do: :ok

    def choose_action(_serialized_state) do
      exit(
        {:timeout, {GenServer, :call, [HermesTrictrac.TrictracModelBot, :choose_action, 120_000]}}
      )
    end

    def choose_action(_preset, serialized_state), do: choose_action(serialized_state)
  end

  defmodule SlowReadyFakeTrictracBot do
    def model_name, do: "SlowReadyFakeTricTracZero"
    def model_name(_preset), do: "SlowReadyFakeTricTracZero"
    def ready, do: ready("classique")

    def ready(preset) do
      case Application.get_env(:hermes_trictrac, :trictrac_model_bot_test_pid) do
        pid when is_pid(pid) -> send(pid, {:slow_ready_called, self(), preset})
        _ -> :ok
      end

      receive do
        :continue_slow_ready -> :ok
      after
        5_000 -> {:error, "Slow ready should not be called during join."}
      end
    end

    def choose_action(serialized_state) do
      case serialized_state["legal_actions"] do
        [action | _] -> {:ok, action}
        _ -> {:error, "No legal actions available in slow-ready fake bot."}
      end
    end

    def choose_action(_preset, serialized_state), do: choose_action(serialized_state)
  end

  defmodule PausedDecisionFakeTrictracBot do
    def model_name, do: "PausedDecisionFakeTricTracZero"
    def model_name(_preset), do: "PausedDecisionFakeTricTracZero"
    def ready, do: :ok
    def ready(_preset), do: :ok

    def choose_action(serialized_state) do
      notify(serialized_state)

      receive do
        :continue_paused_decision_bot -> {:error, "Paused decision bot resumed."}
      after
        5_000 -> {:error, "Timed out while waiting to resume the paused decision bot."}
      end
    end

    def choose_action(_preset, serialized_state), do: choose_action(serialized_state)

    defp notify(serialized_state) do
      case Application.get_env(:hermes_trictrac, :trictrac_model_bot_test_pid) do
        pid when is_pid(pid) -> send(pid, {:paused_decision_bot_started, serialized_state})
        _ -> :ok
      end
    end
  end

  setup do
    original = Application.get_env(:hermes_trictrac, :trictrac_model_bot_impl)
    Application.put_env(:hermes_trictrac, :trictrac_model_bot_impl, FakeTrictracBot)

    on_exit(fn ->
      if is_nil(original) do
        Application.delete_env(:hermes_trictrac, :trictrac_model_bot_impl)
      else
        Application.put_env(:hermes_trictrac, :trictrac_model_bot_impl, original)
      end
    end)

    :ok
  end

  test "legacy Backgammon ingress is rejected until BackgammonZero is released" do
    lobby = "bg-zero-release-#{System.unique_integer([:positive])}"
    GameServer.reg(lobby)
    GameServer.start(lobby, "backgammon")

    assert {:error, %{msg: message}} =
             GameServer.join(lobby, "nick", "bg-ai-turn-host", "backgammon", %{
               "bot" => "backgammon_ai"
             })

    assert message =~ "accepted ML champion"
  end

  test "Tavli computer play never accepts Margot" do
    lobby = "tavli-zero-margot-#{System.unique_integer([:positive])}"
    GameServer.reg(lobby)
    GameServer.start(lobby, "tavli")

    assert {:error, %{msg: "Margot is not available for this computer opponent."}} =
             GameServer.join(lobby, "nick", "tavli-zero-host", "tavli", %{
               "bot" => "tavli_zero",
               "bot_margot" => "yes"
             })
  end

  test "an accepted TavliZero release joins one Tavli table and agrees to the host target" do
    previous_config = Application.get_env(:hermes_trictrac, :race_model_bot)
    previous_impl = Application.get_env(:hermes_trictrac, :race_model_bot_impl)
    session = Path.join(System.tmp_dir!(), "tavli-zero-#{System.unique_integer([:positive])}")
    File.mkdir_p!(session)
    File.write!(Path.join(session, "bestnn.data"), "checkpoint")

    File.write!(
      Path.join(session, "race-champion.json"),
      Jason.encode!(%{"accepted" => true, "checkpoint" => "bestnn.data", "variant_id" => "tavli"})
    )

    Application.put_env(:hermes_trictrac, :race_model_bot, session_dirs: %{"tavli" => session})
    Application.put_env(:hermes_trictrac, :race_model_bot_impl, FakeRaceBot)

    on_exit(fn ->
      Application.put_env(:hermes_trictrac, :race_model_bot, previous_config)

      if is_nil(previous_impl) do
        Application.delete_env(:hermes_trictrac, :race_model_bot_impl)
      else
        Application.put_env(:hermes_trictrac, :race_model_bot_impl, previous_impl)
      end

      File.rm_rf(session)
    end)

    lobby = "tavli-zero-release-#{System.unique_integer([:positive])}"
    GameServer.reg(lobby)
    GameServer.start(lobby, "tavli")

    assert {:ok, %{game: joining}} =
             GameServer.join(lobby, "nick", "tavli-zero-host", "tavli", %{
               "bot" => "tavli_zero"
             })

    assert joining["bot"]["kind"] == "tavli_zero"
    assert joining["pending_match_options"]["kind"] == "tavli_target_consent"

    assert {:ok, _snapshot} =
             GameServer.submit_match_options(
               lobby,
               %{"tavliTargetConsent" => "3"},
               "nick",
               "tavli-zero-host"
             )

    settled = GameServer.peek(lobby)
    assert settled["variant"]["id"] == "tavli"
    assert settled["match"]["options"]["tavliTarget"] == "3"
    assert settled["pending_match_options"] == nil
  end

  test "joining with bot auto-seats the model guest and starts trictrac classique" do
    lobby = "tt-bot-#{System.unique_integer([:positive])}"

    {:ok, host_reply, _host_socket} =
      UserSocket
      |> socket("user:201", %{})
      |> subscribe_and_join(HermesTrictracWeb.GamesChannel, "games:#{lobby}", %{
        "user" => "nick",
        "variant" => "trictrac_classique",
        "bot" => "trictrac_zero",
        "client_id" => "tt-bot-host"
      })

    assert host_reply.player["color"] == "white"
    assert host_reply.game["status"] == "playing"
    assert host_reply.game["pending_match_options"] == nil
    assert host_reply.game["opening_roll"]["pending"] == true
    assert is_integer(host_reply.game["opening_roll"]["rolls"]["black"])
    assert is_nil(host_reply.game["opening_roll"]["rolls"]["white"])
    assert host_reply.game["players"]["guest"]["name"] == "FakeTricTracZero"
    assert host_reply.game["bot"]["enabled"] == true
    assert host_reply.game["bot"]["name"] == "FakeTricTracZero"
  end

  test "joining with a Margot bot applies the lobby choice and starts trictrac classique" do
    lobby = "tt-bot-margot-#{System.unique_integer([:positive])}"

    {:ok, host_reply, _host_socket} =
      UserSocket
      |> socket("user:211", %{})
      |> subscribe_and_join(HermesTrictracWeb.GamesChannel, "games:#{lobby}", %{
        "user" => "nick",
        "variant" => "trictrac_classique",
        "bot" => "trictrac_zero",
        "bot_margot" => "yes",
        "client_id" => "tt-bot-margot-host"
      })

    assert host_reply.player["color"] == "white"
    assert host_reply.game["status"] == "playing"
    assert host_reply.game["pending_match_options"] == nil
    assert host_reply.game["match"]["options"]["margotEnabled"] == true
    assert host_reply.game["opening_roll"]["pending"] == true
    assert is_integer(host_reply.game["opening_roll"]["rolls"]["black"])
    assert is_nil(host_reply.game["opening_roll"]["rolls"]["white"])
    assert host_reply.game["bot"]["enabled"] == true
  end

  test "GameServer bot join does not wait for a blocking model ready ping" do
    original_test_pid = Application.get_env(:hermes_trictrac, :trictrac_model_bot_test_pid)
    Application.put_env(:hermes_trictrac, :trictrac_model_bot_impl, SlowReadyFakeTrictracBot)
    Application.put_env(:hermes_trictrac, :trictrac_model_bot_test_pid, self())

    on_exit(fn ->
      if is_nil(original_test_pid) do
        Application.delete_env(:hermes_trictrac, :trictrac_model_bot_test_pid)
      else
        Application.put_env(:hermes_trictrac, :trictrac_model_bot_test_pid, original_test_pid)
      end
    end)

    lobby = "tt-bot-slow-ready-#{System.unique_integer([:positive])}"
    GameServer.reg(lobby)
    GameServer.start(lobby, "trictrac_classique")

    task =
      Task.async(fn ->
        GameServer.join(lobby, "nick", "tt-bot-slow-ready-host", "trictrac_classique", %{
          "bot" => "trictrac_zero",
          "bot_margot" => "yes"
        })
      end)

    result =
      case Task.yield(task, 500) do
        {:ok, {:ok, host_reply}} ->
          host_reply

        nil ->
          receive do
            {:slow_ready_called, game_server_pid, _preset} ->
              send(game_server_pid, :continue_slow_ready)
          after
            0 -> :ok
          end

          Task.shutdown(task, :brutal_kill)
          flunk("bot join waited for model ready before replying")
      end

    refute_received {:slow_ready_called, _pid, _preset}
    assert result.game["status"] == "playing"
    assert result.game["bot"]["name"] == "SlowReadyFakeTricTracZero"
    assert result.game["opening_roll"]["pending"] == true
  end

  test "Toc remains human-playable until its dedicated champion is released" do
    lobby = "toc-bot-#{System.unique_integer([:positive])}"

    assert {:error, %{msg: message}} =
             UserSocket
             |> socket("user:221", %{})
             |> subscribe_and_join(HermesTrictracWeb.GamesChannel, "games:#{lobby}", %{
               "user" => "nick",
               "variant" => "toc",
               "bot" => "trictrac_zero",
               "client_id" => "toc-bot-host"
             })

    assert message =~ "accepted ML champion"
  end

  test "the lower human-only rail rejects computer bot requests" do
    lobby = "combine-bot-#{System.unique_integer([:positive])}"
    GameServer.reg(lobby)
    GameServer.start(lobby, "trictrac_combine")

    assert {:error, %{msg: message}} =
             GameServer.join(lobby, "nick", "combine-bot-host", "trictrac_combine", %{
               "bot" => "trictrac_zero"
             })

    assert message =~ "only available for Trictrac Classique"
  end

  test "joining with a Margot bot applies the lobby choice and starts toccategli" do
    lobby = "tocc-bot-margot-#{System.unique_integer([:positive])}"

    {:ok, host_reply, _host_socket} =
      UserSocket
      |> socket("user:231", %{})
      |> subscribe_and_join(HermesTrictracWeb.GamesChannel, "games:#{lobby}", %{
        "user" => "nick",
        "variant" => "toccategli",
        "bot" => "trictrac_zero",
        "bot_margot" => "yes",
        "client_id" => "tocc-bot-host"
      })

    assert host_reply.player["color"] == "white"
    assert host_reply.game["bot"]["enabled"] == true
    assert host_reply.game["status"] == "playing"
    assert host_reply.game["pending_match_options"] == nil
    assert host_reply.game["match"]["options"]["margotEnabled"] == true
    assert host_reply.game["opening_roll"]["pending"] == true
    assert is_integer(host_reply.game["opening_roll"]["rolls"]["black"])
    assert is_nil(host_reply.game["opening_roll"]["rolls"]["white"])
  end

  test "peek can advance a bot game when the model is to roll" do
    lobby = "tt-bot-peek-#{System.unique_integer([:positive])}"
    GameServer.reg(lobby)
    GameServer.start(lobby, "trictrac_classique")

    assert {:ok, %{game: _game, player: _player}} =
             GameServer.join(lobby, "nick", "tt-bot-peek-host", "trictrac_classique", %{
               "bot" => "trictrac_zero"
             })

    pid = GenServer.whereis(GameServer.reg(lobby))

    :sys.replace_state(pid, fn state ->
      engine = state.engine

      runtime =
        engine
        |> Engine.runtime_view()
        |> Map.put(:turn_color, :black)
        |> Map.put(:turn_number, 2)
        |> Map.put(:dice, nil)
        |> Map.put(:legal_moves, [])
        |> Map.put(:pending_turn_decision, nil)

      updated_engine = %{
        engine
        | runtime: runtime,
          turn_color: :black,
          turn_number: 2,
          dice: nil,
          legal_moves: [],
          pending_turn_decision: nil
      }

      %{state | engine: updated_engine}
    end)

    snapshot = GameServer.peek(lobby)

    assert snapshot["bot"]["enabled"] == true
    assert snapshot["turn"] != nil
    refute snapshot["turn"]["color"] == "black" and is_nil(snapshot["dice"])
  end

  test "peek can advance a bot game through a decision-only none choice" do
    lobby = "tt-bot-none-#{System.unique_integer([:positive])}"
    GameServer.reg(lobby)
    GameServer.start(lobby, "trictrac_classique")

    assert {:ok, %{game: _game, player: _player}} =
             GameServer.join(lobby, "nick", "tt-bot-none-host", "trictrac_classique", %{
               "bot" => "trictrac_zero"
             })

    pid = GenServer.whereis(GameServer.reg(lobby))

    :sys.replace_state(pid, fn state ->
      engine = state.engine

      pending = %{
        "key" => "synthetic",
        "prompt" => "Synthetic",
        "actorColor" => "black",
        "choices" => ["none"]
      }

      runtime =
        engine
        |> Engine.runtime_view()
        |> Map.put(:turn_color, :black)
        |> Map.put(:turn_number, 2)
        |> Map.put(:dice, nil)
        |> Map.put(:legal_moves, [])
        |> Map.put(:pending_turn_decision, pending)

      updated_engine = %{
        engine
        | runtime: runtime,
          turn_color: :black,
          turn_number: 2,
          dice: nil,
          legal_moves: [],
          pending_turn_decision: pending
      }

      %{state | engine: updated_engine}
    end)

    snapshot = GameServer.peek(lobby)

    assert snapshot["bot"]["enabled"] == true

    refute snapshot["pending_turn_decision"] == %{
             "actorColor" => "black",
             "choices" => ["none"],
             "key" => "synthetic",
             "prompt" => "Synthetic"
           }
  end

  test "human turn decision is not reported as failed when bot follow-up action fails" do
    Application.put_env(:hermes_trictrac, :trictrac_model_bot_impl, InvalidActionFakeTrictracBot)

    lobby = "tt-bot-decision-followup-#{System.unique_integer([:positive])}"
    GameServer.reg(lobby)
    GameServer.start(lobby, "trictrac_classique")

    assert {:ok, %{game: _game, player: _player}} =
             GameServer.join(lobby, "nick", "tt-bot-decision-host", "trictrac_classique", %{
               "bot" => "trictrac_zero"
             })

    pid = GenServer.whereis(GameServer.reg(lobby))

    :sys.replace_state(pid, fn state ->
      engine = state.engine

      pending = %{
        "key" => "reprise",
        "prompt" => "Synthetic reprise",
        "actorColor" => "white",
        "choices" => ["tenir", "s'en aller"]
      }

      runtime =
        engine
        |> Engine.runtime_view()
        |> Map.put(:turn_color, :white)
        |> Map.put(:turn_number, 1)
        |> Map.put(:dice, nil)
        |> Map.put(:legal_moves, [])
        |> Map.put(:pending_turn_decision, pending)

      updated_engine = %{
        engine
        | runtime: runtime,
          turn_color: :white,
          turn_number: 1,
          dice: nil,
          legal_moves: [],
          pending_turn_decision: pending
      }

      %{state | engine: updated_engine}
    end)

    log =
      capture_log(fn ->
        assert {:ok, snapshot} =
                 GameServer.submit_turn_decision(
                   lobby,
                   "tenir",
                   "nick",
                   "tt-bot-decision-host"
                 )

        assert snapshot["pending_turn_decision"] == nil
        assert snapshot["turn"]["color"] == "black"
        assert :sys.get_state(pid).engine.turn_color == :black
      end)

    assert log =~ "Bot follow-up failed"
  end

  test "bot action timeout is logged without terminating the table" do
    Application.put_env(:hermes_trictrac, :trictrac_model_bot_impl, TimeoutExitFakeTrictracBot)

    lobby = "tt-bot-timeout-#{System.unique_integer([:positive])}"
    GameServer.reg(lobby)
    GameServer.start(lobby, "trictrac_classique")

    assert {:ok, %{game: _game, player: _player}} =
             GameServer.join(lobby, "nick", "tt-bot-timeout-host", "trictrac_classique", %{
               "bot" => "trictrac_zero"
             })

    pid = GenServer.whereis(GameServer.reg(lobby))

    :sys.replace_state(pid, fn state ->
      engine = state.engine

      runtime =
        engine
        |> Engine.runtime_view()
        |> Map.put(:turn_color, :black)
        |> Map.put(:turn_number, 2)
        |> Map.put(:dice, nil)
        |> Map.put(:legal_moves, [])
        |> Map.put(:pending_turn_decision, nil)

      updated_engine = %{
        engine
        | runtime: runtime,
          turn_color: :black,
          turn_number: 2,
          dice: nil,
          legal_moves: [],
          pending_turn_decision: nil
      }

      %{state | engine: updated_engine}
    end)

    log =
      capture_log(fn ->
        snapshot = GameServer.peek(lobby)
        assert snapshot["turn"]["color"] == "black"
      end)

    assert log =~ "Timed out waiting for the bot to choose an action."
    assert Process.alive?(pid)
  end

  test "human turn decision replies before a slow bot follow-up completes" do
    original_test_pid = Application.get_env(:hermes_trictrac, :trictrac_model_bot_test_pid)
    Application.put_env(:hermes_trictrac, :trictrac_model_bot_test_pid, self())

    on_exit(fn ->
      if is_nil(original_test_pid) do
        Application.delete_env(:hermes_trictrac, :trictrac_model_bot_test_pid)
      else
        Application.put_env(:hermes_trictrac, :trictrac_model_bot_test_pid, original_test_pid)
      end
    end)

    lobby = "tt-bot-decision-async-#{System.unique_integer([:positive])}"
    GameServer.reg(lobby)
    GameServer.start(lobby, "trictrac_classique")

    assert {:ok, %{game: _game, player: _player}} =
             GameServer.join(lobby, "nick", "tt-bot-decision-async-host", "trictrac_classique", %{
               "bot" => "trictrac_zero"
             })

    Application.put_env(:hermes_trictrac, :trictrac_model_bot_impl, PausedDecisionFakeTrictracBot)

    pid = GenServer.whereis(GameServer.reg(lobby))

    :sys.replace_state(pid, fn state ->
      engine = state.engine

      pending = %{
        "key" => "reprise",
        "prompt" => "Synthetic reprise",
        "actorColor" => "white",
        "choices" => ["tenir", "s'en aller"]
      }

      runtime =
        engine
        |> Engine.runtime_view()
        |> Map.put(:turn_color, :white)
        |> Map.put(:turn_number, 1)
        |> Map.put(:dice, nil)
        |> Map.put(:legal_moves, [])
        |> Map.put(:pending_turn_decision, pending)

      updated_engine = %{
        engine
        | runtime: runtime,
          turn_color: :white,
          turn_number: 1,
          dice: nil,
          legal_moves: [],
          pending_turn_decision: pending
      }

      %{state | engine: updated_engine}
    end)

    task =
      Task.async(fn ->
        GameServer.submit_turn_decision(lobby, "tenir", "nick", "tt-bot-decision-async-host")
      end)

    snapshot =
      case Task.yield(task, 500) do
        {:ok, {:ok, snapshot}} ->
          snapshot

        nil ->
          send(pid, :continue_paused_decision_bot)
          Task.shutdown(task, :brutal_kill)
          flunk("submit_turn_decision waited for the bot follow-up before replying")
      end

    assert snapshot["pending_turn_decision"] == nil
    assert snapshot["turn"]["color"] == "black"
    assert snapshot["viewer"]["seat_color"] == "white"

    assert_receive {:paused_decision_bot_started, serialized_state}, 500
    assert is_list(serialized_state["legal_actions"])
    refute get_in(serialized_state, ["runtime", "tactical_tariffs"])

    send(pid, :continue_paused_decision_bot)
    assert :sys.get_state(pid).engine.turn_color == :black
  end

  test "peek advances a bot decision when actorColor is black even if turn_color is white" do
    lobby = "tt-bot-actorcolor-#{System.unique_integer([:positive])}"
    GameServer.reg(lobby)
    GameServer.start(lobby, "trictrac_classique")

    assert {:ok, %{game: _game, player: _player}} =
             GameServer.join(lobby, "nick", "tt-bot-actorcolor-host", "trictrac_classique", %{
               "bot" => "trictrac_zero"
             })

    pid = GenServer.whereis(GameServer.reg(lobby))

    :sys.replace_state(pid, fn state ->
      engine = state.engine

      pending = %{
        "key" => "synthetic",
        "prompt" => "Synthetic",
        "actorColor" => "black",
        "choices" => ["none"]
      }

      runtime =
        engine
        |> Engine.runtime_view()
        |> Map.put(:turn_color, :white)
        |> Map.put(:turn_number, 2)
        |> Map.put(:dice, nil)
        |> Map.put(:legal_moves, [])
        |> Map.put(:pending_turn_decision, pending)

      updated_engine = %{
        engine
        | runtime: runtime,
          turn_color: :white,
          turn_number: 2,
          dice: nil,
          legal_moves: [],
          pending_turn_decision: pending
      }

      %{state | engine: updated_engine}
    end)

    snapshot = GameServer.peek(lobby)

    assert snapshot["bot"]["enabled"] == true

    refute snapshot["pending_turn_decision"] == %{
             "actorColor" => "black",
             "choices" => ["none"],
             "key" => "synthetic",
             "prompt" => "Synthetic"
           }
  end

  test "peek does not let the bot answer a hidden white decision from the trictrac queue" do
    original_impl = Application.get_env(:hermes_trictrac, :trictrac_model_bot_impl)
    original_test_pid = Application.get_env(:hermes_trictrac, :trictrac_model_bot_test_pid)

    on_exit(fn ->
      if is_nil(original_impl) do
        Application.delete_env(:hermes_trictrac, :trictrac_model_bot_impl)
      else
        Application.put_env(:hermes_trictrac, :trictrac_model_bot_impl, original_impl)
      end

      if is_nil(original_test_pid) do
        Application.delete_env(:hermes_trictrac, :trictrac_model_bot_test_pid)
      else
        Application.put_env(:hermes_trictrac, :trictrac_model_bot_test_pid, original_test_pid)
      end
    end)

    lobby = "tt-bot-hidden-white-#{System.unique_integer([:positive])}"
    GameServer.reg(lobby)
    GameServer.start(lobby, "trictrac_classique")

    assert {:ok, %{game: _game, player: _player}} =
             GameServer.join(lobby, "nick", "tt-bot-hidden-white-host", "trictrac_classique", %{
               "bot" => "trictrac_zero"
             })

    Application.put_env(:hermes_trictrac, :trictrac_model_bot_impl, SpyFakeTrictracBot)
    Application.put_env(:hermes_trictrac, :trictrac_model_bot_test_pid, self())

    pid = GenServer.whereis(GameServer.reg(lobby))

    :sys.replace_state(pid, fn state ->
      engine = state.engine

      hidden_pending = %{
        "key" => "reprise",
        "prompt" => "Synthetic hidden white reprise",
        "actorColor" => "white",
        "choices" => ["tenir", "s'en aller"]
      }

      trictrac =
        engine.runtime.trictrac
        |> Classique.set_turn_event_queue([hidden_pending])

      runtime =
        engine.runtime
        |> Map.put(:trictrac, trictrac)

      updated_engine = %{
        engine
        | runtime: runtime,
          trictrac: trictrac,
          turn_color: :black,
          turn_number: 12,
          dice: nil,
          legal_moves: [],
          pending_turn_decision: nil
      }

      %{state | engine: updated_engine}
    end)

    log =
      capture_log(fn ->
        snapshot = GameServer.peek(lobby)
        assert snapshot["bot"]["enabled"] == true
      end)

    refute_received {:choose_action_called, _serialized_state}
    refute log =~ "TricTrac frontend bot stalled"
  end

  test "peek advances a hidden black decision from the trictrac queue" do
    original_impl = Application.get_env(:hermes_trictrac, :trictrac_model_bot_impl)
    original_test_pid = Application.get_env(:hermes_trictrac, :trictrac_model_bot_test_pid)

    on_exit(fn ->
      if is_nil(original_impl) do
        Application.delete_env(:hermes_trictrac, :trictrac_model_bot_impl)
      else
        Application.put_env(:hermes_trictrac, :trictrac_model_bot_impl, original_impl)
      end

      if is_nil(original_test_pid) do
        Application.delete_env(:hermes_trictrac, :trictrac_model_bot_test_pid)
      else
        Application.put_env(:hermes_trictrac, :trictrac_model_bot_test_pid, original_test_pid)
      end
    end)

    lobby = "tt-bot-hidden-black-#{System.unique_integer([:positive])}"
    GameServer.reg(lobby)
    GameServer.start(lobby, "trictrac_classique")

    assert {:ok, %{game: _game, player: _player}} =
             GameServer.join(lobby, "nick", "tt-bot-hidden-black-host", "trictrac_classique", %{
               "bot" => "trictrac_zero"
             })

    Application.put_env(:hermes_trictrac, :trictrac_model_bot_impl, SpyFakeTrictracBot)
    Application.put_env(:hermes_trictrac, :trictrac_model_bot_test_pid, self())

    pid = GenServer.whereis(GameServer.reg(lobby))

    :sys.replace_state(pid, fn state ->
      engine = state.engine

      hidden_pending = %{
        "key" => "synthetic",
        "prompt" => "Synthetic hidden black decision",
        "actorColor" => "black",
        "choices" => ["none"]
      }

      trictrac =
        engine.runtime.trictrac
        |> Classique.set_turn_event_queue([hidden_pending])

      runtime =
        engine.runtime
        |> Map.put(:trictrac, trictrac)

      updated_engine = %{
        engine
        | runtime: runtime,
          trictrac: trictrac,
          turn_color: :white,
          turn_number: 12,
          dice: nil,
          legal_moves: [],
          pending_turn_decision: nil
      }

      %{state | engine: updated_engine}
    end)

    snapshot = GameServer.peek(lobby)

    assert snapshot["bot"]["enabled"] == true
    assert_received {:choose_action_called, _serialized_state}
  end

  test "bot prefers choose_action/2 so the explicit preset is preserved during live turns" do
    original = Application.get_env(:hermes_trictrac, :trictrac_model_bot_impl)
    Application.put_env(:hermes_trictrac, :trictrac_model_bot_impl, PresetAwareFakeTrictracBot)

    on_exit(fn ->
      if is_nil(original) do
        Application.delete_env(:hermes_trictrac, :trictrac_model_bot_impl)
      else
        Application.put_env(:hermes_trictrac, :trictrac_model_bot_impl, original)
      end
    end)

    lobby = "tt-bot-preset-#{System.unique_integer([:positive])}"
    GameServer.reg(lobby)
    GameServer.start(lobby, "trictrac_classique")

    assert {:ok, %{game: _game, player: _player}} =
             GameServer.join(lobby, "nick", "tt-bot-preset-host", "trictrac_classique", %{
               "bot" => "trictrac_zero"
             })

    pid = GenServer.whereis(GameServer.reg(lobby))

    :sys.replace_state(pid, fn state ->
      engine = state.engine

      runtime =
        engine
        |> Engine.runtime_view()
        |> Map.put(:turn_color, :white)
        |> Map.put(:turn_number, 2)
        |> Map.put(:dice, nil)
        |> Map.put(:legal_moves, [])
        |> Map.put(:pending_turn_decision, nil)

      updated_engine = %{
        engine
        | runtime: runtime,
          turn_color: :white,
          turn_number: 2,
          dice: nil,
          legal_moves: [],
          pending_turn_decision: nil
      }

      %{state | engine: updated_engine}
    end)

    assert {:ok, _game} = GameServer.roll(lobby, "nick", "tt-bot-preset-host")

    play_available_checker_moves(lobby, pid, "nick", "tt-bot-preset-host")

    assert {:ok, game} = GameServer.confirm(lobby, "nick", "tt-bot-preset-host")
    assert game["turn"]["color"] == "black"

    game = GameServer.peek(lobby)
    assert game["turn"]["color"] == "white"
    assert game["turn"]["number"] == 4
  end

  test "human move in a bot game does not wake TrictracZero while the turn remains human" do
    original_impl = Application.get_env(:hermes_trictrac, :trictrac_model_bot_impl)
    original_test_pid = Application.get_env(:hermes_trictrac, :trictrac_model_bot_test_pid)
    Application.put_env(:hermes_trictrac, :trictrac_model_bot_impl, SpyFakeTrictracBot)
    Application.put_env(:hermes_trictrac, :trictrac_model_bot_test_pid, self())

    on_exit(fn ->
      if is_nil(original_impl) do
        Application.delete_env(:hermes_trictrac, :trictrac_model_bot_impl)
      else
        Application.put_env(:hermes_trictrac, :trictrac_model_bot_impl, original_impl)
      end

      if is_nil(original_test_pid) do
        Application.delete_env(:hermes_trictrac, :trictrac_model_bot_test_pid)
      else
        Application.put_env(:hermes_trictrac, :trictrac_model_bot_test_pid, original_test_pid)
      end
    end)

    lobby = "tt-bot-human-move-#{System.unique_integer([:positive])}"
    GameServer.reg(lobby)
    GameServer.start(lobby, "trictrac_classique")

    assert {:ok, %{game: _game, player: _player}} =
             GameServer.join(lobby, "nick", "tt-bot-human-move-host", "trictrac_classique", %{
               "bot" => "trictrac_zero",
               "bot_margot" => "yes"
             })

    pid = GenServer.whereis(GameServer.reg(lobby))

    :sys.replace_state(pid, fn state ->
      engine = state.engine

      runtime =
        engine
        |> Engine.runtime_view()
        |> Map.put(:turn_color, :white)
        |> Map.put(:turn_number, 2)
        |> Map.put(:dice, nil)
        |> Map.put(:legal_moves, [])
        |> Map.put(:pending_turn_decision, nil)

      updated_engine = %{
        engine
        | runtime: runtime,
          turn_color: :white,
          turn_number: 2,
          dice: nil,
          legal_moves: [],
          pending_turn_decision: nil
      }

      %{state | engine: updated_engine}
    end)

    assert {:ok, game} = GameServer.roll(lobby, "nick", "tt-bot-human-move-host")
    assert game["turn"]["color"] == "white"

    move_action =
      pid
      |> :sys.get_state()
      |> then(fn state -> Engine.runtime_view(state.engine) end)
      |> HermesTrictrac.Training.TrictracBridge.serialize_state()
      |> Map.fetch!("legal_actions")
      |> Enum.find(&(&1["type"] == "move"))

    assert move_action

    assert {:ok, game} =
             GameServer.move(
               lobby,
               %{
                 "from" => move_action["from"],
                 "to" => move_action["to"],
                 "sequence" => move_action["sequence"]
               },
               "nick",
               "tt-bot-human-move-host"
             )

    assert game["turn"]["color"] == "white"
    refute_received {:choose_action_called, _serialized_state}
  end

  test "channel subscribers receive an intermediate update with the bot dice before its turn finishes" do
    original_impl = Application.get_env(:hermes_trictrac, :trictrac_model_bot_impl)
    original_test_pid = Application.get_env(:hermes_trictrac, :trictrac_model_bot_test_pid)
    Application.put_env(:hermes_trictrac, :trictrac_model_bot_impl, RollPauseFakeTrictracBot)
    Application.put_env(:hermes_trictrac, :trictrac_model_bot_test_pid, self())

    on_exit(fn ->
      if is_nil(original_impl) do
        Application.delete_env(:hermes_trictrac, :trictrac_model_bot_impl)
      else
        Application.put_env(:hermes_trictrac, :trictrac_model_bot_impl, original_impl)
      end

      if is_nil(original_test_pid) do
        Application.delete_env(:hermes_trictrac, :trictrac_model_bot_test_pid)
      else
        Application.put_env(:hermes_trictrac, :trictrac_model_bot_test_pid, original_test_pid)
      end
    end)

    lobby = "tt-bot-visible-dice-#{System.unique_integer([:positive])}"

    {:ok, _host_reply, _host_socket} =
      UserSocket
      |> socket("user:251", %{})
      |> subscribe_and_join(HermesTrictracWeb.GamesChannel, "games:#{lobby}", %{
        "user" => "nick",
        "variant" => "trictrac_classique",
        "bot" => "trictrac_zero",
        "client_id" => "tt-bot-visible-host"
      })

    drain_updates()

    pid = GenServer.whereis(GameServer.reg(lobby))

    :sys.replace_state(pid, fn state ->
      engine = state.engine

      runtime =
        engine
        |> Engine.runtime_view()
        |> Map.put(:turn_color, :white)
        |> Map.put(:turn_number, 3)
        |> Map.put(:dice, %{values: [1], moves: [1], moves_left: [], moves_played: [1]})
        |> Map.put(:legal_moves, [])
        |> Map.put(:pending_turn_decision, nil)

      updated_engine = %{
        engine
        | runtime: runtime,
          turn_color: :white,
          turn_number: 3,
          dice: runtime.dice,
          legal_moves: [],
          history: [],
          pending_turn_decision: nil
      }

      %{state | engine: updated_engine}
    end)

    log =
      capture_log(fn ->
        assert {:ok, game} = GameServer.confirm(lobby, "nick", "tt-bot-visible-host")
        assert game["turn"]["color"] == "black"
        assert game["dice"] == nil

        assert_receive {:bot_paused_after_roll, serialized_state}
        assert is_list(serialized_state["legal_actions"])
        refute get_in(serialized_state, ["runtime", "tactical_tariffs"])

        assert_broadcast "update", %{
          game: %{
            "turn" => %{"color" => "black"},
            "dice" => %{"values" => values}
          }
        }

        assert is_list(values)
        assert values != []

        send(pid, :continue_bot)
        assert :sys.get_state(pid).engine.turn_color == :black
      end)

    assert log =~ "Paused after exposing the bot dice."
  end

  defp drain_updates do
    receive do
      %Phoenix.Socket.Broadcast{event: "update"} -> drain_updates()
    after
      0 -> :ok
    end
  end

  defp play_available_checker_moves(lobby, pid, user, client_id) do
    state = :sys.get_state(pid)

    serialized =
      HermesTrictrac.Training.TrictracBridge.serialize_state(Engine.runtime_view(state.engine))

    case Enum.find(serialized["legal_actions"], &(&1["type"] == "move")) do
      nil ->
        :ok

      move_action ->
        assert {:ok, _game} =
                 GameServer.move(
                   lobby,
                   %{
                     "from" => move_action["from"],
                     "to" => move_action["to"],
                     "sequence" => move_action["sequence"]
                   },
                   user,
                   client_id
                 )

        play_available_checker_moves(lobby, pid, user, client_id)
    end
  end
end
