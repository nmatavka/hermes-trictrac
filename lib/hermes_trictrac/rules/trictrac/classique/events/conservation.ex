defmodule HermesTrictrac.Rules.Trictrac.Classique.Events.Conservation do
  @behaviour HermesTrictrac.Rules.Trictrac.Classique.Events.Rule

  alias HermesTrictrac.Rules.Trictrac.Classique.{Constants, Moves, Scoring, State}
  alias HermesTrictrac.Rules.Trictrac.Classique.Events.RuleResult

  @spec apply(RuleResult.t()) :: RuleResult.t()
  def apply(%RuleResult{context: context} = result) do
    candidates = Map.get(context, :conservation_candidates, []) || []

    RuleResult.add_events(
      result,
      Enum.flat_map(candidates, fn candidate ->
        events_for(candidate, context)
      end)
    )
  end

  defp events_for(candidate, context) do
    table = Constants.jan_table!(candidate.key)
    outside_after = State.outside_count(context.end_board, context.color)

    ordinary_conservation? =
      Moves.all_paired?(context.end_board, context.variant, context.color, table.from, table.to)

    sortie_progress? =
      candidate.allow_sortie and outside_after > (candidate.outside_before || 0)

    if ordinary_conservation? or sortie_progress? do
      mode = if sortie_progress?, do: :privilege, else: :ordinary

      [
        Scoring.event(context.color, Constants.conservation_rule(table.key), candidate.points, %{
          mode: mode,
          resolution: if(mode == :privilege, do: :conservation_by_privilege, else: :earned_now)
        })
      ]
    else
      []
    end
  end
end
