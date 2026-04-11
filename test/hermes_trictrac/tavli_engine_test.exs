defmodule HermesTrictrac.TavliEngineTest do
  use ExUnit.Case, async: false

  alias HermesTrictrac.Rules.Engine

  defp ready_engine(lobby) do
    engine = Engine.new(lobby, "tavli")
    {:ok, engine, _} = Engine.join(engine, "nick", "tab-a")
    {:ok, engine, _} = Engine.join(engine, "jane", "tab-b")
    engine
  end

  defp choose_target(engine, white_choice, black_choice \\ nil) do
    black_choice = black_choice || white_choice

    {:ok, engine} =
      Engine.submit_match_options(
        engine,
        %{"tavliTargetConsent" => white_choice},
        "nick",
        "tab-a"
      )

    {:ok, engine} =
      Engine.submit_match_options(
        engine,
        %{"tavliTargetConsent" => black_choice},
        "jane",
        "tab-b"
      )

    engine
  end

  defp empty_points do
    Enum.map(0..23, fn _ -> %{white: 0, black: 0} end)
  end

  defp put_point(points, index, point) do
    List.replace_at(points, index, point)
  end

  defp confirmable_engine(
         engine,
         board,
         turn_color,
         score \\ %{white: 0, black: 0},
         leg \\ "backgammon"
       ) do
    dice = %{values: [1, 2], moves: [1, 2], moves_left: [], moves_played: [1, 2]}

    runtime =
      engine.runtime
      |> Map.put(:board, board)
      |> Map.put(:dice, dice)
      |> put_in([:variant_state, :tavli_active_leg], leg)
      |> Map.put(:match, %{engine.match | score: score})

    %{
      engine
      | runtime: runtime,
        board: board,
        dice: dice,
        legal_moves: [],
        history: [],
        turn_color: turn_color,
        turn_number: 1,
        match: runtime.match
    }
  end

  test "tavli requires bilateral target consent and starts on backgammon with opening roll pending" do
    engine = ready_engine("tavli-consent")

    snapshot = Engine.snapshot(engine)
    assert snapshot["status"] == "awaiting_match_options"
    assert snapshot["pending_match_options"]["kind"] == "tavli_target_consent"

    engine = choose_target(engine, "3")
    snapshot = Engine.snapshot(engine)

    assert snapshot["status"] == "playing"
    assert snapshot["match"]["length"] == 3
    assert snapshot["match"]["options"]["tavliTarget"] == "3"
    assert snapshot["variant"]["active_leg"]["id"] == "backgammon"
    assert snapshot["opening_roll"]["order"] == "highest"
    assert snapshot["turn"] == nil
  end

  test "tavli target disagreement defaults to seven" do
    engine = ready_engine("tavli-default")
    engine = choose_target(engine, "3", "9")
    snapshot = Engine.snapshot(engine)

    assert snapshot["match"]["length"] == 7
    assert snapshot["match"]["options"]["tavliTarget"] == "7"
  end

  test "tavli backgammon leg scores and advances to tapa with a fresh opening roll" do
    engine = ready_engine("tavli-bg")
    engine = choose_target(engine, "3")

    board = %{
      engine.board
      | points: empty_points() |> put_point(0, %{white: 0, black: 14}),
        outside: %{white: 15, black: 1},
        bar: %{white: 0, black: 0}
    }

    engine = confirmable_engine(engine, board, :white)

    assert {:ok, engine} = Engine.confirm(engine, "nick", "tab-a")
    snapshot = Engine.snapshot(engine)

    assert snapshot["match"]["score"] == %{"white" => 1, "black" => 0}
    assert snapshot["match"]["is_over"] == false
    assert snapshot["variant"]["active_leg"]["id"] == "tapa"
    assert snapshot["opening_roll"]["pending"] == true
    assert snapshot["turn"] == nil
    assert snapshot["dice"] == nil
  end

  test "tavli tapa talon gammon scores two points and advances to jacquet" do
    engine = ready_engine("tavli-tapa-gammon")
    engine = choose_target(engine, "3")

    points =
      empty_points()
      |> put_point(0, %{white: 1, black: 1, top: :white})
      |> put_point(23, %{white: 14, black: 0})
      |> put_point(5, %{white: 0, black: 14})

    board = %{
      engine.board
      | points: points,
        outside: %{white: 0, black: 0},
        bar: %{white: 0, black: 0}
    }

    engine = confirmable_engine(engine, board, :white, %{white: 0, black: 0}, "tapa")

    assert {:ok, engine} = Engine.confirm(engine, "nick", "tab-a")
    snapshot = Engine.snapshot(engine)

    assert snapshot["match"]["score"] == %{"white" => 2, "black" => 0}

    assert snapshot["match"]["results"] == [
             %{
               "leg" => "tapa",
               "winner" => "white",
               "kind" => "talon_gammon",
               "awards" => %{"white" => 2, "black" => 0}
             }
           ]

    assert snapshot["variant"]["active_leg"]["id"] == "jacquet"
    assert snapshot["opening_roll"]["pending"] == true
  end

  test "tavli tapa mutual pinned talon draw gives one point each and continues on a tie at the target" do
    engine = ready_engine("tavli-tapa-draw")
    engine = choose_target(engine, "3")

    points =
      empty_points()
      |> put_point(0, %{white: 1, black: 1, top: :white})
      |> put_point(23, %{white: 1, black: 1, top: :black})
      |> put_point(5, %{white: 0, black: 13})
      |> put_point(18, %{white: 13, black: 0})

    board = %{
      engine.board
      | points: points,
        outside: %{white: 0, black: 0},
        bar: %{white: 0, black: 0}
    }

    engine = confirmable_engine(engine, board, :white, %{white: 2, black: 2}, "tapa")

    assert {:ok, engine} = Engine.confirm(engine, "nick", "tab-a")
    snapshot = Engine.snapshot(engine)

    assert snapshot["match"]["score"] == %{"white" => 3, "black" => 3}
    assert snapshot["match"]["is_over"] == false
    assert snapshot["match"]["winner"] == nil

    assert List.last(snapshot["match"]["results"]) == %{
             "leg" => "tapa",
             "winner" => nil,
             "kind" => "draw",
             "awards" => %{"white" => 1, "black" => 1}
           }

    assert snapshot["variant"]["active_leg"]["id"] == "jacquet"
  end

  test "tavli ends the match once a player reaches the target with a lead" do
    engine = ready_engine("tavli-finish")
    engine = choose_target(engine, "3")

    board = %{
      engine.board
      | points: empty_points() |> put_point(0, %{white: 0, black: 14}),
        outside: %{white: 15, black: 1},
        bar: %{white: 0, black: 0}
    }

    engine = confirmable_engine(engine, board, :white, %{white: 2, black: 0}, "backgammon")

    assert {:ok, engine} = Engine.confirm(engine, "nick", "tab-a")
    snapshot = Engine.snapshot(engine)

    assert snapshot["match"]["is_over"] == true
    assert snapshot["match"]["winner"] == "white"
    assert snapshot["match"]["winner_kind"] == "tavli_match"
    assert snapshot["match"]["score"] == %{"white" => 3, "black" => 0}
  end
end
