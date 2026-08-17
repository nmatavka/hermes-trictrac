defmodule HermesTrictrac.Rules.Trictrac.Classique.Events do
  alias HermesTrictrac.Rules.Trictrac.Classique.{
    Branches,
    State,
    TurnAnalysis,
    Validation
  }

  alias HermesTrictrac.Rules.Trictrac.Classique.Events.{
    CoinBattu,
    Conservation,
    Context,
    Impuissance,
    JanRecompense,
    Margot,
    PileMisere,
    RuleResult,
    Sortie
  }

  @plein_rules [Conservation]

  @classique_rules [
    JanRecompense,
    CoinBattu,
    Conservation,
    PileMisere,
    Margot,
    Impuissance,
    Sortie
  ]

  @spec detect_turn_events(map(), map(), map(), atom(), map(), map()) :: TurnAnalysis.t()
  def detect_turn_events(start_board, end_board, variant, color, dice, trictrac) do
    detect_turn_events(start_board, end_board, variant, color, dice, trictrac, [])
  end

  @spec detect_turn_events(map(), map(), map(), atom(), map(), map(), keyword()) ::
          TurnAnalysis.t()
  def detect_turn_events(start_board, end_board, variant, color, dice, trictrac, opts)
      when is_list(opts) do
    trictrac = State.ensure(trictrac)
    opening = trictrac.opening
    is_double = State.double?(dice)

    branches_info =
      Keyword.get_lazy(opts, :branches_info, fn ->
        Branches.best_end_branches(start_board, variant, color, dice)
      end)

    context = %Context{
      start_board: start_board,
      end_board: end_board,
      variant: variant,
      color: color,
      dice: dice,
      trictrac: trictrac,
      opening: opening,
      coup_index: opening.coups_by_type[color],
      board_changed: start_board != end_board,
      branches_info: branches_info,
      is_double: is_double,
      conservation_candidates:
        Validation.build_conservation_candidates(start_board, variant, color, dice, branches_info),
      pile_misere:
        PileMisere.resolution(trictrac, variant, end_board, color, branches_info, is_double),
      fill_candidates: Keyword.get(opts, :fill_candidates, [])
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
        context.conservation_candidates,
        context.fill_candidates
      )

    result = apply_rules(@plein_rules, context)

    %TurnAnalysis{
      opening: context.opening,
      obligations: obligations,
      conservation_candidates: context.conservation_candidates,
      pile_misere_candidate: nil,
      pile_misere_pending: false,
      events: pre_move_events(context) ++ result.events
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
          context.conservation_candidates,
          context.fill_candidates
        )
      )
      |> Map.put(:pile_misere_candidate, elem(context.pile_misere, 0))
      |> Map.put(:pile_misere_pending, elem(context.pile_misere, 1))

    %{events: events, context: context} = apply_rules(@classique_rules, context)

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
      events: pre_move_events(context) ++ events
    }
  end

  defp apply_rules(rules, context) do
    Enum.reduce(rules, RuleResult.new(context), fn rule, result ->
      rule.apply(result)
    end)
  end

  defp pre_move_events(context), do: get_in(context.trictrac, [:turn, :events]) || []

  defp plein_variant?(%{id: "plein"}), do: true
  defp plein_variant?(_variant), do: false
end
