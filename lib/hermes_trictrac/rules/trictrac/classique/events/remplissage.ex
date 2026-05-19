defmodule HermesTrictrac.Rules.Trictrac.Classique.Events.Remplissage do
  @behaviour HermesTrictrac.Rules.Trictrac.Classique.Events.Rule

  alias HermesTrictrac.Rules.Trictrac.Classique.{Constants, Moves, Scoring}
  alias HermesTrictrac.Rules.Trictrac.Classique.Events.{EventBuilder, RuleResult, Ways}
  alias HermesTrictrac.Rules.Trictrac.VariantRules

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

      ways =
        Ways.remplissage_way_count(
          context.start_board,
          context.color,
          table,
          context.dice,
          context.variant
        )

      points =
        VariantRules.remplissage_points(context.variant, table.key, context.is_double, ways)

      EventBuilder.maybe(points, fn ->
        Scoring.event(context.color, Constants.remplissage_rule(table.key), points, %{
          ways: ways,
          missing_units: missing.missing_units,
          resolution: :earned_now
        })
      end)
    else
      []
    end
  end
end
