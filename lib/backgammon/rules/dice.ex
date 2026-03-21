defmodule Backgammon.Rules.Dice do
  @moduledoc false

  @default_impl Backgammon.Rules.Dice.CryptoRandom

  def roll(count, opts \\ []) when count in [1, 2, 3] do
    impl().roll(count, opts)
  end

  def roll_one(opts \\ []), do: roll(1, opts)
  def roll_two(opts \\ []), do: roll(2, opts)
  def roll_three(opts \\ []), do: roll(3, opts)

  defp impl do
    case Application.get_env(:backgammon, :dice_impl) do
      impl when is_atom(impl) and not is_nil(impl) ->
        if Code.ensure_loaded?(impl) and function_exported?(impl, :roll, 2), do: impl, else: @default_impl

      _ ->
        @default_impl
    end
  end
end
