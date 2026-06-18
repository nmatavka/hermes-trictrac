defmodule HermesTrictrac.Rules.Trictrac.Classique.Events.Margot do
  @behaviour HermesTrictrac.Rules.Trictrac.Classique.Events.Rule

  alias HermesTrictrac.Rules.Trictrac.Classique.{Dice, Moves, Scoring, State}
  alias HermesTrictrac.Rules.Trictrac.Classique.Events.{RuleResult, Ways}
  alias HermesTrictrac.Rules.Trictrac.VariantRules

  @spec apply(RuleResult.t()) :: RuleResult.t()
  def apply(%RuleResult{context: %{board_changed: false}} = result), do: result

  def apply(%RuleResult{context: context} = result) do
    options = Map.get(context.trictrac, :options, %{}) || %{}

    if Map.get(options, "margotEnabled", false) and Dice.has_two_faces?(context.dice) do
      opp = State.opposite(context.color)

      matches =
        for target <- 0..23,
            split_gap?(context.start_board, context.variant, context.color, opp, target),
            landed_on?(context.start_board, context.end_board, context.color, target),
            ways = margot_ways(context, target),
            ways > 0 do
          %{target: target, ways: ways}
        end

      ways =
        matches
        |> Enum.map(& &1.ways)
        |> Enum.sum()

      margot_points = VariantRules.margot_points(context.variant, context.is_double, ways)

      if margot_points > 0 do
        RuleResult.add_events(result, [
          Scoring.event(opp, :margot, margot_points, %{
            ways: ways,
            matches: matches,
            resolution: :opponent_beneficiary
          })
        ])
      else
        result
      end
    else
      result
    end
  end

  defp margot_ways(context, target) do
    context.start_board
    |> Ways.to_target(context.color, target, context.dice, variant: context.variant)
    |> Map.get(:true_ways, 0)
  end

  defp landed_on?(start_board, end_board, color, target) do
    Moves.pieces_at(end_board, target, color) > Moves.pieces_at(start_board, target, color)
  end

  defp split_gap?(board, variant, color, opp, target) do
    target_norm = State.norm_pos(variant, target, color)
    left_norm = target_norm - 1
    right_norm = target_norm + 1

    left_norm in 0..23 and right_norm in 0..23 and
      Moves.count_all_at(board, target) == 0 and
      Moves.pieces_at(board, State.denorm_pos(variant, left_norm, color), opp) == 1 and
      Moves.pieces_at(board, State.denorm_pos(variant, right_norm, color), opp) == 1
  end
end
