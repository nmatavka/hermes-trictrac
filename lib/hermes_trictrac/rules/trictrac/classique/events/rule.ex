defmodule HermesTrictrac.Rules.Trictrac.Classique.Events.Rule do
  alias HermesTrictrac.Rules.Trictrac.Classique.Events.RuleResult

  @callback apply(RuleResult.t()) :: RuleResult.t()
end
