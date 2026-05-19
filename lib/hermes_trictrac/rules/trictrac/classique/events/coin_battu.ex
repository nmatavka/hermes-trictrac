defmodule HermesTrictrac.Rules.Trictrac.Classique.Events.CoinBattu do
  @behaviour HermesTrictrac.Rules.Trictrac.Classique.Events.Rule

  alias HermesTrictrac.Rules.Trictrac.Classique.{Constants, Dice, Moves, Scoring, State}
  alias HermesTrictrac.Rules.Trictrac.Classique.Events.{RuleResult, Ways}
  alias HermesTrictrac.Rules.Trictrac.VariantRules

  @spec apply(RuleResult.t()) :: RuleResult.t()
  def apply(%RuleResult{context: %{board_changed: false}} = result), do: result

  def apply(%RuleResult{context: context} = result) do
    opp = State.opposite(context.color)

    if eligible?(context, opp) do
      target = State.opp_coin(context.variant, context.color)
      base = VariantRules.coin_battu_points(context.variant, context.is_double)

      true_ways =
        Ways.coin_battu_true_ways(
          context.end_board,
          context.color,
          context.dice,
          context.variant
        )

      false_ways =
        if VariantRules.false_hit_scoring?(context.variant) and true_ways == 0,
          do:
            Ways.coin_battu_false_ways(
              context.end_board,
              context.color,
              context.dice,
              context.variant
            ),
          else: 0

      result
      |> RuleResult.add_events(coin_battu_events(context.color, target, base, true_ways))
      |> RuleResult.add_events(coin_battu_a_faux_events(opp, target, base, false_ways))
    else
      result
    end
  end

  defp eligible?(context, opp) do
    Dice.has_two_faces?(context.dice) and own_coin_made?(context) and
      opponent_coin_empty?(context, opp)
  end

  defp own_coin_made?(context) do
    Moves.pieces_at(
      context.end_board,
      State.own_coin(context.variant, context.color),
      context.color
    ) >=
      2
  end

  defp opponent_coin_empty?(context, opp) do
    Moves.pieces_at(context.end_board, State.opp_coin(context.variant, context.color), opp) == 0
  end

  defp coin_battu_events(_color, _target, _base, 0), do: []

  defp coin_battu_events(color, target, base, ways) do
    points = base * ways

    if points <= 0 do
      []
    else
      [
        Scoring.event(color, :coin_battu, points, %{
          target: target,
          mode: :a_vrai,
          resolution: :earned_now,
          true_ways: ways
        })
      ]
    end
  end

  defp coin_battu_a_faux_events(_opp, _target, _base, 0), do: []

  defp coin_battu_a_faux_events(opp, target, base, ways) do
    points = base * ways

    if points <= 0 do
      []
    else
      [
        Scoring.event(
          opp,
          :coin_battu_a_faux,
          points,
          %{
            target: target,
            mode: :a_faux,
            resolution: :opponent_beneficiary,
            false_ways: ways
          },
          Constants.score_source(:coin_battu_a_faux)
        )
      ]
    end
  end
end
