defmodule HermesTrictrac.Rules.Trictrac.Classique.Events.JanRencontre do
  @behaviour HermesTrictrac.Rules.Trictrac.Classique.Events.Rule

  alias HermesTrictrac.Rules.Trictrac.Classique.Events.RuleResult
  alias HermesTrictrac.Rules.Trictrac.Classique.Opening

  @spec apply(RuleResult.t()) :: RuleResult.t()
  def apply(%RuleResult{events: events, context: context} = result) do
    {events, opening} =
      Opening.detect_jan_rencontre(
        events,
        context.color,
        context.dice,
        context.opening,
        context.variant
      )

    %{result | events: events, context: %{context | opening: opening}}
  end
end
