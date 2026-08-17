defmodule HermesTrictrac.Rules.Trictrac.Classique.Opening do
  alias HermesTrictrac.Rules.Trictrac.Classique.{Constants, Scoring, State}
  alias HermesTrictrac.Rules.Trictrac.VariantRules

  def remember_first_throw(opening, color, dice) do
    cond do
      opening.first_type == nil ->
        %{opening | first_type: color, first_values: State.normalized_throw(dice)}

      true ->
        opening
    end
  end

  def detect_jan_rencontre(events, color, dice, opening, variant \\ %{id: "trictrac_classique"})

  def detect_jan_rencontre(events, _color, _dice, %{first_type: nil} = opening, _variant),
    do: {events, opening}

  def detect_jan_rencontre(events, color, dice, opening, variant) do
    events =
      if opening.jan_rencontre_checked or opening.first_type == color do
        events
      else
        jan_points = VariantRules.jan_rencontre_points(variant, State.double?(dice))

        if opening.first_values == State.normalized_throw(dice) and jan_points > 0 do
          events ++ [Scoring.event(color, :jan_rencontre, jan_points)]
        else
          events
        end
      end

    {events, mark_jan_rencontre(opening, color)}
  end

  def detect_coin_jans(
        events,
        _start_board,
        end_board,
        color,
        dice,
        coup_index,
        depart_done,
        variant \\ %{id: "trictrac_classique"},
        branches_info \\ nil,
        double_seen? \\ false
      ) do
    candidate_boards = candidate_boards(end_board, branches_info)
    talon = if(color == :white, do: 23, else: 0)
    jan_points = VariantRules.coin_jan_points(variant, State.double?(dice))
    low_die = State.dice_values(dice) |> Enum.min(fn -> nil end)

    {events, depart_done} =
      if !depart_done.meseas and low_die == 1 and jan_points > 0 and
           Enum.any?(candidate_boards, &meseas_ready?(&1, color, talon)) do
        opponent_present? =
          Enum.any?(candidate_boards, fn board ->
            meseas_ready?(board, color, talon) and
              pieces_at(board, State.opp_coin(color), State.opposite(color)) > 0
          end)

        rule = if opponent_present?, do: :contre_jan_de_meseas, else: :jan_de_meseas
        beneficiary = if opponent_present?, do: State.opposite(color), else: color
        {events ++ [Scoring.event(beneficiary, rule, jan_points)], %{depart_done | meseas: true}}
      else
        {events, depart_done}
      end

    {events, depart_done} =
      if !depart_done.two_tables and jan_points > 0 and
           Enum.any?(candidate_boards, &two_tables_ready?(&1, color, talon, dice)) do
        opponent_present? =
          Enum.any?(candidate_boards, fn board ->
            two_tables_ready?(board, color, talon, dice) and
              pieces_at(board, State.opp_coin(color), State.opposite(color)) > 0
          end)

        rule = if opponent_present?, do: :contre_jan_de_deux_tables, else: :jan_de_deux_tables
        beneficiary = if opponent_present?, do: State.opposite(color), else: color

        {events ++ [Scoring.event(beneficiary, rule, jan_points)],
         %{depart_done | two_tables: true}}
      else
        {events, depart_done}
      end

    six_tables_points = VariantRules.six_tables_points(variant)

    {events, depart_done} =
      if !depart_done.six_tables and !(double_seen? or State.double?(dice)) and coup_index == 3 and
           Enum.any?(candidate_boards, &all_occupied?(&1, color, 17, 22)) and
           six_tables_points > 0 do
        {events ++ [Scoring.event(color, :jan_de_six_tables, six_tables_points)],
         %{depart_done | six_tables: true}}
      else
        {events, depart_done}
      end

    {events, depart_done}
  end

  defp candidate_boards(_end_board, %{branches: branches}) when is_list(branches), do: branches
  defp candidate_boards(end_board, _branches_info), do: [end_board]

  defp meseas_ready?(board, color, talon) do
    count_abattues(board, color, talon) == 2 and
      pieces_at(board, State.own_coin(color), color) >= 2
  end

  defp two_tables_ready?(board, color, talon, dice) do
    off_points = off_talon_points(board, color, talon)

    count_abattues(board, color, talon) == 2 and length(off_points) == 2 and
      can_two_tables?(off_points, color, dice)
  end

  defp mark_jan_rencontre(%{first_type: nil} = opening, color), do: %{opening | first_type: color}
  defp mark_jan_rencontre(%{first_values: nil} = opening, _color), do: opening

  defp mark_jan_rencontre(opening, color) do
    if opening.first_type != color, do: %{opening | jan_rencontre_checked: true}, else: opening
  end

  defp can_two_tables?(off_points, color, dice) do
    with {:ok, {a, b}} <- State.dice_pair(dice),
         [p1, p2] <- off_points do
      (State.norm_pos(p1, color) - a == Constants.coin_norm_pos() and
         State.norm_pos(p2, color) - b == 11) or
        (State.norm_pos(p1, color) - b == Constants.coin_norm_pos() and
           State.norm_pos(p2, color) - a == 11)
    else
      _ -> false
    end
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
