defmodule HermesTrictrac.Rules.Trictrac.Classique.Events.Margot do
  @behaviour HermesTrictrac.Rules.Trictrac.Classique.Events.Rule

  alias HermesTrictrac.Rules.Trictrac.Classique.{Dice, Moves, Scoring, State}
  alias HermesTrictrac.Rules.Trictrac.Classique.Events.RuleResult
  alias HermesTrictrac.Rules.Trictrac.VariantRules

  @spec apply(RuleResult.t()) :: RuleResult.t()
  def apply(%RuleResult{context: %{board_changed: false}} = result), do: result

  def apply(%RuleResult{context: context} = result) do
    options = Map.get(context.trictrac, :options, %{}) || %{}

    if Map.get(options, "margotEnabled", false) and Dice.has_two_faces?(context.dice) do
      opp = State.opposite(context.color)

      matches =
        for distance <- distances(context),
            pos <- 0..23,
            Moves.pieces_at(context.end_board, pos, context.color) > 0 and
              margot_target?(
                context.end_board,
                context.variant,
                context.color,
                opp,
                pos,
                distance
              ) do
          %{source: pos, distance: distance}
        end

      ways =
        matches
        |> Enum.map(& &1.distance)
        |> Enum.uniq()
        |> length()

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

  defp distances(%{is_double: true, dice: dice}), do: [Dice.first(dice), Dice.first(dice) * 2]

  defp distances(%{dice: dice}) do
    case Dice.faces(dice) do
      {:ok, {a, b}} -> [a, b, a + b]
      :error -> []
    end
  end

  defp margot_target?(board, variant, color, opp, source, distance) do
    dst_norm = State.norm_pos(variant, source, color) - distance

    if dst_norm in 0..23 do
      dst = State.denorm_pos(variant, dst_norm, color)
      left_norm = dst_norm - 1
      right_norm = dst_norm + 1

      left_norm in 0..23 and right_norm in 0..23 and
        Moves.count_all_at(board, dst) == 0 and
        Moves.pieces_at(board, State.denorm_pos(variant, left_norm, color), opp) == 1 and
        Moves.pieces_at(board, State.denorm_pos(variant, right_norm, color), opp) == 1
    else
      false
    end
  end
end
