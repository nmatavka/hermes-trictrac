defmodule HermesTrictrac.Rules.Trictrac.Classique.Events.Ways do
  alias HermesTrictrac.Rules.Trictrac.Classique.{Branches, Constants, Dice, Moves, State}

  def jan_missing_info(board, color, from_norm, to_norm) do
    jan_missing_info(board, nil, color, from_norm, to_norm)
  end

  def jan_missing_info(board, variant, color, from_norm, to_norm) do
    from_norm..to_norm
    |> Enum.reduce(%{missing_units: 0, single_pos: [], empty_pos: []}, fn norm, acc ->
      pos = denorm_pos(variant, norm, color)
      cnt = Moves.pieces_at(board, pos, color)

      cond do
        cnt >= 2 ->
          acc

        cnt == 1 ->
          %{acc | missing_units: acc.missing_units + 1, single_pos: [pos | acc.single_pos]}

        true ->
          %{acc | missing_units: acc.missing_units + 2, empty_pos: [pos | acc.empty_pos]}
      end
    end)
    |> then(fn info ->
      %{info | single_pos: Enum.reverse(info.single_pos), empty_pos: Enum.reverse(info.empty_pos)}
    end)
  end

  def to_target(board, color, target, dice, opts \\ []) do
    allow_opp_single_on_rest = Keyword.get(opts, :allow_opp_single_on_rest, true)
    opts = normalize_opts(opts)
    variant = Keyword.get(opts, :variant)

    if Dice.double?(dice) do
      d = Dice.first(dice)
      has_single = direct_way?(board, color, target, d, d, opts)
      has_double = source_usable_at_distance?(board, color, target, d * 2, opts)
      can_rest = can_rest_on_middle?(board, color, target, d, allow_opp_single_on_rest, variant)

      %{
        true_ways: if(has_single, do: 1, else: 0) + if(has_double and can_rest, do: 1, else: 0),
        false_ways: if(has_double and !can_rest, do: 1, else: 0)
      }
    else
      with {:ok, {a, b}} <- Dice.faces(dice) do
        true_ways =
          if(direct_way?(board, color, target, a, b, opts),
            do: 1,
            else: 0
          ) +
            if(direct_way?(board, color, target, b, a, opts),
              do: 1,
              else: 0
            ) +
            if(
              source_usable_at_distance?(board, color, target, a + b, opts) and
                (can_rest_on_middle?(board, color, target, b, allow_opp_single_on_rest, variant) or
                   can_rest_on_middle?(board, color, target, a, allow_opp_single_on_rest, variant)),
              do: 1,
              else: 0
            )

        false_ways =
          if source_usable_at_distance?(board, color, target, a + b, opts) and
               !(can_rest_on_middle?(board, color, target, b, allow_opp_single_on_rest, variant) or
                   can_rest_on_middle?(board, color, target, a, allow_opp_single_on_rest, variant)),
             do: 1,
             else: 0

        %{true_ways: true_ways, false_ways: false_ways}
      else
        :error -> %{true_ways: 0, false_ways: 0}
      end
    end
  end

  @doc """
  Returns every scoreable remplissage that the current roll can complete.

  A fill is a virtual, roll-time calculation, but it must be realizable by a
  maximum-usage legal branch.  This deliberately uses the same move generator
  as normal play instead of trying to infer possibilities from distances.  In
  particular, a table with two demi-cases scores only when one ordered branch
  can place the second (final) checker after the first has been fixed.
  """
  def remplissage_candidates(start_board, variant, color, dice) do
    branches = Branches.best_turn_branches(start_board, variant, color, dice)

    scoring_tables(variant)
    |> Enum.flat_map(fn table ->
      missing = jan_missing_info(start_board, variant, color, table.from, table.to)

      case fill_methods_for_table(start_board, variant, color, table, missing, branches) do
        [] ->
          []

        methods ->
          [
            %{
              key: table.key,
              ways: length(methods),
              missing_units: missing.missing_units,
              missing_positions: missing_positions(missing),
              methods: methods
            }
          ]
      end
    end)
  end

  def remplissage_way_count(start_board, color, table, dice, variant \\ nil) do
    variant = variant || %{id: "trictrac_classique", total_pieces: 15}

    remplissage_candidates(start_board, variant, color, dice)
    |> Enum.find_value(0, fn candidate ->
      if candidate.key == table.key, do: candidate.ways, else: nil
    end)
  end

  defp fill_methods_for_table(
         _start_board,
         _variant,
         _color,
         _table,
         %{missing_units: units},
         _branches
       )
       when units not in 1..2,
       do: []

  defp fill_methods_for_table(start_board, variant, color, table, missing, branches) do
    branches
    |> Enum.flat_map(fn branch ->
      if Moves.all_paired?(branch.board, variant, color, table.from, table.to) do
        case method_for_branch(start_board, variant, color, table, missing, branch.steps) do
          nil -> []
          method -> [method]
        end
      else
        []
      end
    end)
    |> Enum.uniq_by(& &1.signature)
    |> Enum.sort_by(& &1.signature)
    |> Enum.map(&Map.delete(&1, :signature))
  end

  defp method_for_branch(start_board, variant, color, table, missing, steps) do
    result =
      Enum.reduce_while(steps, {[], [], start_board}, fn %{move: move, board: next_board},
                                                         {relevant, played_moves, _previous_board} ->
        cond do
          move.from in missing_positions(missing) ->
            # The historical virtual construction fills the existing
            # demi-case(s); it cannot first disturb one of them.
            {:halt, :invalid}

          true ->
            relevant =
              if move_targets_missing?(move, missing) do
                [method_step(move, List.last(played_moves)) | relevant]
              else
                relevant
              end

            played_moves = played_moves ++ [move]

            if Moves.all_paired?(next_board, variant, color, table.from, table.to) do
              {:halt, {Enum.reverse(relevant), next_board}}
            else
              {:cont, {relevant, played_moves, next_board}}
            end
        end
      end)

    case result do
      {completion_steps, _board} when is_list(completion_steps) ->
        build_fill_method(completion_steps, missing)

      _ ->
        nil
    end
  end

  defp build_fill_method(completion_steps, missing) do
    if complete_virtual_fill?(completion_steps, missing) do
      completion_order = Enum.map(completion_steps, & &1.target)
      dice = Enum.flat_map(completion_steps, & &1.dice_used)

      %{
        signature: Enum.map(completion_steps, &method_step_signature/1),
        completion_order: completion_order,
        dice_used: dice,
        steps: completion_steps
      }
    end
  end

  defp method_step_signature(%{target: target, dice_used: [die]}), do: {:direct, target, die}

  defp method_step_signature(%{target: target, dice_used: dice_used}),
    do: {:combined, target, Enum.sort(dice_used)}

  defp move_targets_missing?(move, missing) do
    move.to in missing_positions(missing)
  end

  defp complete_virtual_fill?(steps, %{single_pos: positions}) when positions != [] do
    Enum.all?(positions, fn target -> Enum.any?(steps, &(&1.target == target)) end)
  end

  defp complete_virtual_fill?(steps, %{empty_pos: positions}) when positions != [] do
    Enum.all?(positions, fn target -> Enum.count(steps, &(&1.target == target)) >= 2 end)
  end

  defp complete_virtual_fill?(_steps, _missing), do: false

  defp method_step(move, previous_move) do
    dice_used = Map.get(move, :dice_used, [move.die])
    sequence = Map.get(move, :sequence, dice_used)

    if chained_single_steps?(previous_move, move) do
      previous_dice = Map.get(previous_move, :dice_used, [previous_move.die])
      previous_sequence = Map.get(previous_move, :sequence, previous_dice)

      %{
        target: move.to,
        dice_used: previous_dice ++ dice_used,
        sequence: previous_sequence ++ sequence
      }
    else
      %{target: move.to, dice_used: dice_used, sequence: sequence}
    end
  end

  defp chained_single_steps?(nil, _move), do: false

  defp chained_single_steps?(previous_move, move) do
    previous_move.to == move.from and
      length(Map.get(previous_move, :dice_used, [previous_move.die])) == 1 and
      length(Map.get(move, :dice_used, [move.die])) == 1
  end

  defp missing_positions(missing), do: missing.single_pos ++ missing.empty_pos

  defp scoring_tables(%{id: "plein"}),
    do: Enum.filter(Constants.jan_tables(), &(&1.key == :grand))

  defp scoring_tables(_variant), do: Constants.jan_tables()

  def coin_battu_true_ways(board, color, dice) do
    coin_battu_true_ways(board, color, dice, nil)
  end

  def coin_battu_true_ways(board, color, dice, variant) do
    target = opp_coin(variant, color)

    if Dice.double?(dice) do
      if count_coin_battu_sources_at_distance(board, variant, color, target, Dice.first(dice)) >=
           2,
         do: 1,
         else: 0
    else
      with {:ok, {a, b}} <- Dice.faces(dice) do
        if count_coin_battu_sources_at_distance(board, variant, color, target, a) > 0 and
             count_coin_battu_sources_at_distance(board, variant, color, target, b) > 0,
           do: 1,
           else: 0
      else
        :error -> 0
      end
    end
  end

  def coin_battu_false_ways(board, color, dice) do
    coin_battu_false_ways(board, color, dice, nil)
  end

  def coin_battu_false_ways(board, color, dice, variant) do
    target = opp_coin(variant, color)

    ways =
      to_target(board, color, target, dice, allow_opp_single_on_rest: false, variant: variant)

    if ways.true_ways > 0, do: 0, else: ways.false_ways
  end

  defp normalize_opts(opts) do
    Keyword.put_new(opts, :own_coin_policy, :ordinary)
  end

  defp direct_way?(board, color, target, die, other_die, opts) do
    source_usable_at_distance?(board, color, target, die, opts) or
      exact_own_coin_pair_direct_way?(board, color, target, die, other_die, opts)
  end

  defp exact_own_coin_pair_direct_way?(board, color, target, die, other_die, opts) do
    variant = Keyword.get(opts, :variant)

    with :must_move_both_if_made <- Keyword.get(opts, :own_coin_policy, :ordinary),
         {:ok, source} <- source_at_distance(target, color, die, variant),
         true <- source == own_coin(variant, color),
         2 <- Moves.pieces_at(board, source, color),
         variant when not is_nil(variant) <- variant do
      coin_can_move_with_die?(board, variant, color, other_die)
    else
      _ -> false
    end
  end

  defp coin_can_move_with_die?(board, variant, color, die) do
    board
    |> Moves.raw_legal_moves(variant, color, [die])
    |> Enum.any?(&(&1.from == own_coin(variant, color)))
  end

  defp source_usable_at_distance?(board, color, target, distance, opts) do
    variant = Keyword.get(opts, :variant)

    with {:ok, source} <- source_at_distance(target, color, distance, variant) do
      count = Moves.pieces_at(board, source, color)
      policy = Keyword.get(opts, :own_coin_policy, :ordinary)

      cond do
        count <= 0 ->
          false

        source != own_coin(variant, color) ->
          true

        policy != :must_move_both_if_made ->
          true

        count > 2 ->
          true

        true ->
          false
      end
    else
      :error -> false
    end
  end

  defp source_at_distance(target, color, distance, variant) do
    source_norm = norm_pos(variant, target, color) + distance

    if source_norm in 0..23 do
      {:ok, denorm_pos(variant, source_norm, color)}
    else
      :error
    end
  end

  defp count_coin_battu_sources_at_distance(board, variant, color, target, distance) do
    source_norm = norm_pos(variant, target, color) + distance

    cond do
      source_norm not in 0..23 ->
        0

      true ->
        source = denorm_pos(variant, source_norm, color)
        count = Moves.pieces_at(board, source, color)

        if source == own_coin(variant, color) do
          max(count - 2, 0)
        else
          count
        end
    end
  end

  defp can_rest_on_middle?(board, color, target, second_step, allow_opp_single, variant) do
    rest_norm = norm_pos(variant, target, color) + second_step

    if rest_norm not in 0..23 do
      false
    else
      rest = denorm_pos(variant, rest_norm, color)
      opp_count = Moves.pieces_at(board, rest, State.opposite(color))
      opp_count < 2 and (allow_opp_single or opp_count == 0)
    end
  end

  defp norm_pos(nil, position, color), do: State.norm_pos(position, color)
  defp norm_pos(variant, position, color), do: State.norm_pos(variant, position, color)
  defp denorm_pos(nil, position, color), do: State.denorm_pos(position, color)
  defp denorm_pos(variant, position, color), do: State.denorm_pos(variant, position, color)
  defp own_coin(nil, color), do: State.own_coin(color)
  defp own_coin(variant, color), do: State.own_coin(variant, color)
  defp opp_coin(nil, color), do: State.opp_coin(color)
  defp opp_coin(variant, color), do: State.opp_coin(variant, color)
end
