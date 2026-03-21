defmodule Backgammon.Rules.Trictrac.Classique.Opening do
  alias Backgammon.Rules.Trictrac.Classique.{Constants, Scoring, State}

  def remember_first_throw(opening, color, dice) do
    cond do
      opening.first_type == nil ->
        %{opening | first_type: color, first_values: dice.values || []}

      true ->
        opening
    end
  end

  def detect_jan_rencontre(events, _color, _dice, %{first_type: nil} = opening), do: {events, opening}

  def detect_jan_rencontre(events, color, dice, opening) do
    events =
      if opening.jan_rencontre_checked or opening.first_type == color do
        events
      else
        if opening.first_values == (dice.values || []) do
          events ++ [Scoring.event(color, "jan de rencontre", if(State.double?(dice), do: 6, else: 4))]
        else
          events
        end
      end

    {events, mark_jan_rencontre(opening, color)}
  end

  def detect_coin_jans(events, start_board, end_board, color, dice, coup_index, depart_done) do
    _start_board = start_board
    talon = if(color == :white, do: 23, else: 0)
    abattues = count_abattues(end_board, color, talon)
    own_coin_cnt = pieces_at(end_board, State.own_coin(color), color)
    opp_coin_cnt = pieces_at(end_board, State.opp_coin(color), State.opposite(color))
    jan_points = if(State.double?(dice), do: 6, else: 4)
    low_die = dice.values |> List.last()

    {events, depart_done} =
      if !depart_done.meseas and abattues == 2 and own_coin_cnt >= 2 and low_die == 1 do
        label = if opp_coin_cnt <= 0, do: "jan de meseas", else: "contre-jan de meseas"
        beneficiary = if opp_coin_cnt <= 0, do: color, else: State.opposite(color)
        {events ++ [Scoring.event(beneficiary, label, jan_points)], %{depart_done | meseas: true}}
      else
        {events, depart_done}
      end

    off_points = off_talon_points(end_board, color, talon)

    {events, depart_done} =
      if !depart_done.two_tables and abattues == 2 and length(off_points) == 2 and
           can_two_tables?(off_points, color, dice) do
        label = if opp_coin_cnt <= 0, do: "jan de deux tables", else: "contre-jan de deux tables"
        beneficiary = if opp_coin_cnt <= 0, do: color, else: State.opposite(color)
        {events ++ [Scoring.event(beneficiary, label, jan_points)], %{depart_done | two_tables: true}}
      else
        {events, depart_done}
      end

    {events, depart_done} =
      if !depart_done.six_tables and !State.double?(dice) and coup_index == 3 and
           all_occupied?(end_board, color, 18, 23) do
        {events ++ [Scoring.event(color, "jan de six tables", 4)], %{depart_done | six_tables: true}}
      else
        {events, depart_done}
      end

    {events, depart_done}
  end

  defp mark_jan_rencontre(%{first_type: nil} = opening, color), do: %{opening | first_type: color}
  defp mark_jan_rencontre(%{first_values: nil} = opening, _color), do: opening

  defp mark_jan_rencontre(opening, color) do
    if opening.first_type != color, do: %{opening | jan_rencontre_checked: true}, else: opening
  end

  defp can_two_tables?(off_points, color, dice) do
    [a, b] = dice.values

    (State.norm_pos(Enum.at(off_points, 0), color) - a == Constants.coin_norm_pos() and
       State.norm_pos(Enum.at(off_points, 1), color) - b == 11) or
      (State.norm_pos(Enum.at(off_points, 0), color) - b == Constants.coin_norm_pos() and
         State.norm_pos(Enum.at(off_points, 1), color) - a == 11)
  end

  defp off_talon_points(board, color, talon) do
    0..23
    |> Enum.flat_map(fn pos ->
      if pos == talon do
        []
      else
        List.duplicate(pos, pieces_at(board, pos, color))
      end
    end)
  end

  defp count_abattues(board, color, talon) do
    Enum.reduce(0..23, 0, fn pos, acc ->
      if pos == talon, do: acc, else: acc + pieces_at(board, pos, color)
    end)
  end

  defp all_occupied?(board, color, from_norm, to_norm) do
    Enum.all?(from_norm..to_norm, fn norm ->
      pieces_at(board, State.denorm_pos(norm, color), color) >= 1
    end)
  end

  defp pieces_at(board, point, color), do: get_in(board, [:points, Access.at(point), color]) || 0
end
