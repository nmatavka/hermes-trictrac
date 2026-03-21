defmodule Dice do
  # Rolls a single die with a result range of 1 to max_value.
  def roll(max_value) do
    Enum.random(1..max_value)
  end

  # Rolls a specified number of dice and returns a list of results.
  def roll_dice(max_value, dice_num) when dice_num > 0 do
    [roll(max_value) | roll_dice(max_value, dice_num - 1)]
  end

  # Base case: When no dice are left to roll, return an empty list.
  def roll_dice(_max_value, 0), do: []
end
