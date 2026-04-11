defmodule HermesTrictrac.Rules.Trictrac.Classique.Events do
  alias HermesTrictrac.Rules.Trictrac.Classique.{
    Branches,
    Constants,
    Moves,
    Opening,
    Scoring,
    State,
    TurnAnalysis,
    Validation
  }

  alias HermesTrictrac.Rules.Trictrac.VariantRules

  def detect_turn_events(start_board, end_board, variant, color, dice, trictrac) do
    trictrac = State.ensure(trictrac)
    opening = trictrac.opening
    coup_index = opening.coups_by_type[color]
    is_double = State.double?(dice)
    board_changed = start_board != end_board
    branches_info = Branches.best_end_branches(start_board, variant, color, dice)

    context = %{
      start_board: start_board,
      end_board: end_board,
      variant: variant,
      color: color,
      dice: dice,
      trictrac: trictrac,
      opening: opening,
      coup_index: coup_index,
      board_changed: board_changed,
      branches_info: branches_info,
      is_double: is_double,
      conservation_candidates:
        Validation.build_conservation_candidates(start_board, variant, color, dice, branches_info),
      pile_misere:
        pile_misere_resolution(trictrac, variant, end_board, color, branches_info, is_double)
    }

    if plein_variant?(variant) do
      detect_plein_turn_events(context)
    else
      detect_classique_turn_events(context)
    end
  end

  defp detect_plein_turn_events(context) do
    obligations =
      Validation.build_obligations(
        context.start_board,
        context.end_board,
        %{id: "plein"},
        context.color,
        context.dice,
        context.branches_info,
        context.conservation_candidates
      )

    {events, _context} =
      Enum.reduce([&eval_remplissage/1, &eval_conservation/1], {[], context}, fn evaluator, acc ->
        evaluator.(acc)
      end)

    %TurnAnalysis{
      opening: context.opening,
      obligations: obligations,
      conservation_candidates: context.conservation_candidates,
      pile_misere_candidate: nil,
      pile_misere_pending: false,
      events: events
    }
  end

  defp detect_classique_turn_events(context) do
    depart_done =
      get_in(context.opening, [:depart_done_by_type, context.color]) ||
        %{two_tables: false, meseas: false, six_tables: false}

    context =
      context
      |> Map.put(:depart_done, depart_done)
      |> Map.put(
        :obligations,
        Validation.build_obligations(
          context.start_board,
          context.end_board,
          context.variant,
          context.color,
          context.dice,
          context.branches_info,
          context.conservation_candidates
        )
      )
      |> Map.put(:pile_misere_candidate, elem(context.pile_misere, 0))
      |> Map.put(:pile_misere_pending, elem(context.pile_misere, 1))

    evaluators = [
      &eval_jan_rencontre/1,
      &eval_coin_jans/1,
      &eval_jan_recompense/1,
      &eval_coin_battu/1,
      &eval_remplissage/1,
      &eval_conservation/1,
      &eval_pile_misere/1,
      &eval_margot/1,
      &eval_impuissance/1,
      &eval_sortie/1
    ]

    {events, context} =
      Enum.reduce(evaluators, {[], context}, fn evaluator, acc ->
        evaluator.(acc)
      end)

    opening =
      put_in(
        context.opening,
        [:depart_done_by_type, context.color],
        context.depart_done
      )

    %TurnAnalysis{
      opening: opening,
      obligations: context.obligations,
      conservation_candidates: context.conservation_candidates,
      pile_misere_candidate: context.pile_misere_candidate,
      pile_misere_pending: context.pile_misere_pending,
      events: events
    }
  end

  defp eval_jan_rencontre({events, context}) do
    {events, opening} =
      Opening.detect_jan_rencontre(
        events,
        context.color,
        context.dice,
        context.opening,
        context.variant
      )

    {events, %{context | opening: opening}}
  end

  defp eval_coin_jans({events, context}) do
    {events, depart_done} =
      Opening.detect_coin_jans(
        events,
        context.start_board,
        context.end_board,
        context.color,
        context.dice,
        context.coup_index,
        context.depart_done,
        context.variant
      )

    {events, %{context | depart_done: depart_done}}
  end

  defp eval_jan_recompense({events, %{board_changed: false} = context}), do: {events, context}

  defp eval_jan_recompense({events, context}) do
    opp = State.opposite(context.color)

    events =
      Enum.reduce(0..23, events, fn pos, acc ->
        if Moves.pieces_at(context.start_board, pos, opp) == 1 do
          ways = ways_to_target(context.start_board, context.color, pos, context.dice)

          true_points =
            VariantRules.jan_recompense_points(
              context.variant,
              pos,
              opp,
              context.is_double,
              ways.true_ways
            )

          acc =
            if true_points > 0 do
              acc ++
                [
                  Scoring.event(context.color, "jan de recompense", true_points, %{
                    target: pos,
                    mode: :a_vrai,
                    resolution: :earned_now,
                    true_ways: ways.true_ways
                  })
                ]
            else
              acc
            end

          false_ways =
            if VariantRules.false_hit_scoring?(context.variant) and ways.true_ways == 0,
              do: ways.false_ways,
              else: 0

          false_points =
            VariantRules.jan_recompense_points(
              context.variant,
              pos,
              opp,
              context.is_double,
              false_ways
            )

          if false_points > 0 do
            acc ++
              [
                Scoring.event(opp, "jan qui ne peut", false_points, %{
                  target: pos,
                  mode: :a_faux,
                  resolution: :opponent_beneficiary,
                  false_ways: false_ways
                })
              ]
          else
            acc
          end
        else
          acc
        end
      end)

    {events, context}
  end

  defp eval_coin_battu({events, %{board_changed: false} = context}), do: {events, context}

  defp eval_coin_battu({events, context}) do
    opp = State.opposite(context.color)

    events =
      if length(context.dice.values || []) >= 2 and
           Moves.pieces_at(context.end_board, State.own_coin(context.color), context.color) >= 2 and
           Moves.pieces_at(context.end_board, State.opp_coin(context.color), opp) == 0 do
        target = State.opp_coin(context.color)
        base = VariantRules.coin_battu_points(context.variant, context.is_double)
        true_ways = coin_battu_true_ways(context.end_board, context.color, context.dice)

        false_ways =
          if VariantRules.false_hit_scoring?(context.variant) and true_ways == 0,
            do: coin_battu_false_ways(context.end_board, context.color, context.dice),
            else: 0

        events
        |> maybe_add_coin_battu(context.color, target, base, true_ways)
        |> maybe_add_coin_battu_a_faux(opp, target, base, false_ways)
      else
        events
      end

    {events, context}
  end

  defp eval_remplissage({events, context}) do
    events =
      Enum.reduce(Constants.scoring_tables_for_variant(context.variant), events, fn table, acc ->
        start_full = Moves.all_paired?(context.start_board, context.color, table.from, table.to)
        end_full = Moves.all_paired?(context.end_board, context.color, table.from, table.to)

        if !start_full and end_full do
          missing = jan_missing_info(context.start_board, context.color, table.from, table.to)

          ways =
            remplissage_way_count(
              context.start_board,
              context.color,
              table,
              context.dice,
              context.branches_info
            )

          points =
            VariantRules.remplissage_points(
              context.variant,
              table.key,
              context.is_double,
              ways
            )

          if points > 0 do
            acc ++
              [
                Scoring.event(context.color, "remplissage #{table.label}", points, %{
                  ways: ways,
                  missing_units: missing.missing_units,
                  resolution: :earned_now
                })
              ]
          else
            acc
          end
        else
          acc
        end
      end)

    {events, context}
  end

  defp eval_conservation({events, context}) do
    events =
      Enum.reduce(context.conservation_candidates, events, fn candidate, acc ->
        table = Enum.find(Constants.jan_tables(), &(&1.key == candidate.key))

        conserved? =
          table &&
            (Moves.all_paired?(context.end_board, context.color, table.from, table.to) or
               (candidate.allow_sortie and
                  (context.end_board.outside[context.color] || 0) >
                    (candidate.outside_before || 0)))

        if conserved? do
          mode =
            if candidate.allow_sortie and
                 (context.end_board.outside[context.color] || 0) > (candidate.outside_before || 0) do
              :privilege
            else
              :ordinary
            end

          acc ++
            [
              Scoring.event(context.color, "conservation #{table.label}", candidate.points, %{
                mode: mode,
                resolution:
                  if(mode == :privilege, do: :conservation_by_privilege, else: :earned_now)
              })
            ]
        else
          acc
        end
      end)

    {events, context}
  end

  defp eval_pile_misere({events, %{pile_misere_candidate: nil} = context}), do: {events, context}

  defp eval_pile_misere({events, context}) do
    events =
      if Moves.pieces_at(context.end_board, State.own_coin(context.color), context.color) >= 15 do
        candidate = context.pile_misere_candidate

        events ++
          [
            Scoring.event(context.color, "pile de misere", candidate.points, %{
              mode: candidate.mode,
              resolution: :earned_now
            })
          ]
      else
        events
      end

    {events, context}
  end

  defp eval_margot({events, %{board_changed: false} = context}), do: {events, context}

  defp eval_margot({events, context}) do
    events =
      if context.trictrac.options["margotEnabled"] and length(context.dice.values || []) >= 2 do
        opp = State.opposite(context.color)

        distances =
          if context.is_double do
            [hd(context.dice.values), hd(context.dice.values) * 2]
          else
            [
              hd(context.dice.values),
              List.last(context.dice.values),
              Enum.sum(context.dice.values)
            ]
          end

        ways =
          Enum.count(distances, fn distance ->
            Enum.any?(0..23, fn pos ->
              Moves.pieces_at(context.end_board, pos, context.color) > 0 and
                margot_target?(context.end_board, context.color, opp, pos, distance)
            end)
          end)

        margot_points = VariantRules.margot_points(context.variant, context.is_double, ways)

        if margot_points > 0 do
          events ++ [Scoring.event(opp, "Margot la fendue", margot_points)]
        else
          events
        end
      else
        events
      end

    {events, context}
  end

  defp eval_impuissance({events, context}) do
    points = context.trictrac.pending_impuissance_by_type[context.color] || 0

    events =
      if points > 0 do
        events ++
          [
            Scoring.event(State.opposite(context.color), "impuissance", points, %{
              mode: :blocked_passage,
              resolution: :opponent_beneficiary
            })
          ]
      else
        events
      end

    {events, context}
  end

  defp eval_sortie({events, context}) do
    outside_before = context.start_board.outside[context.color] || 0
    outside_after = context.end_board.outside[context.color] || 0
    sortie_points = VariantRules.sortie_points(context.variant, context.is_double)

    events =
      if outside_after >= context.variant.total_pieces and outside_after > outside_before and
           sortie_points > 0 do
        events ++ [Scoring.event(context.color, "sortie", sortie_points)]
      else
        events
      end

    {events, context}
  end

  def pile_misere_resolution(trictrac, variant, end_board, color, branches_info, is_double) do
    points = VariantRules.pile_misere_points(variant, is_double)
    already_pending = get_in(trictrac, [:pile_misere_pending_by_type, color]) || false

    still_piled =
      Moves.pieces_at(end_board, State.own_coin(color), color) >= 15 and
        pile_misere_countable?(branches_info, color)

    cond do
      points <= 0 ->
        {nil, false}

      still_piled and already_pending ->
        {%{points: points, mode: :conservation}, true}

      still_piled ->
        {nil, true}

      true ->
        {nil, false}
    end
  end

  defp pile_misere_countable?(branches_info, color) do
    Enum.all?(branches_info.branches, fn branch ->
      Moves.pieces_at(branch, State.own_coin(color), color) >= 15
    end)
  end

  defp jan_missing_info(board, color, from_norm, to_norm) do
    Enum.reduce(from_norm..to_norm, %{missing_units: 0, single_pos: [], empty_pos: []}, fn norm,
                                                                                           acc ->
      pos = State.denorm_pos(norm, color)
      cnt = Moves.pieces_at(board, pos, color)

      cond do
        cnt >= 2 ->
          acc

        cnt == 1 ->
          %{acc | missing_units: acc.missing_units + 1, single_pos: acc.single_pos ++ [pos]}

        true ->
          %{acc | missing_units: acc.missing_units + 2, empty_pos: acc.empty_pos ++ [pos]}
      end
    end)
  end

  defp ways_to_target(board, color, target, dice, opts \\ []) do
    allow_opp_single_on_rest = Keyword.get(opts, :allow_opp_single_on_rest, true)
    disallow_coin_single = Keyword.get(opts, :disallow_coin_single, false)

    if State.double?(dice) do
      d = hd(dice.values)
      has_single = has_source_at_distance?(board, color, target, d, disallow_coin_single)
      has_double = has_source_at_distance?(board, color, target, d * 2, disallow_coin_single)
      can_rest = can_rest_on_middle?(board, color, target, d, allow_opp_single_on_rest)

      %{
        true_ways: if(has_single, do: 1, else: 0) + if(has_double and can_rest, do: 1, else: 0),
        false_ways: if(has_double and !can_rest, do: 1, else: 0)
      }
    else
      [a, b] = dice.values

      true_ways =
        if(has_source_at_distance?(board, color, target, a, disallow_coin_single), do: 1, else: 0) +
          if(has_source_at_distance?(board, color, target, b, disallow_coin_single),
            do: 1,
            else: 0
          ) +
          if(
            has_source_at_distance?(board, color, target, a + b, disallow_coin_single) and
              (can_rest_on_middle?(board, color, target, b, allow_opp_single_on_rest) or
                 can_rest_on_middle?(board, color, target, a, allow_opp_single_on_rest)),
            do: 1,
            else: 0
          )

      false_ways =
        if has_source_at_distance?(board, color, target, a + b, disallow_coin_single) and
             !(can_rest_on_middle?(board, color, target, b, allow_opp_single_on_rest) or
                 can_rest_on_middle?(board, color, target, a, allow_opp_single_on_rest)),
           do: 1,
           else: 0

      %{true_ways: true_ways, false_ways: false_ways}
    end
  end

  defp has_source_at_distance?(board, color, target, distance, disallow_coin_single) do
    source_norm = State.norm_pos(target, color) + distance

    if source_norm in 0..23 do
      source = State.denorm_pos(source_norm, color)
      count = Moves.pieces_at(board, source, color)
      count > 0 and !(disallow_coin_single and source == State.own_coin(color) and count <= 2)
    else
      false
    end
  end

  defp count_coin_battu_sources_at_distance(board, color, target, distance) do
    source_norm = State.norm_pos(target, color) + distance

    cond do
      source_norm not in 0..23 ->
        0

      true ->
        source = State.denorm_pos(source_norm, color)
        count = Moves.pieces_at(board, source, color)

        if source == State.own_coin(color) do
          max(count - 2, 0)
        else
          count
        end
    end
  end

  defp can_rest_on_middle?(board, color, target, second_step, allow_opp_single) do
    rest_norm = State.norm_pos(target, color) + second_step

    if rest_norm not in 0..23 do
      false
    else
      rest = State.denorm_pos(rest_norm, color)
      opp_count = Moves.pieces_at(board, rest, State.opposite(color))
      opp_count < 2 and (allow_opp_single or opp_count == 0)
    end
  end

  defp remplissage_way_count(start_board, color, table, dice, branches_info) do
    missing = jan_missing_info(start_board, color, table.from, table.to)

    branch_ways =
      branches_info.branches
      |> Enum.filter(&Moves.all_paired?(&1, color, table.from, table.to))
      |> length()
      |> min(3)

    targeted_ways =
      if missing.missing_units == 1 and length(missing.single_pos) == 1 do
        ways_to_target(start_board, color, hd(missing.single_pos), dice,
          disallow_coin_single: table.key == :retour
        ).true_ways
      else
        0
      end

    max(1, max(branch_ways, targeted_ways))
  end

  defp coin_battu_true_ways(board, color, dice) do
    target = State.opp_coin(color)

    if State.double?(dice) do
      if count_coin_battu_sources_at_distance(board, color, target, hd(dice.values)) >= 2,
        do: 1,
        else: 0
    else
      if count_coin_battu_sources_at_distance(board, color, target, hd(dice.values)) > 0 and
           count_coin_battu_sources_at_distance(board, color, target, List.last(dice.values)) > 0,
         do: 1,
         else: 0
    end
  end

  defp coin_battu_false_ways(board, color, dice) do
    target = State.opp_coin(color)
    ways = ways_to_target(board, color, target, dice, allow_opp_single_on_rest: false)
    if ways.true_ways > 0, do: 0, else: ways.false_ways
  end

  defp maybe_add_coin_battu(events, _color, _target, _base, 0), do: events

  defp maybe_add_coin_battu(events, color, target, base, ways) do
    events ++
      [
        Scoring.event(color, "coin battu", base * ways, %{
          target: target,
          mode: :a_vrai,
          resolution: :earned_now,
          true_ways: ways
        })
      ]
  end

  defp maybe_add_coin_battu_a_faux(events, _opp, _target, _base, 0), do: events

  defp maybe_add_coin_battu_a_faux(events, opp, target, base, ways) do
    events ++
      [
        Scoring.event(
          opp,
          "coin battu a faux",
          base * ways,
          %{
            target: target,
            mode: :a_faux,
            resolution: :opponent_beneficiary,
            false_ways: ways
          },
          Constants.score_source("coin battu a faux")
        )
      ]
  end

  defp margot_target?(board, color, opp, source, distance) do
    dst_norm = State.norm_pos(source, color) - distance

    if dst_norm in 0..23 do
      dst = State.denorm_pos(dst_norm, color)
      left_norm = dst_norm - 1
      right_norm = dst_norm + 1

      left_norm in 0..23 and right_norm in 0..23 and
        Moves.count_all_at(board, dst) == 0 and
        Moves.pieces_at(board, State.denorm_pos(left_norm, color), opp) == 1 and
        Moves.pieces_at(board, State.denorm_pos(right_norm, color), opp) == 1
    else
      false
    end
  end

  defp plein_variant?(%{id: "plein"}), do: true
  defp plein_variant?(_variant), do: false
end
