defmodule Backgammon.Rules.DiceTest do
  use ExUnit.Case, async: true

  alias Backgammon.Rules.Dice

  defmodule Deterministic do
    def roll(1, _opts), do: [5]
    def roll(2, _opts), do: [4, 2]
    def roll(3, _opts), do: [6, 3, 1]
  end

  setup do
    original = Application.get_env(:backgammon, :dice_impl)
    on_exit(fn -> Application.put_env(:backgammon, :dice_impl, original) end)
    :ok
  end

  test "crypto roller returns values in range for one two and three dice" do
    Application.delete_env(:backgammon, :dice_impl)

    assert Dice.roll(1) |> Enum.all?(&(&1 in 1..6))
    assert Dice.roll(2) |> Enum.all?(&(&1 in 1..6))
    assert Dice.roll(3) |> Enum.all?(&(&1 in 1..6))

    assert length(Dice.roll(1)) == 1
    assert length(Dice.roll(2)) == 2
    assert length(Dice.roll(3)) == 3
  end

  test "exclude_doubles prevents repeats for two and three dice" do
    Application.delete_env(:backgammon, :dice_impl)

    two = Dice.roll(2, exclude_doubles: true)
    three = Dice.roll(3, exclude_doubles: true)

    assert length(Enum.uniq(two)) == 2
    assert length(Enum.uniq(three)) == 3
  end

  test "exclude_doubles is ignored for a single die" do
    Application.put_env(:backgammon, :dice_impl, Deterministic)
    assert Dice.roll(1, exclude_doubles: true) == [5]
  end

  test "configured implementation can override rolls deterministically" do
    Application.put_env(:backgammon, :dice_impl, Deterministic)

    assert Dice.roll(1) == [5]
    assert Dice.roll(2) == [4, 2]
    assert Dice.roll(3) == [6, 3, 1]
  end
end
