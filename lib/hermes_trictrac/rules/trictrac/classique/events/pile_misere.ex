defmodule HermesTrictrac.Rules.Trictrac.Classique.Events.PileMisere do
  @behaviour HermesTrictrac.Rules.Trictrac.Classique.Events.Rule

  alias HermesTrictrac.Rules.Trictrac.Classique.{Moves, Scoring, State}
  alias HermesTrictrac.Rules.Trictrac.Classique.Events.RuleResult
  alias HermesTrictrac.Rules.Trictrac.VariantRules

  @spec apply(RuleResult.t()) :: RuleResult.t()
  def apply(%RuleResult{context: %{pile_misere_candidate: nil}} = result), do: result

  def apply(%RuleResult{context: context} = result) do
    if Moves.pieces_at(
         context.end_board,
         State.own_coin(context.variant, context.color),
         context.color
       ) >=
         15 do
      candidate = context.pile_misere_candidate

      RuleResult.add_events(result, [
        Scoring.event(context.color, :pile_misere, candidate.points, %{
          mode: candidate.mode,
          resolution: :earned_now
        })
      ])
    else
      result
    end
  end

  def resolution(trictrac, variant, end_board, color, branches_info, is_double) do
    points = VariantRules.pile_misere_points(variant, is_double)

    already_pending =
      (trictrac || %{})
      |> Map.get(:pile_misere_pending_by_type, %{})
      |> Map.get(color, false)

    still_piled =
      Moves.pieces_at(end_board, State.own_coin(variant, color), color) >= 15 and
        countable?(branches_info, variant, color)

    cond do
      points <= 0 ->
        {nil, false}

      still_piled and already_pending ->
        {%{points: points, mode: :conservation}, true}

      still_piled ->
        {nil, true}

      true ->
        {nil, false}
    end
  end

  defp countable?(%{branches: [_ | _] = branches}, variant, color) do
    Enum.all?(branches, fn branch ->
      Moves.pieces_at(branch, State.own_coin(variant, color), color) >= 15
    end)
  end

  defp countable?(_branches_info, _variant, _color), do: false
end
