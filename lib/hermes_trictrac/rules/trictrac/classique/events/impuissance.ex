defmodule HermesTrictrac.Rules.Trictrac.Classique.Events.Impuissance do
  @behaviour HermesTrictrac.Rules.Trictrac.Classique.Events.Rule

  alias HermesTrictrac.Rules.Trictrac.Classique.{Scoring, State}
  alias HermesTrictrac.Rules.Trictrac.Classique.Events.RuleResult

  @spec apply(RuleResult.t()) :: RuleResult.t()
  def apply(%RuleResult{context: context} = result) do
    points =
      context.trictrac
      |> Map.get(:pending_impuissance_by_type, %{})
      |> Kernel.||(%{})
      |> Map.get(context.color, 0)

    if points > 0 do
      RuleResult.add_events(result, [
        Scoring.event(State.opposite(context.color), :impuissance, points, %{
          mode: :blocked_passage,
          resolution: :opponent_beneficiary
        })
      ])
    else
      result
    end
  end
end
