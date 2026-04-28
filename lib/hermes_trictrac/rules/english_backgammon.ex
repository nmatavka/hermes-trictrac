defmodule HermesTrictrac.Rules.EnglishBackgammon do
  @moduledoc false

  def legal_moves(runtime, variant, color, raw_fun, apply_fun) do
    moves_left = if runtime.dice, do: runtime.dice.moves_left, else: []

    raw_fun.(runtime.board, variant, color, moves_left)
    |> filter_forced_usage(runtime.board, variant, color, moves_left, apply_fun)
  end

  def bear_off_allowed?(route, route_index, die, occupied?) do
    current_point = Enum.at(route, route_index)
    home_zone = Enum.take(route, -6)
    furthest_point = Enum.find(home_zone, occupied?)
    distance = length(route) - route_index

    cond do
      is_nil(furthest_point) ->
        false

      distance == die ->
        true

      distance < die ->
        current_point == furthest_point

      true ->
        false
    end
  end

  def landing_allowed(
        _board,
        color,
        source,
        source_count,
        destination,
        pieces_at_fun,
        move_count_fun
      ) do
    opp_count = pieces_at_fun.(destination, opposite(color))

    cond do
      opp_count >= 2 ->
        :error

      opp_count == 1 ->
        with {:ok, count} <- move_count_fun.(source, source_count, destination) do
          {:ok, true, count}
        end

      true ->
        with {:ok, count} <- move_count_fun.(source, source_count, destination) do
          {:ok, false, count}
        end
    end
  end

  defp filter_forced_usage(moves, _board, _variant, _color, _moves_left, _apply_fun)
       when moves == [], do: []

  defp filter_forced_usage(moves, board, variant, color, moves_left, apply_fun) do
    branches = enumerate_branches(board, variant, color, moves_left, apply_fun)
    max_played = Enum.max_by(branches, & &1.played, fn -> %{played: 0} end).played

    moves =
      Enum.filter(moves, fn move ->
        used = Map.get(move, :dice_used, [move.die])
        next_board = apply_fun.(board, variant, color, move)
        remaining = remove_all_used(moves_left, used)
        next_branches = enumerate_branches(next_board, variant, color, remaining, apply_fun)

        total_played =
          length(used) +
            Enum.max_by(next_branches, & &1.played, fn -> %{played: 0} end).played

        total_played == max_played
      end)

    if max_played == 1 do
      highest_die = moves |> Enum.map(& &1.die) |> Enum.max(fn -> nil end)
      Enum.filter(moves, &(&1.die == highest_die))
    else
      moves
    end
  end

  defp enumerate_branches(board, variant, color, moves_left, apply_fun, played \\ 0) do
    moves =
      HermesTrictrac.Rules.RaceCore.raw_generic_legal_moves(board, variant, color, moves_left)

    cond do
      moves_left == [] ->
        [%{played: played}]

      moves == [] ->
        [%{played: played}]

      true ->
        Enum.flat_map(moves, fn move ->
          used = Map.get(move, :dice_used, [move.die])
          next_board = apply_fun.(board, variant, color, move)
          remaining = remove_all_used(moves_left, used)

          enumerate_branches(
            next_board,
            variant,
            color,
            remaining,
            apply_fun,
            played + length(used)
          )
        end)
    end
  end

  defp remove_first([value | rest], value), do: rest
  defp remove_first([head | rest], value), do: [head | remove_first(rest, value)]
  defp remove_first([], _value), do: []

  defp remove_all_used(values, used) do
    Enum.reduce(used, values, fn die, acc -> remove_first(acc, die) end)
  end

  defp opposite(:white), do: :black
  defp opposite(:black), do: :white
end
