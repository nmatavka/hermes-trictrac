defmodule HermesTrictrac.Training.TrictracBridgeTest do
  use ExUnit.Case, async: false

  alias HermesTrictrac.Rules.Registry
  alias HermesTrictrac.Rules.Trictrac.Classique
  alias HermesTrictrac.Rules.Trictrac.Classique.Branches
  alias HermesTrictrac.Rules.Trictrac.Classique.Events
  alias HermesTrictrac.Rules.TrictracCore
  alias HermesTrictrac.Training.TrictracBridge

  test "new_game starts directly in roll phase with a fixed legal action set" do
    assert {:ok, response} = TrictracBridge.new_game()

    assert response["phase"] == nil
    assert response["terminal"] == false
    assert response["white_to_play"]
    assert response["legal_actions"] == [%{"type" => "special", "id" => "ROLL"}]

    state = response["state"]
    assert state["phase"] == "roll"
    assert state["legal_actions"] == [%{"type" => "special", "id" => "ROLL"}]
    assert get_in(state, ["runtime", "match", "options", "margotEnabled"]) == false
    assert get_in(state, ["runtime", "match", "variant_id"]) == "trictrac_classique"
    assert get_in(state, ["runtime", "tactical_tariffs", "enabled"]) == true
    assert get_in(state, ["runtime", "tactical_tariffs", "horizon_own_turns"]) == 3
    assert is_number(get_in(state, ["runtime", "tactical_tariffs", "white", "h1"]))
    assert is_number(get_in(state, ["runtime", "tactical_tariffs", "white", "h2"]))
    assert is_number(get_in(state, ["runtime", "tactical_tariffs", "white", "h3"]))
    assert is_number(get_in(state, ["runtime", "tactical_tariffs", "black", "h1"]))
    assert is_number(get_in(state, ["runtime", "tactical_tariffs", "black", "h2"]))
    assert is_number(get_in(state, ["runtime", "tactical_tariffs", "black", "h3"]))
  end

  test "new_game accepts a configured trictrac variant and match options" do
    assert {:ok, response} =
             TrictracBridge.new_game(%{
               "variant_id" => "toccategli",
               "match_options" => %{"margotEnabled" => true}
             })

    state = response["state"]
    assert state["phase"] == "roll"
    assert get_in(state, ["runtime", "match", "variant_id"]) == "toccategli"
    assert get_in(state, ["runtime", "match", "options", "margotEnabled"]) == true
  end

  test "new_game accepts toc options and preserves them in public state" do
    assert {:ok, response} =
             TrictracBridge.new_game(%{
               "variant_id" => "toc",
               "match_options" => %{
                 "holeTarget" => "7",
                 "doublesMode" => "off",
                 "margotEnabled" => true
               }
             })

    state = response["state"]
    assert state["phase"] == "roll"
    assert get_in(state, ["runtime", "match", "variant_id"]) == "toc"
    assert get_in(state, ["runtime", "match", "length"]) == 7
    assert get_in(state, ["runtime", "match", "options", "holeTarget"]) == "7"
    assert get_in(state, ["runtime", "match", "options", "doublesMode"]) == "off"
    assert get_in(state, ["runtime", "match", "options", "margotEnabled"]) == true
  end

  test "confirm is not legal while checker moves remain" do
    config = %{"tactical_config" => %{"enabled" => false}}
    {:ok, initial} = TrictracBridge.new_game(config)
    {:ok, rolled} = TrictracBridge.step(initial["state"], %{"type" => "special", "id" => "ROLL"}, config)

    actions = rolled["state"]["legal_actions"]

    assert Enum.any?(actions, &(&1["type"] == "move"))
    refute Enum.any?(actions, &(&1["type"] == "special" and &1["id"] == "CONFIRM"))

    assert {:error, "Turn obligations not fulfilled."} =
             TrictracBridge.step(rolled["state"], %{"type" => "special", "id" => "CONFIRM"}, config)
  end

  test "bridge step matches direct trictrac core transitions across a full sampled turn" do
    variant = Registry.fetch!("trictrac_classique")
    config = %{"tactical_config" => %{"enabled" => false}}
    {:ok, initial} = TrictracBridge.new_game(config)
    {:ok, rolled} = TrictracBridge.step(initial["state"], %{"type" => "special", "id" => "ROLL"}, config)

    runtime = TrictracBridge.decode_runtime_term(rolled["state"]["runtime_term"])
    color = runtime.turn_color

    assert {:ok, actions, direct_confirmed} = find_confirmable_turn(runtime, variant, color, [])

    {bridge_state, direct_runtime} =
      Enum.reduce(actions, {rolled["state"], runtime}, fn action,
                                                          {bridge_state, direct_runtime} ->
        {:ok, bridged} = TrictracBridge.step(bridge_state, action, config)

        {:ok, advanced} =
          TrictracCore.move(direct_runtime, variant, color, bridge_move_payload(action))

        assert bridged["state"]["runtime"] == TrictracBridge.public_runtime(advanced, config)
        assert bridged["reward"] == 0.0

        {bridged["state"], advanced}
      end)

    {:ok, confirmed} =
      TrictracBridge.step(bridge_state, %{"type" => "special", "id" => "CONFIRM"}, config)

    {:ok, direct_after_confirm} = TrictracCore.confirm(direct_runtime, variant, color)

    assert direct_after_confirm == direct_confirmed
    assert confirmed["state"]["runtime"] == TrictracBridge.public_runtime(direct_after_confirm, config)
    assert confirmed["reward"] == trous_reward(direct_runtime, direct_after_confirm)

    if confirmed["state"]["phase"] == "decision" do
      decision_action = List.first(confirmed["state"]["legal_actions"])
      {:ok, decided} = TrictracBridge.step(confirmed["state"], decision_action, config)

      {:ok, direct_after_decision} =
        TrictracCore.submit_turn_decision(
          direct_after_confirm,
          variant,
          direct_after_confirm.turn_color,
          decision_choice(decision_action)
        )

      assert decided["state"]["runtime"] ==
               TrictracBridge.public_runtime(direct_after_decision, config)
    end
  end

  test "step_batch preserves input order and matches duplicated sequential step results" do
    config = %{"tactical_config" => %{"enabled" => false}}
    {:ok, initial} = TrictracBridge.new_game(config)
    {:ok, rolled} = TrictracBridge.step(initial["state"], %{"type" => "special", "id" => "ROLL"}, config)
    action = List.first(rolled["state"]["legal_actions"])

    batch = [
      %{
        "item_id" => "first",
        "state" => rolled["state"],
        "action" => action,
        "config" => config
      },
      %{
        "item_id" => "second",
        "state" => rolled["state"],
        "action" => action,
        "config" => config
      }
    ]

    {:ok, [%{"ok" => true, "result" => first}, %{"ok" => true, "result" => second}]} =
      TrictracBridge.step_batch(batch)

    {:ok, sequential} = TrictracBridge.step(rolled["state"], action, config)

    assert first == sequential
    assert second == sequential
  end

  test "step_batch singleton matches direct step result" do
    config = %{"tactical_config" => %{"enabled" => false}}
    {:ok, initial} = TrictracBridge.new_game(config)
    {:ok, rolled} = TrictracBridge.step(initial["state"], %{"type" => "special", "id" => "ROLL"}, config)
    action = List.first(rolled["state"]["legal_actions"])

    {:ok, direct} = TrictracBridge.step(rolled["state"], action, config)

    {:ok, [%{"ok" => true, "result" => batched}]} =
      TrictracBridge.step_batch([
        %{
          "item_id" => "only",
          "state" => rolled["state"],
          "action" => action,
          "config" => config
        }
      ])

    assert batched == direct
  end

  test "concurrent daemon table initialization is race-safe" do
    delete_bridge_tables()

    tasks =
      1..32
      |> Task.async_stream(
        fn _ ->
          assert :ok = TrictracBridge.ensure_daemon_tables()
          assert {:ok, _stats} = TrictracBridge.stats()
          assert {:ok, _response} = TrictracBridge.new_game(%{"tactical_config" => %{"enabled" => false}})
        end,
        ordered: false,
        max_concurrency: 32,
        timeout: 15_000
      )
      |> Enum.to_list()

    assert Enum.all?(tasks, &match?({:ok, _}, &1))
  end

  test "invalid runtime terms are rejected consistently across state and step paths" do
    bad_state = %{"runtime_term" => "not-base64"}
    roll = %{"type" => "special", "id" => "ROLL"}

    assert {:error, "Invalid state payload."} = TrictracBridge.state(bad_state)
    assert {:error, "Invalid state payload."} = TrictracBridge.step(bad_state, roll)

    assert {:ok, [%{"ok" => false, "error" => "Invalid state payload."}]} =
             TrictracBridge.step_batch([
               %{
                 "item_id" => "bad",
                 "state" => bad_state,
                 "action" => roll,
                 "config" => %{}
               }
             ])
  end

  test "serialized state is deterministic across repeated round-trips" do
    {:ok, initial} = TrictracBridge.new_game()
    runtime = TrictracBridge.decode_runtime_term(initial["state"]["runtime_term"])

    assert TrictracBridge.serialize_state(runtime) == TrictracBridge.serialize_state(runtime)
  end

  test "state can omit tactical payload for transient forced-chain responses" do
    {:ok, initial} = TrictracBridge.new_game()

    {:ok, cheap} =
      TrictracBridge.state(initial["state"], %{
        "include_tactical_summary" => false
      })

    refute get_in(cheap, ["state", "runtime", "tactical_tariffs"])

    {:ok, hydrated} = TrictracBridge.state(cheap["state"])

    assert_tactical_shape(get_in(hydrated, ["state", "runtime", "tactical_tariffs"]))
  end

  test "classique roll, move, and decision phases emit tactical h1/h2/h3 payloads" do
    {:ok, initial} = TrictracBridge.new_game()
    roll_runtime = TrictracBridge.decode_runtime_term(initial["state"]["runtime_term"])
    roll_state = TrictracBridge.serialize_state(roll_runtime)

    assert_tactical_shape(roll_state["runtime"]["tactical_tariffs"])

    move_runtime = simple_classique_move_runtime()
    move_state = TrictracBridge.serialize_state(move_runtime)

    assert move_state["phase"] == "move"
    assert_tactical_shape(move_state["runtime"]["tactical_tariffs"])

    decision_runtime =
      roll_runtime
      |> Map.put(:pending_turn_decision, %{
        "key" => "reprise",
        "prompt" => "Synthetic reprise",
        "choices" => ["tenir", "s'en aller"],
        "actorColor" => "white"
      })
      |> put_in([:trictrac, :turn_event_queue], [])

    decision_state = TrictracBridge.serialize_state(decision_runtime)

    assert decision_state["phase"] == "decision"
    assert_tactical_shape(decision_state["runtime"]["tactical_tariffs"])
  end

  test "classique horizon-1 roll phase keeps h1 at zero until dice are known" do
    {:ok, initial} =
      TrictracBridge.new_game(%{
        "tactical_config" => %{
          "enabled" => true,
          "horizon_own_turns" => 1,
          "reward_weight" => 1.0,
          "heuristic_weight" => 1.0,
          "version" => "classique-tactical-v3"
        }
      })

    tactical = get_in(initial, ["state", "runtime", "tactical_tariffs"])

    assert tactical["horizon_own_turns"] == 1
    assert get_in(tactical, ["white", "h1"]) == 0.0
    assert get_in(tactical, ["black", "h1"]) == 0.0
  end

  test "classique move-phase tactical payload is stable across equivalent dice ordering" do
    runtime_a = simple_classique_move_runtime()

    runtime_b =
      runtime_a
      |> Map.put(:dice, %{values: [1, 2], moves: [1, 2], moves_left: [2, 1], moves_played: []})
      |> Map.put(:legal_moves, [])
      |> then(fn runtime ->
        variant = Registry.fetch!("trictrac_classique")
        Map.put(runtime, :legal_moves, Classique.legal_moves(runtime, variant, :white))
      end)

    tactical_a =
      runtime_a
      |> TrictracBridge.serialize_state()
      |> get_in(["runtime", "tactical_tariffs"])

    tactical_b =
      runtime_b
      |> TrictracBridge.serialize_state()
      |> get_in(["runtime", "tactical_tariffs"])

    assert tactical_a == tactical_b
  end

  test "classique move-phase runtime_term is stable across equivalent dice and legal-move ordering" do
    runtime_a = simple_classique_move_runtime()

    runtime_b =
      runtime_a
      |> Map.put(:dice, %{values: [1, 2], moves: [1, 2], moves_left: [2, 1], moves_played: []})
      |> Map.put(:legal_moves, Enum.reverse(runtime_a.legal_moves))

    state_a = TrictracBridge.serialize_state(runtime_a)
    state_b = TrictracBridge.serialize_state(runtime_b)

    assert state_a["runtime_term"] == state_b["runtime_term"]
  end

  test "classique tactical scoring rules distinguish single and double remplissage tariffs" do
    {single_start, single_end, single_dice} = single_remplissage_setup()
    {double_start, double_end, double_dice} = double_remplissage_setup()

    single_value =
      turn_event_points(single_start, single_end, single_dice, %{"margotEnabled" => false}) / 144.0

    double_value =
      turn_event_points(double_start, double_end, double_dice, %{"margotEnabled" => false}) / 144.0

    margot_value =
      turn_event_points(single_start, single_end, single_dice, %{"margotEnabled" => true}) / 144.0

    assert_in_delta single_value, 4.0 / 144.0, 1.0e-6
    assert_in_delta double_value, 12.0 / 144.0, 1.0e-6
    assert_in_delta margot_value, 4.0 / 144.0, 1.0e-6
  end

  test "turn event detection matches when branch analysis is precomputed" do
    {start_board, end_board, dice} = single_remplissage_setup()
    variant = Registry.fetch!("trictrac_classique")

    trictrac =
      %{}
      |> Classique.apply_options(%{"margotEnabled" => false})
      |> Classique.begin_turn(start_board, variant, :white, dice)

    branches_info = Branches.best_end_branches(start_board, variant, :white, dice)

    direct =
      Events.detect_turn_events(start_board, end_board, variant, :white, dice, trictrac)

    reused =
      Events.detect_turn_events(start_board, end_board, variant, :white, dice, trictrac,
        branches_info: branches_info
      )

    assert reused == direct
  end

  test "non classique bridge state does not emit tactical tariffs" do
    assert {:ok, response} = TrictracBridge.new_game(%{"variant_id" => "toccategli"})
    refute Map.has_key?(response["state"]["runtime"], "tactical_tariffs")
  end

  defp find_confirmable_turn(runtime, variant, color, actions) do
    case TrictracCore.confirm(runtime, variant, color) do
      {:ok, confirmed} ->
        {:ok, Enum.reverse(actions), confirmed}

      {:error, _reason} ->
        runtime.legal_moves
        |> Enum.find_value({:error, :unconfirmable}, fn move ->
          action = %{
            "type" => "move",
            "from" => move.from,
            "to" => move.to,
            "sequence" => Map.get(move, :sequence)
          }

          case TrictracCore.move(runtime, variant, color, bridge_move_payload(action)) do
            {:ok, next_runtime} ->
              find_confirmable_turn(next_runtime, variant, color, [action | actions])

            {:error, _reason} ->
              nil
          end
        end)
    end
  end

  defp bridge_move_payload(%{"type" => "move"} = action) do
    payload = %{"from" => action["from"], "to" => action["to"]}

    case action["sequence"] do
      sequence when is_list(sequence) -> Map.put(payload, "sequence", sequence)
      _ -> payload
    end
  end

  defp decision_choice(%{"id" => "DECISION_TENIR"}), do: "tenir"
  defp decision_choice(%{"id" => "DECISION_SEN_ALLER"}), do: "s'en aller"
  defp decision_choice(%{"id" => "DECISION_SUSPEND_CLASSIQUE"}), do: "suspend_classique"
  defp decision_choice(%{"id" => "DECISION_SUSPEND_A_ECRIRE"}), do: "suspend_a_ecrire"
  defp decision_choice(%{"id" => "DECISION_NONE"}), do: "none"

  defp delete_bridge_tables do
    case Process.whereis(:trictrac_bridge_table_owner) do
      nil ->
        :ok

      pid ->
        Process.exit(pid, :kill)
        wait_until(fn -> Process.whereis(:trictrac_bridge_table_owner) == nil end)
    end

    Enum.each(
      [
        :trictrac_bridge_step_cache,
        :trictrac_bridge_tactical_cache,
        :trictrac_bridge_current_turn_leaf_cache,
        :trictrac_bridge_stats
      ],
      fn table ->
        case :ets.whereis(table) do
          :undefined -> :ok
          tid -> :ets.delete(tid)
        end
      end
    )
  end

  defp wait_until(fun, attempts \\ 100)

  defp wait_until(_fun, 0), do: :ok

  defp wait_until(fun, attempts) do
    if fun.() do
      :ok
    else
      Process.sleep(1)
      wait_until(fun, attempts - 1)
    end
  end

  defp trous_reward(before_runtime, after_runtime) do
    white_before = get_in(before_runtime, [:trictrac, :score, Access.at(0), :trous]) || 0
    white_after = get_in(after_runtime, [:trictrac, :score, Access.at(0), :trous]) || 0
    black_before = get_in(before_runtime, [:trictrac, :score, Access.at(1), :trous]) || 0
    black_after = get_in(after_runtime, [:trictrac, :score, Access.at(1), :trous]) || 0
    (white_after - white_before - (black_after - black_before)) * 1.0
  end

  defp turn_event_points(start_board, end_board, dice, match_options) do
    variant = Registry.fetch!("trictrac_classique")

    trictrac =
      %{}
      |> Classique.apply_options(match_options)
      |> Classique.begin_turn(start_board, variant, :white, dice)

    start_board
    |> Events.detect_turn_events(end_board, variant, :white, dice, trictrac)
    |> Map.get(:events, [])
    |> Enum.reduce(0, fn event, total -> total + event.points end)
  end

  defp single_remplissage_setup do
    {
      board_from_points(fn index ->
        cond do
          index in 12..16 -> %{white: 2, black: 0}
          index == 17 -> %{white: 1, black: 0}
          index == 18 -> %{white: 2, black: 0}
          true -> %{white: 0, black: 0}
        end
      end),
      board_from_points(fn index ->
        cond do
          index in 12..18 -> %{white: 2, black: 0}
          true -> %{white: 0, black: 0}
        end
      end),
      %{values: [2, 1], moves: [2, 1], moves_left: [], moves_played: [1]}
    }
  end

  defp classique_move_runtime(board, dice, match_options \\ %{"margotEnabled" => false}) do
    variant = Registry.fetch!("trictrac_classique")
    {:ok, initial} = TrictracBridge.new_game(%{"match_options" => match_options})
    runtime = TrictracBridge.decode_runtime_term(initial["state"]["runtime_term"])

    runtime =
      runtime
      |> Map.put(:board, board)
      |> Map.put(:turn_color, :white)
      |> Map.put(:turn_number, 7)
      |> Map.put(:dice, dice)
      |> Map.put(:pending_turn_decision, nil)
      |> Map.put(:history, [])

    trictrac =
      runtime.trictrac
      |> Classique.apply_options(match_options)
      |> Classique.begin_turn(board, variant, :white, dice)

    runtime = %{runtime | trictrac: trictrac}
    Map.put(runtime, :legal_moves, Classique.legal_moves(runtime, variant, :white))
  end

  defp simple_classique_move_runtime do
    {:ok, initial} = TrictracBridge.new_game()
    runtime = HermesTrictrac.Training.TrictracBridge.decode_runtime_term(initial["state"]["runtime_term"])
    dice = %{values: [1, 2], moves: [1, 2], moves_left: [1, 2], moves_played: []}
    classique_move_runtime(runtime.board, dice)
  end

  defp assert_tactical_shape(tactical_tariffs) do
    assert tactical_tariffs["enabled"] == true
    assert tactical_tariffs["horizon_own_turns"] == 3

    for color <- ["white", "black"], field <- ["h1", "h2", "h3"] do
      assert is_number(get_in(tactical_tariffs, [color, field]))
    end
  end

  defp double_remplissage_setup do
    {
      board_from_points(fn index ->
        cond do
          index in 12..16 -> %{white: 2, black: 0}
          index == 17 -> %{white: 1, black: 0}
          index in 18..20 -> %{white: 1, black: 0}
          true -> %{white: 0, black: 0}
        end
      end),
      board_from_points(fn index ->
        cond do
          index in 12..17 -> %{white: 2, black: 0}
          index in 19..20 -> %{white: 1, black: 0}
          true -> %{white: 0, black: 0}
        end
      end),
      %{values: [1, 1, 1, 1], moves: [1, 1, 1, 1], moves_left: [], moves_played: [1]}
    }
  end

  defp board_from_points(fun) do
    Enum.reduce(0..23, empty_board(), fn index, acc -> put_point(acc, index, fun.(index)) end)
  end

  defp empty_board do
    %{
      points: Enum.map(1..24, fn _ -> %{white: 0, black: 0} end),
      bar: %{white: 0, black: 0},
      outside: %{white: 0, black: 0}
    }
  end

  defp put_point(board, index, point) do
    board
    |> put_in([:points, Access.at(index), :white], point.white)
    |> put_in([:points, Access.at(index), :black], point.black)
  end
end
