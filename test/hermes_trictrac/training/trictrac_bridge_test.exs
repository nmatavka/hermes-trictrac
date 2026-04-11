defmodule HermesTrictrac.Training.TrictracBridgeTest do
  use ExUnit.Case, async: true

  alias HermesTrictrac.Rules.Registry
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
    {:ok, initial} = TrictracBridge.new_game()
    {:ok, rolled} = TrictracBridge.step(initial["state"], %{"type" => "special", "id" => "ROLL"})

    actions = rolled["state"]["legal_actions"]

    assert Enum.any?(actions, &(&1["type"] == "move"))
    refute Enum.any?(actions, &(&1["type"] == "special" and &1["id"] == "CONFIRM"))

    assert {:error, "Turn obligations not fulfilled."} =
             TrictracBridge.step(rolled["state"], %{"type" => "special", "id" => "CONFIRM"})
  end

  test "bridge step matches direct trictrac core transitions across a full sampled turn" do
    variant = Registry.fetch!("trictrac_classique")
    {:ok, initial} = TrictracBridge.new_game()
    {:ok, rolled} = TrictracBridge.step(initial["state"], %{"type" => "special", "id" => "ROLL"})

    runtime = TrictracBridge.decode_runtime_term(rolled["state"]["runtime_term"])
    color = runtime.turn_color

    assert {:ok, actions, direct_confirmed} = find_confirmable_turn(runtime, variant, color, [])

    {bridge_state, direct_runtime} =
      Enum.reduce(actions, {rolled["state"], runtime}, fn action,
                                                          {bridge_state, direct_runtime} ->
        {:ok, bridged} = TrictracBridge.step(bridge_state, action)

        {:ok, advanced} =
          TrictracCore.move(direct_runtime, variant, color, bridge_move_payload(action))

        assert bridged["state"]["runtime"] == TrictracBridge.public_runtime(advanced)
        assert bridged["reward"] == 0.0

        {bridged["state"], advanced}
      end)

    {:ok, confirmed} =
      TrictracBridge.step(bridge_state, %{"type" => "special", "id" => "CONFIRM"})

    {:ok, direct_after_confirm} = TrictracCore.confirm(direct_runtime, variant, color)

    assert direct_after_confirm == direct_confirmed
    assert confirmed["state"]["runtime"] == TrictracBridge.public_runtime(direct_after_confirm)
    assert confirmed["reward"] == trous_reward(direct_runtime, direct_after_confirm)

    if confirmed["state"]["phase"] == "decision" do
      decision_action = List.first(confirmed["state"]["legal_actions"])
      {:ok, decided} = TrictracBridge.step(confirmed["state"], decision_action)

      {:ok, direct_after_decision} =
        TrictracCore.submit_turn_decision(
          direct_after_confirm,
          variant,
          direct_after_confirm.turn_color,
          decision_choice(decision_action)
        )

      assert decided["state"]["runtime"] == TrictracBridge.public_runtime(direct_after_decision)
    end
  end

  test "serialized state is deterministic across repeated round-trips" do
    {:ok, initial} = TrictracBridge.new_game()
    runtime = TrictracBridge.decode_runtime_term(initial["state"]["runtime_term"])

    assert TrictracBridge.serialize_state(runtime) == TrictracBridge.serialize_state(runtime)
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

  defp trous_reward(before_runtime, after_runtime) do
    white_before = get_in(before_runtime, [:trictrac, :score, Access.at(0), :trous]) || 0
    white_after = get_in(after_runtime, [:trictrac, :score, Access.at(0), :trous]) || 0
    black_before = get_in(before_runtime, [:trictrac, :score, Access.at(1), :trous]) || 0
    black_after = get_in(after_runtime, [:trictrac, :score, Access.at(1), :trous]) || 0
    (white_after - white_before - (black_after - black_before)) * 1.0
  end
end
