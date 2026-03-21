defmodule Backgammon.Rules.Dice.CryptoRandom do
  @moduledoc false

  def roll(count, opts \\ []) when count in [1, 2, 3] do
    exclude_repeats = Keyword.get(opts, :exclude_doubles, false) and count > 1
    do_roll(count, exclude_repeats)
  end

  def roll_single_dice do
    <<rand_byte::integer-size(8)>> = :crypto.strong_rand_bytes(1)

    if rand_byte < 252 do
      rem(rand_byte, 6) + 1
    else
      roll_single_dice()
    end
  end

  defp do_roll(count, false), do: Enum.map(1..count, fn _ -> roll_single_dice() end)

  defp do_roll(count, true) do
    values = do_roll(count, false)

    if Enum.uniq(values) == values do
      values
    else
      do_roll(count, true)
    end
  end
end
