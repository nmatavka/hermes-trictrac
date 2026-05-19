defmodule HermesTrictrac.XgidTest do
  use ExUnit.Case, async: true

  alias HermesTrictrac.Rules.{RaceCore, Registry, TrictracCore}
  alias HermesTrictrac.Rules.Trictrac.Classique
  alias HermesTrictrac.Training.TrictracBridge
  alias HermesTrictrac.Xgid

  @starting_xgid "XGID=-O----------------------o-:0:0:-1:61:0:0:0:1:0"
  @position_xgid "XGID=-DCCBBA-----------aa----m-:0:0:-1:66:0:0:0:0:10"
  @bar_xgid "XGID=m------------------------M:0:0:-1:66:0:0:0:0:10"

  test "parses XGID points from the bottom player's perspective" do
    assert {:ok, parsed} = Xgid.parse(@starting_xgid)

    assert parsed.turn_color == :white
    assert parsed.dice == [6, 1]
    assert Enum.at(parsed.board.points, 0) == %{black: 15, white: 0}
    assert Enum.at(parsed.board.points, 23) == %{black: 0, white: 15}
    assert parsed.board.outside == %{black: 0, white: 0}
  end

  test "maps XGID characters 2 through 25 to board points" do
    assert {:ok, parsed} = Xgid.parse(@position_xgid)

    assert parsed.turn_color == :white
    assert parsed.dice == [6, 6]
    assert parsed.board.bar.white == 0
    assert Enum.at(parsed.board.points, 23).white == 13
    assert Enum.at(parsed.board.points, 0).black == 4
  end

  test "maps XGID bars at the first and last position characters" do
    assert {:ok, parsed} = Xgid.parse(@bar_xgid)

    assert parsed.turn_color == :white
    assert parsed.board.bar.white == 13
    assert parsed.board.bar.black == 13
    assert Enum.all?(parsed.board.points, &(&1.white == 0 and &1.black == 0))
  end

  test "rejects XGIDs with more than fifteen men of one color on the board" do
    xgid = "XGID=-a----------------------o-:0:0:-1:61:0:0:0:1:0"

    assert {:error, message} = Xgid.parse(xgid)
    assert message =~ "16 white men"
  end

  test "trictrac classique legal actions do not bear off from the talon" do
    assert {:ok, parsed} = Xgid.parse(@starting_xgid)

    variant = Registry.fetch!("trictrac_classique")
    dice = %{values: [6, 1], moves: [6, 1], moves_left: [6, 1], moves_played: []}

    runtime =
      variant
      |> TrictracCore.new()
      |> TrictracCore.submit_options(variant, %{"margotEnabled" => false})
      |> Map.put(:board, parsed.board)
      |> Map.put(:match, match_state(variant))
      |> Map.put(:turn_color, :white)
      |> Map.put(:turn_number, 1)
      |> Map.put(:dice, dice)
      |> Map.put(:history, [])
      |> Map.put(:pending_turn_decision, nil)
      |> begin_trictrac_turn(variant, dice)
      |> then(&Map.put(&1, :legal_moves, RaceCore.legal_moves(&1, variant, :white)))

    legal_actions = TrictracBridge.serialize_state(runtime)["legal_actions"]

    refute Enum.any?(legal_actions, &(&1["to"] == "home"))

    assert Enum.any?(legal_actions, &(&1["from"] == 23 and &1["to"] == 16))
    assert Enum.any?(legal_actions, &(&1["from"] == 23 and &1["to"] == 17))
    assert Enum.any?(legal_actions, &(&1["from"] == 23 and &1["to"] == 22))
  end

  test "trictrac model-lab direction can make white move from point 24 toward point 1" do
    assert {:ok, parsed} =
             Xgid.parse("XGID=-----a-bbabbb-------------:0:0:-1:43:0:0:0:1:0")

    variant = Registry.fetch!("trictrac_classique") |> Map.put(:orientation, :ascending)
    dice = %{values: [4, 3], moves: [4, 3], moves_left: [4, 3], moves_played: []}

    runtime =
      variant
      |> TrictracCore.new()
      |> TrictracCore.submit_options(variant, %{"margotEnabled" => false})
      |> Map.put(:board, parsed.board)
      |> Map.put(:match, match_state(variant))
      |> Map.put(:turn_color, :white)
      |> Map.put(:turn_number, 1)
      |> Map.put(:dice, dice)
      |> Map.put(:history, [])
      |> Map.put(:pending_turn_decision, nil)
      |> begin_trictrac_turn(variant, dice)
      |> then(&Map.put(&1, :legal_moves, RaceCore.legal_moves(&1, variant, :white)))

    display_moves =
      Enum.map(runtime.legal_moves, fn move ->
        {display_point(move.from), display_point(move.to), move.die, Map.get(move, :sequence)}
      end)

    assert {20, 16, 4, nil} in display_moves
    assert {18, 15, 3, nil} in display_moves
    refute {20, 24, 4, nil} in display_moves
    refute {18, 21, 3, nil} in display_moves

    legal_actions = TrictracBridge.serialize_state(runtime)["legal_actions"]

    assert Enum.any?(legal_actions, &(&1["from"] == 4 and &1["to"] == 8))
    refute Enum.any?(legal_actions, &(&1["from"] == 4 and &1["to"] == 0))
  end

  defp begin_trictrac_turn(runtime, variant, dice) do
    trictrac =
      runtime.trictrac
      |> Classique.apply_options(%{"margotEnabled" => false})
      |> Classique.begin_turn(runtime.board, variant, :white, dice)

    %{runtime | trictrac: trictrac}
  end

  defp match_state(variant) do
    %{
      is_over: false,
      score: %{white: 0, black: 0},
      length: 1,
      winner: nil,
      winner_kind: nil,
      results: [],
      options: %{"margotEnabled" => false},
      variant_id: variant.id
    }
  end

  defp display_point(point) when is_integer(point), do: 24 - point
  defp display_point(point), do: point
end
