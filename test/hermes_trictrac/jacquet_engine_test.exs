defmodule HermesTrictrac.JacquetEngineTest do
  use ExUnit.Case, async: false

  alias HermesTrictrac.Rules.Engine

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
    engine = Engine.new(lobby, "jacquet")
    {:ok, engine, _} = Engine.join(engine, "nick", "tab-a")
    {:ok, engine, _} = Engine.join(engine, "jane", "tab-b")
    engine
  end

  test "jacquet opening roll only decides the starter and still requires a fresh turn roll" do
    Application.put_env(:hermes_trictrac, :dice_impl, SequenceDice)
    Process.put({SequenceDice, :values}, [2, 5, 6, 1])

    engine = ready_engine("jacquet-opening")

    assert Engine.snapshot(engine)["opening_roll"]["rolls"] == %{"white" => nil, "black" => nil}

    assert {:ok, engine} = Engine.roll(engine, "nick", "tab-a")
    assert get_in(Engine.snapshot(engine), ["opening_roll", "rolls", "white"]) == 2
    assert engine.turn_color == nil

    assert {:ok, engine} = Engine.roll(engine, "jane", "tab-b")
    assert engine.turn_color == :black
    assert engine.turn_number == 1
    assert engine.dice == nil
    assert engine.legal_moves == []
    assert Engine.snapshot(engine)["opening_roll"] == nil

    assert {:ok, engine} = Engine.roll(engine, "jane", "tab-b")
    assert engine.dice.values == [6, 1]
    assert engine.dice.moves_left == [6, 1]
    assert Enum.all?(engine.legal_moves, &(&1.from == 0))
  end

  test "jacquet rerolls tied opening throws until a starter is found" do
    Application.put_env(:hermes_trictrac, :dice_impl, SequenceDice)
    Process.put({SequenceDice, :values}, [4, 4, 1, 6])

    engine = ready_engine("jacquet-opening-tie")

    assert {:ok, engine} = Engine.roll(engine, "nick", "tab-a")
    assert {:ok, engine} = Engine.roll(engine, "jane", "tab-b")
    assert engine.turn_color == nil
    assert engine.turn_number == 0
    assert Engine.snapshot(engine)["opening_roll"]["rolls"] == %{"white" => nil, "black" => nil}

    assert {:ok, engine} = Engine.roll(engine, "nick", "tab-a")
    assert {:ok, engine} = Engine.roll(engine, "jane", "tab-b")
    assert engine.turn_color == :black
    assert engine.dice == nil
    assert engine.legal_moves == []
  end
end
