defmodule HermesTrictracWeb.GamesChannelBotTest do
  use HermesTrictracWeb.ChannelCase, async: false

  import ExUnit.CaptureLog

  alias HermesTrictrac.GameServer
  alias HermesTrictrac.Rules.{Engine, RaceCore}
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

  test "English backgammon can be hosted against the copied BackgammonAI bot" do
    lobby = "bg-ai-join-#{System.unique_integer([:positive])}"

    {:ok, reply, _socket} =
      UserSocket
      |> socket("user:bg-ai", %{})
      |> subscribe_and_join(HermesTrictracWeb.GamesChannel, "games:#{lobby}", %{
        "user" => "nick",
        "variant" => "backgammon",
        "bot" => "backgammon_ai",
        "client_id" => "bg-ai-host"
      })

    assert reply.player["color"] == "white"
    assert reply.game["variant"]["id"] == "backgammon"
    assert reply.game["bot"]["kind"] == "backgammon_ai"
    assert reply.game["bot"]["name"] == "BackgammonAI"
    assert reply.game["players"]["guest"]["name"] == "BackgammonAI"
    assert get_in(reply.game, ["opening_roll", "rolls", "black"]) in 1..6
  end

  test "BackgammonAI bot plays and confirms a forced in-progress turn" do
    lobby = "bg-ai-turn-#{System.unique_integer([:positive])}"
    GameServer.reg(lobby)
    GameServer.start(lobby, "backgammon")

    assert {:ok, %{game: _game, player: _player}} =
             GameServer.join(lobby, "nick", "bg-ai-turn-host", "backgammon", %{
               "bot" => "backgammon_ai"
             })

    pid = GenServer.whereis(GameServer.reg(lobby))

    before_board =
      :sys.replace_state(pid, fn state ->
        engine = state.engine
        dice = %{values: [1, 2], moves: [1, 2], moves_left: [1, 2], moves_played: []}

        runtime =
          engine
          |> Engine.runtime_view()
          |> Map.put(:turn_color, :black)
          |> Map.put(:turn_number, 42)
          |> Map.put(:dice, dice)
          |> Map.put(:pending_turn_decision, nil)

        runtime = %{runtime | legal_moves: RaceCore.legal_moves(runtime, engine.variant, :black)}

        updated_engine = %{
          engine
          | runtime: runtime,
            board: runtime.board,
            turn_color: :black,
            turn_number: 42,
            dice: dice,
            legal_moves: runtime.legal_moves,
            pending_turn_decision: nil
        }

        %{state | engine: updated_engine}
      end).engine.board

    snapshot = GameServer.peek(lobby)
    state = :sys.get_state(pid)

    assert snapshot["turn"]["color"] == "white"
    assert state.engine.turn_color == :white
    assert state.engine.dice == nil
    refute state.engine.board == before_board
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

  test "joining with bot is exposed for toc and applies default match options" do
    lobby = "toc-bot-#{System.unique_integer([:positive])}"

    {:ok, host_reply, _host_socket} =
      UserSocket
      |> socket("user:221", %{})
      |> subscribe_and_join(HermesTrictracWeb.GamesChannel, "games:#{lobby}", %{
        "user" => "nick",
        "variant" => "toc",
        "bot" => "trictrac_zero",
        "bot_margot" => "yes",
        "client_id" => "toc-bot-host"
      })

    assert host_reply.player["color"] == "white"
    assert host_reply.game["bot"]["enabled"] == true
    assert host_reply.game["status"] == "playing"
    assert host_reply.game["pending_match_options"] == nil
    assert host_reply.game["match"]["options"]["holeTarget"] == "1"
    assert host_reply.game["match"]["options"]["doublesMode"] == "on"
    assert host_reply.game["match"]["options"]["margotEnabled"] == true
    assert host_reply.game["opening_roll"]["pending"] == true
    assert is_integer(host_reply.game["opening_roll"]["rolls"]["black"])
    assert is_nil(host_reply.game["opening_roll"]["rolls"]["white"])
  end

  test "joining with bot is exposed for trictrac combine and applies default match options" do
    lobby = "combine-bot-#{System.unique_integer([:positive])}"

    {:ok, host_reply, _host_socket} =
      UserSocket
      |> socket("user:226", %{})
      |> subscribe_and_join(HermesTrictracWeb.GamesChannel, "games:#{lobby}", %{
        "user" => "nick",
        "variant" => "trictrac_combine",
        "bot" => "trictrac_zero",
        "client_id" => "combine-bot-host"
      })

    assert host_reply.player["color"] == "white"
    assert host_reply.game["bot"]["enabled"] == true
    assert host_reply.game["status"] == "playing"
    assert host_reply.game["pending_match_options"] == nil
    assert host_reply.game["match"]["options"]["aEcrirePartieLength"] == "16"
    assert host_reply.game["match"]["options"]["margotEnabled"] == false
    assert host_reply.game["opening_roll"]["pending"] == true
    assert is_integer(host_reply.game["opening_roll"]["rolls"]["black"])
    assert is_nil(host_reply.game["opening_roll"]["rolls"]["white"])
  end

  test "aecrire bot applies default match options and takes its opening roll" do
    lobby = "aecrire-bot-opening-#{System.unique_integer([:positive])}"
    GameServer.reg(lobby)
    GameServer.start(lobby, "trictrac_aecrire")

    assert {:ok, %{game: game, player: _player}} =
             GameServer.join(lobby, "nick", "aecrire-bot-host", "trictrac_aecrire", %{
               "bot" => "trictrac_zero"
             })

    assert game["status"] == "playing"
    assert game["pending_match_options"] == nil
    assert game["match"]["options"]["aEcrirePartieLength"] == "16"
    assert game["match"]["options"]["margotEnabled"] == false
    assert game["opening_roll"]["pending"] == true
    assert is_integer(game["opening_roll"]["rolls"]["black"])
    assert is_nil(game["opening_roll"]["rolls"]["white"])
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
    assert game["turn"]["color"] == "white"
    assert game["turn"]["number"] == 4
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
        task = Task.async(fn -> GameServer.confirm(lobby, "nick", "tt-bot-visible-host") end)

        assert_receive {:bot_paused_after_roll, serialized_state}
        assert is_list(serialized_state["legal_actions"])

        assert_broadcast "update", %{
          game: %{
            "turn" => %{"color" => "black"},
            "dice" => %{"values" => values}
          }
        }

        assert is_list(values)
        assert values != []

        send(pid, :continue_bot)
        assert {:ok, game} = Task.await(task, 5_000)
        assert game["turn"]["color"] == "black"
        assert game["dice"] != nil
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
