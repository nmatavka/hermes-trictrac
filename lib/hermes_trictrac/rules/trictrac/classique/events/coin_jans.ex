defmodule HermesTrictrac.Rules.Trictrac.Classique.Events.CoinJans do
  @behaviour HermesTrictrac.Rules.Trictrac.Classique.Events.Rule

  alias HermesTrictrac.Rules.Trictrac.Classique.Events.RuleResult
  alias HermesTrictrac.Rules.Trictrac.Classique.Opening

  @spec apply(RuleResult.t()) :: RuleResult.t()
  def apply(%RuleResult{events: events, context: context} = result) do
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

    %{result | events: events, context: %{context | depart_done: depart_done}}
  end
end
