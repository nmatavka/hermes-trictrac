defmodule HermesTrictrac.GaranguetEngineTest do
  use ExUnit.Case, async: false

  alias HermesTrictrac.Rules.{Engine, RaceCore}

  defmodule SequenceDice do
    def roll(count, _opts) do
      key = {__MODULE__, :values}
      values = Process.get(key, [])
      {next, rest} = Enum.split(values, count)

      if length(next) != count do
        raise "not enough queued dice values"
      end

      Process.put(key, rest)
      next
    end
  end

  setup do
    original = Application.get_env(:hermes_trictrac, :dice_impl)
    on_exit(fn -> Application.put_env(:hermes_trictrac, :dice_impl, original) end)
    :ok
  end

  defp ready_engine(lobby) do
    engine = Engine.new(lobby, "garanguet")
    {:ok, engine, _} = Engine.join(engine, "nick", "tab-a")
    {:ok, engine, _} = Engine.join(engine, "jane", "tab-b")
    engine
  end

  defp empty_points do
    Enum.map(0..23, fn _ -> %{white: 0, black: 0} end)
  end

  defp put_point(points, index, point) do
    List.replace_at(points, index, point)
  end

  defp confirmable_engine(engine, board, turn_color \\ :white) do
    dice = %{values: [1], moves: [1], moves_left: [], moves_played: [1]}

    runtime =
      engine.runtime
      |> Map.put(:board, board)
      |> Map.put(:dice, dice)
      |> Map.put(:match, engine.match)

    %{
      engine
      | runtime: runtime,
        board: board,
        dice: dice,
        legal_moves: [],
        history: [],
        turn_color: turn_color,
        turn_number: 1,
        match: runtime.match
    }
  end

  test "garanguet opening roll immediately seeds a fresh three-die turn" do
    Application.put_env(:hermes_trictrac, :dice_impl, SequenceDice)
    Process.put({SequenceDice, :values}, [2, 5, 6, 1, 4])

    engine = ready_engine("garanguet-opening")

    assert {:ok, engine} = Engine.roll(engine, "nick", "tab-a")
    assert get_in(Engine.snapshot(engine), ["opening_roll", "rolls", "white"]) == 2
    assert engine.turn_color == nil

    assert {:ok, engine} = Engine.roll(engine, "jane", "tab-b")

    snapshot = Engine.snapshot(engine)
    assert engine.turn_color == :black
    assert engine.turn_number == 1
    assert snapshot["opening_roll"] == nil
    assert snapshot["dice"]["values"] == [6, 1, 4]
    assert snapshot["dice"]["moves_left"] == [6, 4, 1]
    assert Enum.all?(engine.legal_moves, &(&1.from == 0))
  end

  test "garanguet rerolls tied opening throws and expands a triplet into six plays" do
    Application.put_env(:hermes_trictrac, :dice_impl, SequenceDice)
    Process.put({SequenceDice, :values}, [4, 4, 1, 6, 3, 3, 3])

    engine = ready_engine("garanguet-opening-tie")

    assert {:ok, engine} = Engine.roll(engine, "nick", "tab-a")
    assert {:ok, engine} = Engine.roll(engine, "jane", "tab-b")
    assert engine.turn_color == nil
    assert Engine.snapshot(engine)["opening_roll"]["rolls"] == %{"white" => nil, "black" => nil}

    assert {:ok, engine} = Engine.roll(engine, "nick", "tab-a")
    assert {:ok, engine} = Engine.roll(engine, "jane", "tab-b")

    assert engine.turn_color == :black
    assert engine.dice.values == [3, 3, 3]
    assert engine.dice.moves_left == [3, 3, 3, 3, 3, 3]
  end

  test "garanguet expands simple rolls, exploitable doublets, and triplets correctly" do
    Application.put_env(:hermes_trictrac, :dice_impl, SequenceDice)
    engine = ready_engine("garanguet-expansion")

    Process.put({SequenceDice, :values}, [2, 2, 5])
    {:ok, simple_runtime} = RaceCore.roll(engine.runtime, engine.variant, :white)
    assert simple_runtime.dice.values == [2, 2, 5]
    assert simple_runtime.dice.moves_left == [5, 2, 2]

    Process.put({SequenceDice, :values}, [6, 6, 5])
    {:ok, doublet_runtime} = RaceCore.roll(engine.runtime, engine.variant, :white)
    assert doublet_runtime.dice.values == [6, 6, 5]
    assert doublet_runtime.dice.moves_left == [6, 6, 6, 6, 5]

    Process.put({SequenceDice, :values}, [4, 4, 4])
    {:ok, triplet_runtime} = RaceCore.roll(engine.runtime, engine.variant, :white)
    assert triplet_runtime.dice.values == [4, 4, 4]
    assert triplet_runtime.dice.moves_left == [4, 4, 4, 4, 4, 4]
  end

  test "garanguet favors the strongest playable pips on exploitable doublets" do
    engine = ready_engine("garanguet-force-pips")

    points =
      empty_points()
      |> put_point(23, %{white: 1, black: 0})
      |> put_point(12, %{white: 0, black: 1})

    runtime =
      engine.runtime
      |> Map.put(:board, %{engine.board | points: points, bar: %{white: 0, black: 0}})
      |> Map.put(:dice, %{
        values: [6, 6, 5],
        moves: [6, 6, 6, 6, 5],
        moves_left: [6, 6, 6, 6, 5],
        moves_played: []
      })
      |> put_in([:variant_state, :garanguet_force_mode], :max_pips)

    legal = RaceCore.legal_moves(runtime, engine.variant, :white)

    assert legal != []
    assert Enum.all?(legal, &(&1.die == 6))
    refute Enum.any?(legal, &(&1.die == 5))
  end

  test "garanguet ignores stale bar counts and distinguishes single double and triple wins" do
    engine = ready_engine("garanguet-outcomes")

    stale_bar_points =
      empty_points()
      |> put_point(23, %{white: 1, black: 0})

    stale_bar_runtime =
      engine.runtime
      |> Map.put(:board, %{engine.board | points: stale_bar_points, bar: %{white: 1, black: 0}})
      |> Map.put(:dice, %{values: [1], moves: [1], moves_left: [1], moves_played: []})

    legal = RaceCore.legal_moves(stale_bar_runtime, engine.variant, :white)
    refute Enum.any?(legal, &(&1.from == "bar"))
    assert Enum.any?(legal, &(&1.from == 23 and &1.to == 22 and &1.die == 1))

    single_board = %{
      engine.board
      | points: empty_points() |> put_point(0, %{white: 0, black: 14}),
        outside: %{white: 15, black: 1},
        bar: %{white: 0, black: 0}
    }

    assert {:ok, single_engine} =
             engine
             |> confirmable_engine(single_board)
             |> Engine.confirm("nick", "tab-a")

    assert Engine.snapshot(single_engine)["match"]["winner_kind"] == "single"

    double_board = %{
      engine.board
      | points: empty_points() |> put_point(0, %{white: 0, black: 15}),
        outside: %{white: 15, black: 0},
        bar: %{white: 0, black: 0}
    }

    assert {:ok, double_engine} =
             engine
             |> confirmable_engine(double_board)
             |> Engine.confirm("nick", "tab-a")

    assert Engine.snapshot(double_engine)["match"]["winner_kind"] == "double"

    triple_board = %{
      engine.board
      | points:
          empty_points()
          |> put_point(0, %{white: 0, black: 14})
          |> put_point(20, %{white: 0, black: 1}),
        outside: %{white: 15, black: 0},
        bar: %{white: 0, black: 0}
    }

    assert {:ok, triple_engine} =
             engine
             |> confirmable_engine(triple_board)
             |> Engine.confirm("nick", "tab-a")

    assert Engine.snapshot(triple_engine)["match"]["winner_kind"] == "triple"
  end
end
