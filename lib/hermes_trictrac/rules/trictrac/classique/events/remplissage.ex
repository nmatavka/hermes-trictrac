defmodule HermesTrictrac.Rules.Trictrac.Classique.Events.Remplissage do
  @behaviour HermesTrictrac.Rules.Trictrac.Classique.Events.Rule

  alias HermesTrictrac.Rules.Trictrac.Classique.{Constants, Moves, Scoring}
  alias HermesTrictrac.Rules.Trictrac.Classique.Events.{EventBuilder, RuleResult, Ways}
  alias HermesTrictrac.Rules.Trictrac.VariantRules

  def roll_candidates(start_board, variant, color, dice),
    do: Ways.remplissage_candidates(start_board, variant, color, dice)

  def roll_events(variant, color, dice, candidates) do
    Enum.flat_map(candidates, fn candidate ->
      table = Constants.jan_table(candidate.key)

      points =
        VariantRules.remplissage_points(
          variant,
          candidate.key,
          HermesTrictrac.Rules.Trictrac.Classique.State.double?(dice),
          candidate.ways
        )

      EventBuilder.maybe(points, fn ->
        Scoring.event(color, Constants.remplissage_rule(table.key), points, %{
          ways: candidate.ways,
          missing_units: candidate.missing_units,
          missing_positions: candidate.missing_positions,
          methods: candidate.methods,
          resolution: :roll_time_virtual
        })
      end)
    end)
  end

  @spec apply(RuleResult.t()) :: RuleResult.t()
  def apply(%RuleResult{context: context} = result) do
    RuleResult.add_events(
      result,
      Enum.flat_map(Constants.scoring_tables_for_variant(context.variant), fn table ->
        events_for(table, context)
      end)
    )
  end

  defp events_for(table, context) do
    start_full =
      Moves.all_paired?(context.start_board, context.variant, context.color, table.from, table.to)

    end_full =
      Moves.all_paired?(context.end_board, context.variant, context.color, table.from, table.to)

    if !start_full and end_full do
      missing =
        Ways.jan_missing_info(
          context.start_board,
          context.variant,
          context.color,
          table.from,
          table.to
        )

      candidate =
        context
        |> Map.get(:fill_candidates, [])
        |> Enum.find(&(&1.key == table.key))

      ways = if(candidate, do: candidate.ways, else: 0)

      points =
        VariantRules.remplissage_points(context.variant, table.key, context.is_double, ways)

      EventBuilder.maybe(points, fn ->
        Scoring.event(context.color, Constants.remplissage_rule(table.key), points, %{
          ways: ways,
          missing_units: missing.missing_units,
          missing_positions: if(candidate, do: candidate.missing_positions, else: []),
          methods: if(candidate, do: candidate.methods, else: []),
          resolution: :roll_time_virtual
        })
      end)
    else
      []
    end
  end
end
