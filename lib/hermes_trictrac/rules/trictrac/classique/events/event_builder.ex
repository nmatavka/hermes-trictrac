defmodule HermesTrictrac.Rules.Trictrac.Classique.Events.EventBuilder do
  @spec maybe(number(), (-> term())) :: [term()]
  def maybe(points, build_event) when is_number(points) and points > 0, do: [build_event.()]
  def maybe(_points, _build_event), do: []
end
