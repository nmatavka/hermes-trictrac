defmodule Backgammon.Rules.Rabattues do
  alias Backgammon.Rules.Dice

  def new do
    piles = %{1 => 2, 2 => 2, 3 => 2, 4 => 3, 5 => 3, 6 => 3}

    %{
      phase: :rabattre,
      phases: %{white: :rabattre, black: :rabattre},
      lever_ready: %{white: false, black: false},
      piles: %{white: piles, black: piles},
      down: %{white: %{}, black: %{}},
      variant_state: %{opening_rolls: %{white: nil, black: nil}},
      board:
        board_from_state(:rabattre, %{white: piles, black: piles}, %{white: %{}, black: %{}}),
      carry_turn: false
    }
  end

  def roll(runtime) do
    values = Dice.roll_two()
    moves_left = if Enum.at(values, 0) == Enum.at(values, 1), do: values, else: values

    runtime
    |> Map.put(:dice, %{
      values: values,
      moves: moves_left,
      moves_left: moves_left,
      moves_played: []
    })
    |> Map.put(:carry_turn, Enum.at(values, 0) == Enum.at(values, 1))
  end

  def play_phase(runtime, color), do: play_phase_for(runtime, color)

  def legal_moves(runtime, color) do
    Enum.flat_map(dice_moves_left(runtime), fn die ->
      case play_phase_for(runtime, color) do
        :rabattre ->
          if get_in(runtime, [:piles, color, die]) > 0 do
            [%{from: pile_point(color, die), to: down_point(color, die), die: die}]
          else
            []
          end

        :lever ->
          if get_in(runtime, [:down, color, die]) > 0 do
            [%{from: down_point(color, die), to: pile_point(color, die), die: die}]
          else
            []
          end

        :done ->
          []
      end
    end)
    |> Enum.uniq_by(fn move -> {move.from, move.to, move.die} end)
  end

  def move(runtime, color, move) do
    legal =
      Enum.find(legal_moves(runtime, color), fn candidate ->
        candidate.from == move["from"] and candidate.to == move["to"]
      end)

    if is_nil(legal) do
      {:error, "Invalid move."}
    else
      current_phase = play_phase_for(runtime, color)

      runtime =
        case current_phase do
          :rabattre ->
            runtime
            |> update_in([:piles, color, legal.die], &max((&1 || 0) - 1, 0))
            |> update_in([:down, color, legal.die], &((&1 || 0) + 1))

          :lever ->
            runtime
            |> update_in([:down, color, legal.die], &max((&1 || 0) - 1, 0))
            |> update_in([:piles, color, legal.die], &((&1 || 0) + 1))
        end
        |> put_in([:dice, :moves_left], remove_first(dice_moves_left(runtime), legal.die))
        |> update_in([:dice, :moves_played], &((&1 || []) ++ [legal.die]))

      next_phase =
        cond do
          current_phase == :rabattre and complete?(runtime.down[color], 15) -> :lever
          current_phase == :lever and complete?(runtime.piles[color], 15) -> :done
          true -> current_phase
        end

      updated =
        runtime
        |> put_phase(color, next_phase)
        |> put_lever_ready(color, next_phase in [:lever, :done])
        |> Map.put(:board, board_from_state(next_phase, runtime.piles, runtime.down))

      {:ok, updated}
    end
  end

  def winner(runtime, color) do
    if play_phase_for(runtime, color) == :done, do: "levered", else: nil
  end

  defp complete?(map, target), do: Enum.reduce(map, 0, fn {_k, v}, acc -> acc + v end) == target
  defp total_count(map), do: Enum.reduce(map, 0, fn {_k, v}, acc -> acc + v end)

  defp board_from_state(_phase, piles, down) do
    base = %{
      points: Enum.map(0..23, fn _ -> %{white: 0, black: 0} end),
      bar: %{white: 0, black: 0},
      outside: %{white: 0, black: 0}
    }

    base
    |> apply_side(:black, piles.black, down.black)
    |> apply_side(:white, piles.white, down.white)
  end

  defp apply_side(board, color, piles, down) do
    Enum.reduce(1..6, board, fn die, acc ->
      acc
      |> put_in([:points, Access.at(pile_point(color, die)), color], Map.get(piles, die, 0))
      |> put_in([:points, Access.at(down_point(color, die)), color], Map.get(down, die, 0))
    end)
  end

  defp pile_point(:black, die), do: die - 1
  defp pile_point(:white, die), do: 24 - die
  defp down_point(:black, die), do: 5 + die
  defp down_point(:white, die), do: 18 - die

  defp lever_ready_for(%{lever_ready: lever_ready}, color) when is_map(lever_ready),
    do: Map.get(lever_ready, color, false)

  defp lever_ready_for(_runtime, _color), do: false

  defp play_phase_for(runtime, color) do
    piles_total = total_count(runtime.piles[color])
    down_total = total_count(runtime.down[color])
    lever_ready = lever_ready_for(runtime, color) or down_total == 15

    cond do
      piles_total == 15 and down_total == 0 and lever_ready ->
        :done

      down_total == 15 ->
        :lever

      lever_ready and down_total > 0 ->
        :lever

      true ->
        :rabattre
    end
  end

  defp put_phase(runtime, color, phase) do
    runtime
    |> Map.put(:phase, phase)
    |> put_in([:phases, color], phase)
  end

  defp put_lever_ready(runtime, color, value) do
    runtime
    |> Map.put_new(:lever_ready, %{white: false, black: false})
    |> put_in([:lever_ready, color], value)
  end

  defp dice_moves_left(runtime), do: get_in(runtime, [:dice, :moves_left]) || []

  defp remove_first([value | rest], value), do: rest
  defp remove_first([head | rest], value), do: [head | remove_first(rest, value)]
  defp remove_first([], _value), do: []
end
