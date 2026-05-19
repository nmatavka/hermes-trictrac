defmodule HermesTrictrac.Rules.Trictrac.Classique.Events.JanRecompense do
  @behaviour HermesTrictrac.Rules.Trictrac.Classique.Events.Rule

  alias HermesTrictrac.Rules.Trictrac.Classique.{Moves, Scoring, State}
  alias HermesTrictrac.Rules.Trictrac.Classique.Events.{EventBuilder, RuleResult, Ways}
  alias HermesTrictrac.Rules.Trictrac.VariantRules

  @spec apply(RuleResult.t()) :: RuleResult.t()
  def apply(%RuleResult{context: %{board_changed: false}} = result), do: result

  def apply(%RuleResult{context: context} = result) do
    opp = State.opposite(context.color)

    RuleResult.add_events(
      result,
      Enum.flat_map(0..23, fn pos -> events_for(pos, context, opp) end)
    )
  end

  defp events_for(pos, context, opp) do
    if Moves.pieces_at(context.start_board, pos, opp) == 1 do
      ways = Ways.to_target(context.start_board, context.color, pos, context.dice)

      true_points =
        VariantRules.jan_recompense_points(
          context.variant,
          pos,
          opp,
          context.is_double,
          ways.true_ways
        )

      false_ways =
        if VariantRules.false_hit_scoring?(context.variant) and ways.true_ways == 0,
          do: ways.false_ways,
          else: 0

      false_points =
        VariantRules.jan_recompense_points(
          context.variant,
          pos,
          opp,
          context.is_double,
          false_ways
        )

      EventBuilder.maybe(true_points, fn ->
        Scoring.event(context.color, :jan_recompense, true_points, %{
          target: pos,
          mode: :a_vrai,
          resolution: :earned_now,
          true_ways: ways.true_ways
        })
      end) ++
        EventBuilder.maybe(false_points, fn ->
          Scoring.event(opp, :jan_qui_ne_peut, false_points, %{
            target: pos,
            mode: :a_faux,
            resolution: :opponent_beneficiary,
            false_ways: false_ways
          })
        end)
    else
      []
    end
  end
end
