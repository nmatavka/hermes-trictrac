defmodule HermesTrictrac.Training.RaceTrainingBridgeTest do
  use ExUnit.Case, async: true

  alias HermesTrictrac.Training.RaceTrainingBridge
  alias HermesTrictrac.Rules.Engine

  test "creates engine-backed Bräde matches with raw legal checker actions" do
    assert {:ok, response} =
             RaceTrainingBridge.new_game(%{"match_options" => %{"matchLength" => "3"}})

    state = response["state"]
    assert state["phase"] == "move"
    assert state["terminal"] == false
    assert get_in(state, ["runtime", "match", "length"]) == 3
    assert is_binary(state["runtime_term"])

    assert Enum.all?(state["legal_actions"], fn action ->
             action["type"] == "move" and is_integer(action["die"])
           end)
  end

  test "steps and batches through the authoritative engine" do
    {:ok, initial} = RaceTrainingBridge.new_game()
    action = List.first(initial["state"]["legal_actions"])

    assert {:ok, stepped} = RaceTrainingBridge.step(initial["state"], action)
    assert is_number(stepped["reward"])
    assert is_binary(stepped["state"]["runtime_term"])

    assert {:ok, [%{"item_id" => "one", "ok" => true, "result" => batched}]} =
             RaceTrainingBridge.step_batch([
               %{"item_id" => "one", "state" => initial["state"], "action" => action}
             ])

    assert batched == stepped
  end

  test "exposes the weighted 21-outcome dice boundary" do
    assert {:ok, %{"outcomes" => outcomes}} = RaceTrainingBridge.dice_outcomes()
    assert length(outcomes) == 21
    assert_in_delta Enum.sum(Enum.map(outcomes, & &1["weight"])), 1.0, 1.0e-12
    assert Enum.any?(outcomes, &(&1["dice"] == [1, 1] and &1["weight"] == 1.0 / 36.0))
    assert Enum.any?(outcomes, &(&1["dice"] == [1, 2] and &1["weight"] == 2.0 / 36.0))
  end

  test "training-only forced dice still use production legal-move generation" do
    engine = Engine.new("brade-training-test", "brade")
    {:ok, engine, _} = Engine.join(engine, "White", "white")
    {:ok, engine, _} = Engine.join(engine, "Black", "black")
    {:ok, engine} = Engine.submit_match_options(engine, %{"matchLength" => "5"}, "White", "white")
    engine = Engine.force_start_turn(engine, :white)

    assert {:ok, forced} = Engine.roll_for_training(engine, :white, [2, 5])
    assert forced.dice.values == [2, 5]
    assert forced.legal_moves != []
  end

  test "creates Tavli as one engine-owned fixed-order composite match" do
    assert {:ok, response} =
             RaceTrainingBridge.new_game(%{
               "variant_id" => "tavli",
               "match_options" => %{"tavliTarget" => "3"}
             })

    state = response["state"]
    assert state["variant_id"] == "tavli"
    assert state["phase"] == "move"
    assert get_in(state, ["runtime", "variant_state", "tavli_active_leg"]) == "backgammon"
    assert get_in(state, ["runtime", "match", "length"]) == 3
  end

  test "uses the Jacquet diagonal parallel opening without a black-coordinate mirror" do
    assert {:ok, response} = RaceTrainingBridge.new_game(%{"variant_id" => "jacquet"})
    runtime = response["state"]["runtime"]

    assert get_in(runtime, ["board", "points", Access.at(23), "white"]) == 15
    assert get_in(runtime, ["board", "points", Access.at(11), "black"]) == 15

    [opening_action | _] = response["state"]["legal_actions"]
    assert opening_action["from"] in [23, 11]

    assert Enum.all?(response["state"]["legal_actions"], fn action ->
             action["type"] == "move" and action["from"] == opening_action["from"] and
               action["to"] < action["from"]
           end)
  end
end
