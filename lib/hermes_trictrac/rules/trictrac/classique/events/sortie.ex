defmodule HermesTrictrac.Rules.Trictrac.Classique.Events.Sortie do
  @behaviour HermesTrictrac.Rules.Trictrac.Classique.Events.Rule

  alias HermesTrictrac.Rules.Trictrac.Classique.{Scoring, State}
  alias HermesTrictrac.Rules.Trictrac.Classique.Events.RuleResult
  alias HermesTrictrac.Rules.Trictrac.VariantRules

  @spec apply(RuleResult.t()) :: RuleResult.t()
  def apply(%RuleResult{context: context} = result) do
    outside_before = State.outside_count(context.start_board, context.color)
    outside_after = State.outside_count(context.end_board, context.color)
    total_pieces = Map.get(context.variant, :total_pieces, 15)
    sortie_points = VariantRules.sortie_points(context.variant, context.is_double)

    if outside_after >= total_pieces and outside_after > outside_before and
         sortie_points > 0 do
      RuleResult.add_events(result, [
        Scoring.event(context.color, :sortie, sortie_points, %{
          outside_before: outside_before,
          outside_after: outside_after,
          resolution: :earned_now
        })
      ])
    else
      result
    end
  end
end
