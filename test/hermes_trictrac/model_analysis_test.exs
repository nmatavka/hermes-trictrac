defmodule HermesTrictrac.ModelAnalysisTest do
  use ExUnit.Case, async: true

  alias HermesTrictrac.{ModelAnalysis, Xgid}
  alias HermesTrictrac.Rules.{RaceCore, Registry, TrictracCore}
  alias HermesTrictrac.Rules.Trictrac.Classique

  test "model analysis surfaces intermediate trictrac scoring events along a line" do
    assert {:ok, parsed} =
             Xgid.parse("XGID=-a-----bbabbb-------------:0:0:-1:44:0:0:0:1:0")

    variant = Registry.fetch!("trictrac_classique") |> Map.put(:orientation, :ascending)

    dice = %{
      values: [4, 4, 4, 4],
      moves: [4, 4, 4, 4],
      moves_left: [4, 4, 4, 4],
      moves_played: []
    }

    match_options = %{"margotEnabled" => true, "black_direction" => "toward_24"}

    runtime =
      variant
      |> TrictracCore.new()
      |> TrictracCore.submit_options(variant, match_options)
      |> Map.put(:board, parsed.board)
      |> Map.put(:match, %{
        is_over: false,
        score: %{white: 0, black: 0},
        length: 1,
        winner: nil,
        winner_kind: nil,
        results: [],
        options: match_options,
        variant_id: variant.id
      })
      |> Map.put(:turn_color, :white)
      |> Map.put(:turn_number, 1)
      |> Map.put(:dice, dice)
      |> Map.put(:history, [])
      |> Map.put(:pending_turn_decision, nil)
      |> begin_trictrac_turn(variant, dice, match_options)
      |> then(&Map.put(&1, :legal_moves, RaceCore.legal_moves(&1, variant, :white)))

    line_events =
      ModelAnalysis.line_events_for_actions(runtime, variant, [
        %{"type" => "move", "from" => 0, "to" => 4},
        %{"type" => "move", "from" => 4, "to" => 8}
      ])

    assert :coin_battu in Enum.map(line_events, & &1.rule)
    assert :remplissage_grand in Enum.map(line_events, & &1.rule)
  end

  defp begin_trictrac_turn(runtime, variant, dice, match_options) do
    trictrac =
      runtime.trictrac
      |> Classique.apply_options(match_options)
      |> Classique.begin_turn(runtime.board, variant, :white, dice)

    %{runtime | trictrac: trictrac}
  end
end
