defmodule Backgammon.EngineTest do
  use ExUnit.Case, async: true

  alias Backgammon.Rules.Engine

  defmodule DeterministicDice do
    def roll(1, _opts), do: [6]
    def roll(2, _opts), do: [4, 2]
    def roll(3, _opts), do: [5, 3, 1]
  end

  defmodule SequenceDice do
    def roll(count, _opts) do
      key = {__MODULE__, :values}
      values = Process.get(key, [])
      {next, rest} = Enum.split(values, count)

      if length(next) != count do
        raise "not enough queued dice values"
      end

      Process.put(key, rest)
      next
    end
  end

  setup do
    original = Application.get_env(:backgammon, :dice_impl)
    on_exit(fn -> Application.put_env(:backgammon, :dice_impl, original) end)
    :ok
  end

  defp empty_brade_turn_cause do
    %{
      white: %{last_inward_signature: nil, qualifying_signature: nil},
      black: %{last_inward_signature: nil, qualifying_signature: nil}
    }
  end

  defp prepare_classique_reprise_engine(lobby) do
    engine = Engine.new(lobby, "trictrac_classique")
    {:ok, engine, _} = Engine.join(engine, "nick", "tab-a")
    {:ok, engine, _} = Engine.join(engine, "jane", "tab-b")
    {:ok, engine} = reject_margot(engine)

    start_points =
      Enum.map(0..23, fn index ->
        cond do
          index in 12..16 -> %{white: 2, black: 0}
          index == 17 -> %{white: 1, black: 0}
          index in 18..20 -> %{white: 1, black: 0}
          true -> %{white: 0, black: 0}
        end
      end)

    end_points =
      Enum.map(0..23, fn index ->
        cond do
          index in 12..17 -> %{white: 2, black: 0}
          index in 19..20 -> %{white: 1, black: 0}
          true -> %{white: 0, black: 0}
        end
      end)

    start_board = %{
      engine.board
      | points: start_points,
        outside: %{white: 0, black: 0},
        bar: %{white: 0, black: 0}
    }

    end_board = %{
      engine.board
      | points: end_points,
        outside: %{white: 0, black: 0},
        bar: %{white: 0, black: 0}
    }

    dice = %{values: [2, 1], moves: [2, 1], moves_left: [], moves_played: [1]}

    trictrac =
      Backgammon.Rules.Trictrac.Classique.begin_turn(
        %{engine.trictrac | score: [%{points: 8, trous: 0}, %{points: 0, trous: 0}]},
        start_board,
        engine.variant,
        :white,
        dice
      )

    runtime =
      engine.runtime
      |> Map.put(:trictrac, trictrac)
      |> Map.put(:board, end_board)
      |> Map.put(:dice, dice)

    %{
      engine
      | runtime: runtime,
        trictrac: trictrac,
        board: end_board,
        turn_color: :white,
        dice: dice
    }
  end

  defp reject_margot(engine) do
    Engine.submit_match_options(engine, %{"margotConsent" => "no"}, "nick", "tab-a")
  end

  defp start_aecrire_variant(engine, style \\ "avec_releve") do
    with {:ok, engine} <- reject_margot(engine) do
      Engine.submit_match_options(engine, %{"aEcrireStyle" => style}, "nick", "tab-a")
    end
  end

  test "backgammon lobby becomes playable after two joins" do
    engine = Engine.new("bg", "backgammon")

    assert {:ok, engine, %{"color" => "white"}} = Engine.join(engine, "nick", "tab-a")
    assert engine.status == :waiting_for_opponent

    assert {:ok, engine, %{"color" => "black"}} = Engine.join(engine, "jane", "tab-b")
    assert engine.status == :playing

    snapshot = Engine.snapshot(engine)
    assert snapshot["variant"]["id"] == "backgammon"
    assert snapshot["status"] == "playing"
  end

  test "tapa uses the expected starting stacks" do
    engine = Engine.new("tapa", "tapa")
    snapshot = Engine.snapshot(engine)
    points = snapshot["board"]["points"]

    assert Enum.at(points, 0)["pieces"] == List.duplicate("black", 15)
    assert Enum.at(points, 23)["pieces"] == List.duplicate("white", 15)
  end

  test "backgammon forces the higher die when only one die is playable" do
    engine = Engine.new("bg-high", "backgammon")
    assert {:ok, engine, _} = Engine.join(engine, "nick", "tab-a")
    assert {:ok, engine, _} = Engine.join(engine, "jane", "tab-b")

    points =
      Enum.map(0..23, fn index ->
        cond do
          index == 0 -> %{white: 1, black: 0}
          index == 1 -> %{white: 0, black: 2}
          true -> %{white: 0, black: 0}
        end
      end)

    board = %{engine.board | points: points}
    dice = %{values: [3, 1], moves: [3, 1], moves_left: [3, 1], moves_played: []}
    runtime = engine.runtime |> Map.put(:board, board) |> Map.put(:dice, dice)

    legal = Backgammon.Rules.RaceCore.legal_moves(runtime, engine.variant, :white)

    assert legal == [%{from: 0, to: 3, die: 3, hit?: false, count: 1, coin_mode: :normal}]
  end

  test "backgammon filters out first moves that cannot reach the maximum dice usage" do
    engine = Engine.new("bg-max", "backgammon")
    assert {:ok, engine, _} = Engine.join(engine, "nick", "tab-a")
    assert {:ok, engine, _} = Engine.join(engine, "jane", "tab-b")

    points =
      Enum.map(0..23, fn index ->
        cond do
          index == 0 -> %{white: 1, black: 0}
          index == 4 -> %{white: 1, black: 0}
          index in [1, 7] -> %{white: 0, black: 2}
          true -> %{white: 0, black: 0}
        end
      end)

    board = %{engine.board | points: points}
    dice = %{values: [2, 1], moves: [2, 1], moves_left: [2, 1], moves_played: []}
    runtime = engine.runtime |> Map.put(:board, board) |> Map.put(:dice, dice)

    legal = Backgammon.Rules.RaceCore.legal_moves(runtime, engine.variant, :white)

    refute Enum.any?(legal, &(&1.from == 4 and &1.to == 6 and &1.die == 2))
    assert Enum.any?(legal, &(&1.from == 0 and &1.to == 2 and &1.die == 2))
  end

  test "backgammon hit sends the opponent to the bar" do
    engine = Engine.new("bg-hit", "backgammon")
    assert {:ok, engine, _} = Engine.join(engine, "nick", "tab-a")
    assert {:ok, engine, _} = Engine.join(engine, "jane", "tab-b")

    points =
      Enum.map(0..23, fn index ->
        cond do
          index == 0 -> %{white: 1, black: 0}
          index == 2 -> %{white: 0, black: 1}
          true -> %{white: 0, black: 0}
        end
      end)

    board = %{engine.board | points: points, bar: %{white: 0, black: 0}}
    dice = %{values: [2, 1], moves: [2, 1], moves_left: [2], moves_played: []}
    runtime = engine.runtime |> Map.put(:board, board) |> Map.put(:dice, dice)

    engine = %{
      engine
      | runtime: runtime,
        board: board,
        turn_color: :white,
        turn_number: 1,
        dice: dice,
        legal_moves: Backgammon.Rules.RaceCore.legal_moves(runtime, engine.variant, :white)
    }

    assert {:ok, engine} =
             Engine.move(engine, %{"from" => 0, "to" => 2, "die" => 2}, "nick", "tab-a")

    snapshot = Engine.snapshot(engine)
    assert Enum.at(snapshot["board"]["points"], 2)["pieces"] == ["white"]
    assert snapshot["board"]["bar"]["black"] == 1
  end

  test "backgammon requires bar entry before other moves" do
    engine = Engine.new("bg-bar", "backgammon")
    assert {:ok, engine, _} = Engine.join(engine, "nick", "tab-a")
    assert {:ok, engine, _} = Engine.join(engine, "jane", "tab-b")

    points =
      Enum.map(0..23, fn index ->
        cond do
          index == 5 -> %{white: 1, black: 0}
          true -> %{white: 0, black: 0}
        end
      end)

    board = %{engine.board | points: points, bar: %{white: 1, black: 0}}
    dice = %{values: [3, 1], moves: [3, 1], moves_left: [3, 1], moves_played: []}
    runtime = engine.runtime |> Map.put(:board, board) |> Map.put(:dice, dice)

    legal = Backgammon.Rules.RaceCore.legal_moves(runtime, engine.variant, :white)

    assert legal != []
    assert Enum.all?(legal, &(&1.from == "bar"))
  end

  test "backgammon overshoot bearing off only allows the farthest checker" do
    engine = Engine.new("bg-bearoff", "backgammon")
    assert {:ok, engine, _} = Engine.join(engine, "nick", "tab-a")
    assert {:ok, engine, _} = Engine.join(engine, "jane", "tab-b")

    points =
      Enum.map(0..23, fn index ->
        cond do
          index == 18 -> %{white: 14, black: 0}
          index == 20 -> %{white: 1, black: 0}
          true -> %{white: 0, black: 0}
        end
      end)

    board = %{engine.board | points: points, outside: %{white: 0, black: 0}}
    dice = %{values: [6, 1], moves: [6, 1], moves_left: [6], moves_played: []}
    runtime = engine.runtime |> Map.put(:board, board) |> Map.put(:dice, dice)

    legal = Backgammon.Rules.RaceCore.legal_moves(runtime, engine.variant, :white)

    assert Enum.any?(legal, &(&1.from == 18 and &1.to == "home"))
    refute Enum.any?(legal, &(&1.from == 20 and &1.to == "home"))
  end

  test "backgammon can confirm a no-move roll and exhaust the turn" do
    engine = Engine.new("bg-pass", "backgammon")
    assert {:ok, engine, _} = Engine.join(engine, "nick", "tab-a")
    assert {:ok, engine, _} = Engine.join(engine, "jane", "tab-b")

    points =
      Enum.map(0..23, fn index ->
        cond do
          index in [0, 1] -> %{white: 0, black: 2}
          true -> %{white: 0, black: 0}
        end
      end)

    board = %{engine.board | points: points, bar: %{white: 1, black: 0}}
    dice = %{values: [2, 1], moves: [2, 1], moves_left: [2, 1], moves_played: []}
    runtime = engine.runtime |> Map.put(:board, board) |> Map.put(:dice, dice)
    legal_moves = Backgammon.Rules.RaceCore.legal_moves(runtime, engine.variant, :white)

    assert legal_moves == []

    engine = %{
      engine
      | runtime: Map.put(runtime, :legal_moves, legal_moves),
        board: board,
        turn_color: :white,
        turn_number: 1,
        dice: dice,
        legal_moves: legal_moves
    }

    assert {:ok, engine} = Engine.confirm(engine, "nick", "tab-a")
    snapshot = Engine.snapshot(engine)
    assert snapshot["turn"]["color"] == "black"
    assert snapshot["dice"] == nil
    assert snapshot["legal_moves"] == []
  end

  test "backgammon consumes doubles across four moves" do
    engine = Engine.new("bg-double", "backgammon")
    assert {:ok, engine, _} = Engine.join(engine, "nick", "tab-a")
    assert {:ok, engine, _} = Engine.join(engine, "jane", "tab-b")

    points =
      Enum.map(0..23, fn index ->
        if index == 0, do: %{white: 1, black: 0}, else: %{white: 0, black: 0}
      end)

    board = %{engine.board | points: points}

    dice = %{
      values: [1, 1, 1, 1],
      moves: [1, 1, 1, 1],
      moves_left: [1, 1, 1, 1],
      moves_played: []
    }

    runtime = engine.runtime |> Map.put(:board, board) |> Map.put(:dice, dice)
    legal_moves = Backgammon.Rules.RaceCore.legal_moves(runtime, engine.variant, :white)

    engine = %{
      engine
      | runtime: runtime,
        board: board,
        turn_color: :white,
        turn_number: 1,
        dice: dice,
        legal_moves: legal_moves
    }

    assert {:ok, engine} =
             Engine.move(engine, %{"from" => 0, "to" => 1, "die" => 1}, "nick", "tab-a")

    assert engine.dice.moves_left == [1, 1, 1]

    assert {:ok, engine} =
             Engine.move(engine, %{"from" => 1, "to" => 2, "die" => 1}, "nick", "tab-a")

    assert engine.dice.moves_left == [1, 1]

    assert {:ok, engine} =
             Engine.move(engine, %{"from" => 2, "to" => 3, "die" => 1}, "nick", "tab-a")

    assert engine.dice.moves_left == [1]

    assert {:ok, engine} =
             Engine.move(engine, %{"from" => 3, "to" => 4, "die" => 1}, "nick", "tab-a")

    assert engine.dice.moves_left == []
    assert Enum.at(engine.board.points, 4).white == 1
  end

  test "tapa pins onto an opposing blot instead of hitting and only the top stack owner may move" do
    engine = Engine.new("tapa-pin", "tapa")
    assert {:ok, engine, _} = Engine.join(engine, "nick", "tab-a")
    assert {:ok, engine, _} = Engine.join(engine, "jane", "tab-b")

    points =
      Enum.map(0..23, fn index ->
        cond do
          index == 5 -> %{white: 1, black: 0}
          index == 4 -> %{white: 0, black: 1}
          true -> %{white: 0, black: 0}
        end
      end)

    board = %{engine.board | points: points, bar: %{white: 0, black: 0}}
    dice = %{values: [1, 3], moves: [1, 3], moves_left: [1], moves_played: []}
    runtime = engine.runtime |> Map.put(:board, board) |> Map.put(:dice, dice)

    engine = %{
      engine
      | runtime: runtime,
        board: board,
        turn_color: :white,
        turn_number: 1,
        dice: dice,
        legal_moves: Backgammon.Rules.RaceCore.legal_moves(runtime, engine.variant, :white)
    }

    assert {:ok, engine} =
             Engine.move(engine, %{"from" => 5, "to" => 4, "die" => 1}, "nick", "tab-a")

    snapshot = Engine.snapshot(engine)
    assert Enum.at(snapshot["board"]["points"], 4)["pieces"] == ["black", "white"]
    assert snapshot["board"]["bar"]["black"] == 0

    black_runtime = %{
      engine.runtime
      | dice: %{values: [1, 2], moves: [1, 2], moves_left: [1], moves_played: []}
    }

    white_runtime = %{
      engine.runtime
      | dice: %{values: [1, 2], moves: [1, 2], moves_left: [1], moves_played: []}
    }

    refute Enum.any?(
             Backgammon.Rules.RaceCore.legal_moves(black_runtime, engine.variant, :black),
             &(&1.from == 4)
           )

    assert Enum.any?(
             Backgammon.Rules.RaceCore.legal_moves(white_runtime, engine.variant, :white),
             &(&1.from == 4 and &1.to == 3)
           )
  end

  test "tapa allows the top owner to bear off from a mixed stack in the home board" do
    engine = Engine.new("tapa-home-pin", "tapa")
    assert {:ok, engine, _} = Engine.join(engine, "nick", "tab-a")
    assert {:ok, engine, _} = Engine.join(engine, "jane", "tab-b")

    points =
      Enum.map(0..23, fn index ->
        cond do
          index == 2 -> %{white: 1, black: 1, top: :white}
          index == 0 -> %{white: 14, black: 0}
          true -> %{white: 0, black: 0}
        end
      end)

    board = %{
      engine.board
      | points: points,
        outside: %{white: 0, black: 0},
        bar: %{white: 0, black: 0}
    }

    dice = %{values: [4, 1], moves: [4, 1], moves_left: [4], moves_played: []}
    runtime = engine.runtime |> Map.put(:board, board) |> Map.put(:dice, dice)

    legal = Backgammon.Rules.RaceCore.legal_moves(runtime, engine.variant, :white)

    assert Enum.any?(legal, &(&1.from == 2 and &1.to == "home"))

    refute Enum.any?(
             Backgammon.Rules.RaceCore.legal_moves(runtime, engine.variant, :black),
             &(&1.from == 2)
           )
  end

  test "tapa allows bar entry onto a mixed stack only for the side that is on top" do
    engine = Engine.new("tapa-bar-pin", "tapa")
    assert {:ok, engine, _} = Engine.join(engine, "nick", "tab-a")
    assert {:ok, engine, _} = Engine.join(engine, "jane", "tab-b")

    points =
      Enum.map(0..23, fn index ->
        cond do
          index == 23 -> %{white: 1, black: 1, top: :white}
          true -> %{white: 0, black: 0}
        end
      end)

    board = %{
      engine.board
      | points: points,
        outside: %{white: 0, black: 0},
        bar: %{white: 1, black: 0}
    }

    dice = %{values: [1, 2], moves: [1, 2], moves_left: [1], moves_played: []}
    runtime = engine.runtime |> Map.put(:board, board) |> Map.put(:dice, dice)

    legal = Backgammon.Rules.RaceCore.legal_moves(runtime, engine.variant, :white)

    assert Enum.any?(legal, &(&1.from == "bar" and &1.to == 23 and &1.die == 1))

    refute Enum.any?(
             Backgammon.Rules.RaceCore.legal_moves(runtime, engine.variant, :black),
             &(&1.from == 23)
           )
  end

  test "tapa does not let either side move a mixed stack with no top owner metadata" do
    engine = Engine.new("tapa-ambiguous-pin", "tapa")
    assert {:ok, engine, _} = Engine.join(engine, "nick", "tab-a")
    assert {:ok, engine, _} = Engine.join(engine, "jane", "tab-b")

    points =
      Enum.map(0..23, fn index ->
        cond do
          index == 5 -> %{white: 1, black: 1}
          true -> %{white: 0, black: 0}
        end
      end)

    board = %{engine.board | points: points, bar: %{white: 0, black: 0}}
    dice = %{values: [1, 2], moves: [1, 2], moves_left: [1], moves_played: []}
    runtime = engine.runtime |> Map.put(:board, board) |> Map.put(:dice, dice)

    refute Enum.any?(
             Backgammon.Rules.RaceCore.legal_moves(runtime, engine.variant, :white),
             &(&1.from == 5)
           )

    refute Enum.any?(
             Backgammon.Rules.RaceCore.legal_moves(runtime, engine.variant, :black),
             &(&1.from == 5)
           )
  end

  test "tapa normalizes stale single-color top metadata for moves and snapshots" do
    engine = Engine.new("tapa-stale-top", "tapa")
    assert {:ok, engine, _} = Engine.join(engine, "nick", "tab-a")
    assert {:ok, engine, _} = Engine.join(engine, "jane", "tab-b")

    points =
      Enum.map(0..23, fn index ->
        cond do
          index == 5 -> %{white: 1, black: 0, top: :black}
          true -> %{white: 0, black: 0}
        end
      end)

    board = %{engine.board | points: points, bar: %{white: 0, black: 0}}
    dice = %{values: [1, 2], moves: [1, 2], moves_left: [1], moves_played: []}
    runtime = engine.runtime |> Map.put(:board, board) |> Map.put(:dice, dice)
    snapshot = Engine.snapshot(%{engine | runtime: runtime, board: board})

    assert Enum.at(snapshot["board"]["points"], 5)["pieces"] == ["white"]

    assert Enum.any?(
             Backgammon.Rules.RaceCore.legal_moves(runtime, engine.variant, :white),
             &(&1.from == 5)
           )

    refute Enum.any?(
             Backgammon.Rules.RaceCore.legal_moves(runtime, engine.variant, :black),
             &(&1.from == 5)
           )
  end

  test "tapa keeps mixed-stack ownership stable across branch filtering" do
    engine = Engine.new("tapa-branch", "tapa")
    assert {:ok, engine, _} = Engine.join(engine, "nick", "tab-a")
    assert {:ok, engine, _} = Engine.join(engine, "jane", "tab-b")

    points =
      Enum.map(0..23, fn index ->
        cond do
          index == 5 -> %{white: 1, black: 1, top: :white}
          index == 2 -> %{white: 1, black: 0}
          true -> %{white: 0, black: 0}
        end
      end)

    board = %{engine.board | points: points, bar: %{white: 0, black: 0}}
    dice = %{values: [3, 1], moves: [3, 1], moves_left: [3, 1], moves_played: []}
    runtime = engine.runtime |> Map.put(:board, board) |> Map.put(:dice, dice)

    legal = Backgammon.Rules.RaceCore.legal_moves(runtime, engine.variant, :white)

    assert Enum.any?(legal, &(&1.from == 5))

    refute Enum.any?(
             Backgammon.Rules.RaceCore.legal_moves(runtime, engine.variant, :black),
             &(&1.from == 5)
           )
  end

  test "tapa keeps mixed-stack ownership stable after a filtered move is actually played" do
    engine = Engine.new("tapa-live-branch", "tapa")
    assert {:ok, engine, _} = Engine.join(engine, "nick", "tab-a")
    assert {:ok, engine, _} = Engine.join(engine, "jane", "tab-b")

    points =
      Enum.map(0..23, fn index ->
        cond do
          index == 5 -> %{white: 1, black: 1, top: :white}
          index == 2 -> %{white: 1, black: 0}
          true -> %{white: 0, black: 0}
        end
      end)

    board = %{engine.board | points: points, bar: %{white: 0, black: 0}}
    dice = %{values: [3, 1], moves: [3, 1], moves_left: [3, 1], moves_played: []}
    runtime = engine.runtime |> Map.put(:board, board) |> Map.put(:dice, dice)
    legal_moves = Backgammon.Rules.RaceCore.legal_moves(runtime, engine.variant, :white)

    assert Enum.any?(legal_moves, &(&1.from == 5 and &1.to == 2 and &1.die == 3))

    engine =
      %{
        engine
        | runtime: runtime,
          board: board,
          turn_color: :white,
          turn_number: 1,
          dice: dice,
          legal_moves: legal_moves
      }

    assert {:ok, engine} =
             Engine.move(engine, %{"from" => 5, "to" => 2, "die" => 3}, "nick", "tab-a")

    white_runtime = %{
      engine.runtime
      | dice: %{values: [1, 2], moves: [1, 2], moves_left: [1], moves_played: []}
    }

    black_runtime = %{
      engine.runtime
      | dice: %{values: [1, 2], moves: [1, 2], moves_left: [1], moves_played: []}
    }

    refute Enum.any?(
             Backgammon.Rules.RaceCore.legal_moves(white_runtime, engine.variant, :white),
             &(&1.from == 5)
           )

    assert Enum.any?(
             Backgammon.Rules.RaceCore.legal_moves(black_runtime, engine.variant, :black),
             &(&1.from == 5 and &1.to == 6)
           )
  end

  test "tapa undo restores mixed-stack ordering in snapshots" do
    engine = Engine.new("tapa-undo-order", "tapa")
    assert {:ok, engine, _} = Engine.join(engine, "nick", "tab-a")
    assert {:ok, engine, _} = Engine.join(engine, "jane", "tab-b")

    points =
      Enum.map(0..23, fn index ->
        cond do
          index == 5 -> %{white: 1, black: 1, top: :white}
          index == 4 -> %{white: 0, black: 1}
          true -> %{white: 0, black: 0}
        end
      end)

    board = %{engine.board | points: points, bar: %{white: 0, black: 0}}
    dice = %{values: [1, 2], moves: [1, 2], moves_left: [1], moves_played: []}
    runtime = engine.runtime |> Map.put(:board, board) |> Map.put(:dice, dice)
    legal_moves = Backgammon.Rules.RaceCore.legal_moves(runtime, engine.variant, :white)

    engine =
      %{
        engine
        | runtime: runtime,
          board: board,
          turn_color: :white,
          turn_number: 1,
          dice: dice,
          legal_moves: legal_moves
      }

    assert {:ok, engine} =
             Engine.move(engine, %{"from" => 5, "to" => 4, "die" => 1}, "nick", "tab-a")

    moved_snapshot = Engine.snapshot(engine)
    assert Enum.at(moved_snapshot["board"]["points"], 4)["pieces"] == ["black", "white"]

    assert {:ok, engine} = Engine.undo(engine, "nick", "tab-a")
    undone_snapshot = Engine.snapshot(engine)
    assert Enum.at(undone_snapshot["board"]["points"], 5)["pieces"] == ["black", "white"]
    assert Enum.at(undone_snapshot["board"]["points"], 4)["pieces"] == ["black"]
  end

  test "trictrac classique waits for bilateral Margot consent before first roll" do
    engine = Engine.new("tt-classique-consent", "trictrac_classique")
    assert {:ok, engine, _} = Engine.join(engine, "nick", "tab-a")
    assert {:ok, engine, _} = Engine.join(engine, "jane", "tab-b")

    snapshot = Engine.snapshot(engine)
    assert snapshot["status"] == "awaiting_match_options"
    assert snapshot["pending_match_options"]["kind"] == "trictrac_margot_consent"
    assert snapshot["pending_match_options"]["responses"] == %{"white" => nil, "black" => nil}

    assert {:error, "Match options must be resolved before rolling."} =
             Engine.roll(engine, "nick", "tab-a")
  end

  test "trictrac Margot consent waits for both yes votes and any no disables Margot" do
    engine = Engine.new("tt-consent", "trictrac_classique")
    assert {:ok, engine, _} = Engine.join(engine, "nick", "tab-a")
    assert {:ok, engine, _} = Engine.join(engine, "jane", "tab-b")

    assert {:ok, engine} =
             Engine.submit_match_options(engine, %{"margotConsent" => "yes"}, "nick", "tab-a")

    snapshot = Engine.snapshot(engine)
    assert snapshot["status"] == "awaiting_match_options"
    assert snapshot["pending_match_options"]["responses"] == %{"white" => "yes", "black" => nil}

    assert {:ok, engine} =
             Engine.submit_match_options(engine, %{"margotConsent" => "yes"}, "jane", "tab-b")

    snapshot = Engine.snapshot(engine)
    assert snapshot["status"] == "playing"
    assert snapshot["match"]["options"]["margotEnabled"] == true

    engine = Engine.new("tt-consent-no", "trictrac_classique")
    assert {:ok, engine, _} = Engine.join(engine, "nick", "tab-a")
    assert {:ok, engine, _} = Engine.join(engine, "jane", "tab-b")

    assert {:ok, engine} =
             Engine.submit_match_options(engine, %{"margotConsent" => "no"}, "nick", "tab-a")

    snapshot = Engine.snapshot(engine)
    assert snapshot["status"] == "playing"
    assert snapshot["match"]["options"]["margotEnabled"] == false
  end

  test "resign ends an active trictrac match immediately" do
    engine = Engine.new("tt-resign", "trictrac_classique")
    assert {:ok, engine, _} = Engine.join(engine, "nick", "tab-a")
    assert {:ok, engine, _} = Engine.join(engine, "jane", "tab-b")
    assert {:ok, engine} = reject_margot(engine)

    assert {:ok, engine} = Engine.resign(engine, "nick", "tab-a")
    snapshot = Engine.snapshot(engine)

    assert snapshot["status"] == "match_over"
    assert snapshot["match"]["winner"] == "black"
    assert snapshot["match"]["winner_kind"] == "resign"
    assert snapshot["pending_match_options"] == nil
  end

  test "aecrire publishes Margot consent before style options" do
    engine = Engine.new("tt", "trictrac_aecrire")
    assert {:ok, engine, _} = Engine.join(engine, "nick", "tab-a")
    assert {:ok, engine, _} = Engine.join(engine, "jane", "tab-b")

    snapshot = Engine.snapshot(engine)
    assert snapshot["status"] == "awaiting_match_options"
    assert snapshot["pending_match_options"]["kind"] == "trictrac_margot_consent"

    assert {:ok, engine} = reject_margot(engine)
    snapshot = Engine.snapshot(engine)
    assert snapshot["pending_match_options"]["rule"] == "RuleFrTrictracAEcrire"
    assert Enum.map(snapshot["pending_match_options"]["options"], & &1["key"]) == ["aEcrireStyle"]
  end

  test "aecrire sortie queues reprise decision and tenir keeps the turn after releve" do
    engine = Engine.new("tt-decide", "trictrac_aecrire")
    assert {:ok, engine, _} = Engine.join(engine, "nick", "tab-a")
    assert {:ok, engine, _} = Engine.join(engine, "jane", "tab-b")

    assert {:ok, engine} = start_aecrire_variant(engine)

    start_points =
      Enum.map(0..23, fn index ->
        cond do
          index == 0 -> %{white: 1, black: 0}
          true -> %{white: 0, black: 0}
        end
      end)

    end_points =
      Enum.map(0..23, fn _ ->
        %{white: 0, black: 0}
      end)

    start_board = %{engine.board | points: start_points, outside: %{white: 14, black: 0}}
    end_board = %{engine.board | points: end_points, outside: %{white: 15, black: 0}}
    dice = %{values: [1, 2], moves: [1, 2], moves_left: [], moves_played: [1]}

    trictrac =
      Backgammon.Rules.Trictrac.Classique.begin_turn(
        %{engine.trictrac | score: [%{points: 8, trous: 0}, %{points: 0, trous: 0}]},
        start_board,
        engine.variant,
        :white,
        dice
      )

    runtime =
      engine.runtime
      |> Map.put(:trictrac, trictrac)
      |> Map.put(:board, end_board)
      |> Map.put(:dice, dice)

    engine = %{
      engine
      | runtime: runtime,
        trictrac: trictrac,
        board: end_board,
        turn_color: :white,
        dice: dice
    }

    assert {:ok, engine} = Engine.confirm(engine, "nick", "tab-a")
    snapshot = Engine.snapshot(engine)
    assert snapshot["pending_turn_decision"]["key"] == "reprise"
    assert get_in(snapshot, ["trictrac", "turn_event_queue", Access.at(0), "key"]) == "reprise"
    assert get_in(snapshot, ["trictrac", "sortie", "last_event", "releve"]) == true

    assert {:ok, engine} = Engine.submit_turn_decision(engine, "tenir", "nick", "tab-a")
    snapshot = Engine.snapshot(engine)
    assert snapshot["pending_turn_decision"] == nil
    assert snapshot["turn"]["color"] == "white"
    assert Enum.at(snapshot["board"]["points"], 23)["pieces"] == List.duplicate("white", 15)
  end

  test "aecrire pre-six s'en aller resets the board but preserves current coup trous" do
    engine = Engine.new("tt-pre-six", "trictrac_aecrire")
    assert {:ok, engine, _} = Engine.join(engine, "nick", "tab-a")
    assert {:ok, engine, _} = Engine.join(engine, "jane", "tab-b")

    assert {:ok, engine} = start_aecrire_variant(engine)

    start_points =
      Enum.map(0..23, fn index ->
        if index == 0, do: %{white: 1, black: 0}, else: %{white: 0, black: 0}
      end)

    end_points = Enum.map(0..23, fn _ -> %{white: 0, black: 0} end)
    start_board = %{engine.board | points: start_points, outside: %{white: 14, black: 0}}
    end_board = %{engine.board | points: end_points, outside: %{white: 15, black: 0}}
    dice = %{values: [1, 2], moves: [1, 2], moves_left: [], moves_played: [1]}

    trictrac =
      Backgammon.Rules.Trictrac.Classique.begin_turn(
        %{engine.trictrac | score: [%{points: 8, trous: 0}, %{points: 0, trous: 0}]},
        start_board,
        engine.variant,
        :white,
        dice
      )

    runtime =
      engine.runtime
      |> Map.put(:trictrac, trictrac)
      |> Map.put(:board, end_board)
      |> Map.put(:dice, dice)

    engine = %{
      engine
      | runtime: runtime,
        trictrac: trictrac,
        board: end_board,
        turn_color: :white,
        dice: dice
    }

    assert {:ok, engine} = Engine.confirm(engine, "nick", "tab-a")
    assert {:ok, engine} = Engine.submit_turn_decision(engine, "s'en aller", "nick", "tab-a")
    snapshot = Engine.snapshot(engine)

    assert snapshot["turn"]["color"] == "white"
    assert get_in(snapshot, ["trictrac", "track_aecrire", "current_coup", "trous", "white"]) == 2
    assert get_in(snapshot, ["trictrac", "score", Access.at(0), "trous"]) == 2
    assert get_in(snapshot, ["trictrac", "track_aecrire", "marques", "white"]) == 0
  end

  test "aecrire reaching six by opponent die does not allow leaving" do
    trictrac =
      Backgammon.Rules.Trictrac.AEcrire.ensure(%{})
      |> put_in([:track_aecrire, :current_coup, :trous], %{white: 5, black: 0})

    trictrac =
      Backgammon.Rules.Trictrac.AEcrire.record_turn(
        trictrac,
        :black,
        %{white: 1, black: 0}
      )

    assert Backgammon.Rules.Trictrac.AEcrire.current_coup_trous(trictrac, :white) == 6
    refute Backgammon.Rules.Trictrac.AEcrire.reprise_due?(trictrac, :white)
    refute Backgammon.Rules.Trictrac.AEcrire.settlement_ready?(trictrac, :white)
  end

  test "aecrire held coup can still be overtaken before reprise settlement" do
    trictrac =
      Backgammon.Rules.Trictrac.AEcrire.ensure(%{})
      |> put_in([:track_aecrire, :current_coup, :trous], %{white: 6, black: 5})
      |> put_in([:track_aecrire, :current_coup, :legal_exit_by], %{white: true, black: false})
      |> Backgammon.Rules.Trictrac.AEcrire.hold_current_coup(:white)
      |> Backgammon.Rules.Trictrac.AEcrire.record_turn(:black, %{white: 0, black: 2})

    assert Backgammon.Rules.Trictrac.AEcrire.current_coup_trous(trictrac, :white) == 6
    assert Backgammon.Rules.Trictrac.AEcrire.current_coup_trous(trictrac, :black) == 7
    refute Backgammon.Rules.Trictrac.AEcrire.reprise_due?(trictrac, :white)
    assert Backgammon.Rules.Trictrac.AEcrire.reprise_due?(trictrac, :black)

    {trictrac, result} = Backgammon.Rules.Trictrac.AEcrire.resolve_reprise(trictrac)

    assert result == %{ended_marque: true, refait: false, winner: :black, marque_value: 1}
    assert trictrac.track_aecrire.marques.black == 1
  end

  test "aecrire tie at six trous resolves as refait" do
    trictrac =
      Backgammon.Rules.Trictrac.AEcrire.ensure(%{})
      |> put_in([:track_aecrire, :current_coup, :trous], %{white: 6, black: 6})

    {trictrac, result} = Backgammon.Rules.Trictrac.AEcrire.resolve_reprise(trictrac)

    assert result == %{ended_marque: true, refait: true, winner: nil, marque_value: 0}
    assert trictrac.track_aecrire.last_marques_by_type == %{white: 0, black: 0}
    assert trictrac.track_aecrire.last_marque_result.refait == true
  end

  test "aecrire ensure seeds a blank current coup from raw score on partial track state" do
    trictrac =
      Backgammon.Rules.Trictrac.AEcrire.ensure(%{
        score: [%{points: 0, trous: 4}, %{points: 0, trous: 1}],
        track_aecrire: %{current_coup: %{trous: %{white: 0, black: 0}}}
      })

    assert trictrac.track_aecrire.current_coup.trous == %{white: 4, black: 1}
    assert trictrac.track_aecrire.marques == %{white: 0, black: 0}
  end

  test "classique trous gain queues reprise and tenir advances to the opponent" do
    engine = prepare_classique_reprise_engine("tt-classique-tenir")

    assert {:ok, engine} = Engine.confirm(engine, "nick", "tab-a")
    snapshot = Engine.snapshot(engine)

    assert snapshot["pending_turn_decision"]["key"] == "reprise"

    assert snapshot["pending_turn_decision"]["prompt"] ==
             "Choose whether to continue the game or take a reprise."

    assert get_in(snapshot, ["trictrac", "turn_event_queue", Access.at(0), "key"]) == "reprise"
    assert get_in(snapshot, ["trictrac", "score", Access.at(0), "trous"]) == 2

    assert Enum.any?(get_in(snapshot, ["trictrac", "score_history"]), fn event ->
             event["source"] == "REMPLISSAGE_GRAND" and event["points"] == 12 and
               event["trous_delta"] == 2
           end)

    assert {:ok, engine} = Engine.submit_turn_decision(engine, "tenir", "nick", "tab-a")
    snapshot = Engine.snapshot(engine)

    assert snapshot["pending_turn_decision"] == nil
    assert snapshot["turn"]["color"] == "black"
    assert snapshot["turn"]["number"] == 2
    assert get_in(snapshot, ["trictrac", "score", Access.at(0), "trous"]) == 2
    assert Enum.at(snapshot["board"]["points"], 17)["pieces"] == ["white", "white"]
  end

  test "classique s'en aller resets the board and keeps the same player on reprise" do
    engine = prepare_classique_reprise_engine("tt-classique-reprise")

    assert {:ok, engine} = Engine.confirm(engine, "nick", "tab-a")
    assert {:ok, engine} = Engine.submit_turn_decision(engine, "s'en aller", "nick", "tab-a")

    snapshot = Engine.snapshot(engine)

    assert snapshot["pending_turn_decision"] == nil
    assert snapshot["turn"]["color"] == "white"
    assert snapshot["turn"]["number"] == 2
    assert get_in(snapshot, ["trictrac", "score", Access.at(0), "trous"]) == 2
    assert get_in(snapshot, ["trictrac", "opening", "releve_count"]) == 1
    assert get_in(snapshot, ["trictrac", "score_history"]) |> length() == 1
    assert Enum.at(snapshot["board"]["points"], 23)["pieces"] == List.duplicate("white", 15)
    assert Enum.at(snapshot["board"]["points"], 0)["pieces"] == List.duplicate("black", 15)
  end

  test "classique confirm scores conservation and sortie from the finalized event stream" do
    engine = Engine.new("tt-score", "trictrac_classique")
    assert {:ok, engine, _} = Engine.join(engine, "nick", "tab-a")
    assert {:ok, engine, _} = Engine.join(engine, "jane", "tab-b")

    start_points =
      Enum.map(0..23, fn index ->
        cond do
          index in 12..23 -> %{white: 2, black: 0}
          index == 0 -> %{white: 1, black: 0}
          true -> %{white: 0, black: 0}
        end
      end)

    end_points =
      Enum.map(0..23, fn index ->
        cond do
          index in 12..23 -> %{white: 2, black: 0}
          true -> %{white: 0, black: 0}
        end
      end)

    start_board = %{engine.board | points: start_points, outside: %{white: 14, black: 0}}
    end_board = %{engine.board | points: end_points, outside: %{white: 15, black: 0}}
    dice = %{values: [6, 5], moves: [6, 5], moves_left: [], moves_played: [6]}

    trictrac =
      Backgammon.Rules.Trictrac.Classique.begin_turn(
        engine.trictrac,
        start_board,
        engine.variant,
        :white,
        dice
      )

    runtime =
      engine.runtime
      |> Map.put(:trictrac, trictrac)
      |> Map.put(:board, end_board)
      |> Map.put(:dice, dice)

    engine = %{
      engine
      | runtime: runtime,
        trictrac: trictrac,
        board: end_board,
        turn_color: :white,
        dice: dice
    }

    assert {:ok, engine} = Engine.confirm(engine, "nick", "tab-a")
    snapshot = Engine.snapshot(engine)
    assert get_in(snapshot, ["trictrac", "score", Access.at(0), "trous"]) == 2

    assert Enum.sort(get_in(snapshot, ["trictrac", "last_events"])) ==
             Enum.sort([
               "coin battu",
               "conservation grand jan",
               "conservation petit jan",
               "sortie"
             ])

    assert Enum.map(
             get_in(snapshot, ["trictrac", "turn", "obligations", "must_conserve"]),
             & &1["key"]
           ) == ["petit", "grand"]

    sources =
      get_in(snapshot, ["trictrac", "score_history"])
      |> Enum.map(& &1["source"])

    assert "COIN_BATTU" in sources
    assert "CONSERVATION_GRAND" in sources
    assert "CONSERVATION_PETIT" in sources
    assert "SORTIE" in sources
    assert snapshot["turn"]["color"] == "white"
    assert Enum.at(snapshot["board"]["points"], 23)["pieces"] == List.duplicate("white", 15)
  end

  test "classique awards conservation par privilege on jan de retour when sortie breaks the table" do
    engine = Engine.new("tt-retour-privilege", "trictrac_classique")
    assert {:ok, engine, _} = Engine.join(engine, "nick", "tab-a")
    assert {:ok, engine, _} = Engine.join(engine, "jane", "tab-b")

    start_points =
      Enum.map(0..23, fn index ->
        cond do
          index == 0 -> %{white: 2, black: 0}
          index in 1..5 -> %{white: 2, black: 0}
          true -> %{white: 0, black: 0}
        end
      end)

    end_points =
      Enum.map(0..23, fn index ->
        cond do
          index == 0 -> %{white: 1, black: 0}
          index in 1..5 -> %{white: 2, black: 0}
          true -> %{white: 0, black: 0}
        end
      end)

    start_board = %{engine.board | points: start_points, outside: %{white: 14, black: 0}}
    end_board = %{engine.board | points: end_points, outside: %{white: 15, black: 0}}
    dice = %{values: [1, 2], moves: [1, 2], moves_left: [], moves_played: [1]}

    trictrac =
      Backgammon.Rules.Trictrac.Classique.begin_turn(
        engine.trictrac,
        start_board,
        engine.variant,
        :white,
        dice
      )

    runtime =
      engine.runtime
      |> Map.put(:trictrac, trictrac)
      |> Map.put(:board, end_board)
      |> Map.put(:dice, dice)

    engine = %{
      engine
      | runtime: runtime,
        trictrac: trictrac,
        board: end_board,
        turn_color: :white,
        dice: dice
    }

    assert {:ok, engine} = Engine.confirm(engine, "nick", "tab-a")
    snapshot = Engine.snapshot(engine)

    assert Enum.sort(get_in(snapshot, ["trictrac", "last_events"])) ==
             Enum.sort(["conservation jan de retour", "sortie"])

    assert Enum.any?(get_in(snapshot, ["trictrac", "score_history"]), fn event ->
             event["source"] == "CONSERVATION_RETOUR" and
               event["metadata"]["mode"] == "privilege" and
               event["metadata"]["resolution"] == "conservation_by_privilege"
           end)
  end

  test "trictrac counts three-way remplissage in score metadata" do
    engine = Engine.new("tt-remplissage-3", "trictrac_classique")
    assert {:ok, engine, _} = Engine.join(engine, "nick", "tab-a")
    assert {:ok, engine, _} = Engine.join(engine, "jane", "tab-b")

    start_points =
      Enum.map(0..23, fn index ->
        cond do
          index in 12..16 -> %{white: 2, black: 0}
          index == 17 -> %{white: 1, black: 0}
          index in 18..20 -> %{white: 1, black: 0}
          true -> %{white: 0, black: 0}
        end
      end)

    end_points =
      Enum.map(0..23, fn index ->
        cond do
          index in 12..17 -> %{white: 2, black: 0}
          index in 19..20 -> %{white: 1, black: 0}
          true -> %{white: 0, black: 0}
        end
      end)

    start_board = %{engine.board | points: start_points}
    end_board = %{engine.board | points: end_points}
    dice = %{values: [2, 1], moves: [2, 1], moves_left: [], moves_played: [1]}

    trictrac =
      Backgammon.Rules.Trictrac.Classique.begin_turn(
        engine.trictrac,
        start_board,
        engine.variant,
        :white,
        dice
      )

    runtime =
      engine.runtime
      |> Map.put(:trictrac, trictrac)
      |> Map.put(:board, end_board)
      |> Map.put(:dice, dice)

    engine = %{
      engine
      | runtime: runtime,
        trictrac: trictrac,
        board: end_board,
        turn_color: :white,
        dice: dice
    }

    assert {:ok, engine} = Engine.confirm(engine, "nick", "tab-a")
    snapshot = Engine.snapshot(engine)

    assert Enum.any?(get_in(snapshot, ["trictrac", "score_history"]), fn event ->
             event["label"] == "remplissage grand jan" and
               event["metadata"]["ways"] == 3 and
               event["metadata"]["resolution"] == "earned_now"
           end)
  end

  test "trictrac scores coin battu a faux to the opponent" do
    engine = Engine.new("tt-coin-faux", "trictrac_classique")
    assert {:ok, engine, _} = Engine.join(engine, "nick", "tab-a")
    assert {:ok, engine, _} = Engine.join(engine, "jane", "tab-b")

    start_points =
      Enum.map(0..23, fn index ->
        cond do
          index == 12 -> %{white: 2, black: 0}
          index == 16 -> %{white: 1, black: 0}
          index == 20 -> %{white: 1, black: 0}
          index == 13 -> %{white: 0, black: 2}
          index == 14 -> %{white: 0, black: 2}
          true -> %{white: 0, black: 0}
        end
      end)

    end_points =
      Enum.map(0..23, fn index ->
        cond do
          index == 12 -> %{white: 2, black: 0}
          index == 16 -> %{white: 1, black: 0}
          index == 19 -> %{white: 1, black: 0}
          index == 13 -> %{white: 0, black: 2}
          index == 14 -> %{white: 0, black: 2}
          true -> %{white: 0, black: 0}
        end
      end)

    start_board = %{engine.board | points: start_points}
    end_board = %{engine.board | points: end_points}
    dice = %{values: [3, 2], moves: [3, 2], moves_left: [], moves_played: [1]}

    trictrac =
      Backgammon.Rules.Trictrac.Classique.begin_turn(
        engine.trictrac,
        start_board,
        engine.variant,
        :white,
        dice
      )

    runtime =
      engine.runtime
      |> Map.put(:trictrac, trictrac)
      |> Map.put(:board, end_board)
      |> Map.put(:dice, dice)

    engine = %{
      engine
      | runtime: runtime,
        trictrac: trictrac,
        board: end_board,
        turn_color: :white,
        dice: dice
    }

    assert {:ok, engine} = Engine.confirm(engine, "nick", "tab-a")
    snapshot = Engine.snapshot(engine)

    assert "coin battu a faux" in get_in(snapshot, ["trictrac", "last_events"])

    assert Enum.any?(get_in(snapshot, ["trictrac", "score_history"]), fn event ->
             event["label"] == "coin battu a faux" and event["beneficiary"] == "black" and
               event["metadata"]["mode"] == "a_faux" and
               event["metadata"]["resolution"] == "opponent_beneficiary"
           end)
  end

  test "trictrac coin battu can use surcases already sitting on your own coin" do
    engine = Engine.new("tt-coin-surcase", "trictrac_classique")
    assert {:ok, engine, _} = Engine.join(engine, "nick", "tab-a")
    assert {:ok, engine, _} = Engine.join(engine, "jane", "tab-b")

    start_points =
      Enum.map(0..23, fn index ->
        cond do
          index == 12 -> %{white: 4, black: 0}
          index == 5 -> %{white: 1, black: 0}
          true -> %{white: 0, black: 0}
        end
      end)

    end_points =
      Enum.map(0..23, fn index ->
        cond do
          index == 12 -> %{white: 4, black: 0}
          index == 4 -> %{white: 1, black: 0}
          true -> %{white: 0, black: 0}
        end
      end)

    start_board = %{engine.board | points: start_points}
    end_board = %{engine.board | points: end_points}
    dice = %{values: [1, 1], moves: [1, 1], moves_left: [], moves_played: [1]}

    trictrac =
      Backgammon.Rules.Trictrac.Classique.begin_turn(
        engine.trictrac,
        start_board,
        engine.variant,
        :white,
        dice
      )

    runtime =
      engine.runtime
      |> Map.put(:trictrac, trictrac)
      |> Map.put(:board, end_board)
      |> Map.put(:dice, dice)

    engine = %{
      engine
      | runtime: runtime,
        trictrac: trictrac,
        board: end_board,
        turn_color: :white,
        dice: dice
    }

    assert {:ok, engine} = Engine.confirm(engine, "nick", "tab-a")
    snapshot = Engine.snapshot(engine)

    assert "coin battu" in get_in(snapshot, ["trictrac", "last_events"])

    assert Enum.any?(get_in(snapshot, ["trictrac", "score_history"]), fn event ->
             event["label"] == "coin battu" and event["beneficiary"] == "white" and
               event["points"] == 6 and event["metadata"]["mode"] == "a_vrai"
           end)
  end

  test "trictrac coin battu does not count the two foundation men on your own coin twice" do
    engine = Engine.new("tt-coin-foundation", "trictrac_classique")
    assert {:ok, engine, _} = Engine.join(engine, "nick", "tab-a")
    assert {:ok, engine, _} = Engine.join(engine, "jane", "tab-b")

    start_points =
      Enum.map(0..23, fn index ->
        cond do
          index == 12 -> %{white: 3, black: 0}
          index == 5 -> %{white: 1, black: 0}
          true -> %{white: 0, black: 0}
        end
      end)

    end_points =
      Enum.map(0..23, fn index ->
        cond do
          index == 12 -> %{white: 3, black: 0}
          index == 4 -> %{white: 1, black: 0}
          true -> %{white: 0, black: 0}
        end
      end)

    start_board = %{engine.board | points: start_points}
    end_board = %{engine.board | points: end_points}
    dice = %{values: [1, 1], moves: [1, 1], moves_left: [], moves_played: [1]}

    trictrac =
      Backgammon.Rules.Trictrac.Classique.begin_turn(
        engine.trictrac,
        start_board,
        engine.variant,
        :white,
        dice
      )

    runtime =
      engine.runtime
      |> Map.put(:trictrac, trictrac)
      |> Map.put(:board, end_board)
      |> Map.put(:dice, dice)

    engine = %{
      engine
      | runtime: runtime,
        trictrac: trictrac,
        board: end_board,
        turn_color: :white,
        dice: dice
    }

    assert {:ok, engine} = Engine.confirm(engine, "nick", "tab-a")
    snapshot = Engine.snapshot(engine)

    refute "coin battu" in get_in(snapshot, ["trictrac", "last_events"])

    refute Enum.any?(get_in(snapshot, ["trictrac", "score_history"]), fn event ->
             event["label"] == "coin battu"
           end)
  end

  test "trictrac does not award impuissance outside conservation contexts" do
    engine = Engine.new("tt-imp-none", "trictrac_classique")
    assert {:ok, engine, _} = Engine.join(engine, "nick", "tab-a")
    assert {:ok, engine, _} = Engine.join(engine, "jane", "tab-b")

    start_points =
      Enum.map(0..23, fn index ->
        cond do
          index == 12 -> %{white: 2, black: 0}
          index == 6 -> %{white: 0, black: 2}
          true -> %{white: 0, black: 0}
        end
      end)

    start_board = %{engine.board | points: start_points}
    dice = %{values: [6, 1], moves: [6, 1], moves_left: [], moves_played: [1]}

    trictrac =
      Backgammon.Rules.Trictrac.Classique.begin_turn(
        engine.trictrac,
        start_board,
        engine.variant,
        :white,
        dice
      )

    runtime =
      engine.runtime
      |> Map.put(:trictrac, trictrac)
      |> Map.put(:board, start_board)
      |> Map.put(:dice, dice)

    engine = %{
      engine
      | runtime: runtime,
        trictrac: trictrac,
        board: start_board,
        turn_color: :white,
        dice: dice
    }

    assert {:ok, engine} = Engine.confirm(engine, "nick", "tab-a")
    snapshot = Engine.snapshot(engine)
    refute "impuissance" in get_in(snapshot, ["trictrac", "last_events"])
  end

  test "trictrac pile de misere can conserve on a later still-blocked turn" do
    engine = Engine.new("tt-pile", "trictrac_classique")
    assert {:ok, engine, _} = Engine.join(engine, "nick", "tab-a")
    assert {:ok, engine, _} = Engine.join(engine, "jane", "tab-b")

    points =
      Enum.map(0..23, fn index ->
        cond do
          index == 12 -> %{white: 15, black: 0}
          index == 6 -> %{white: 0, black: 2}
          index == 7 -> %{white: 0, black: 2}
          true -> %{white: 0, black: 0}
        end
      end)

    board = %{engine.board | points: points}
    dice = %{values: [6, 5], moves: [6, 5], moves_left: [], moves_played: []}

    trictrac =
      Backgammon.Rules.Trictrac.Classique.begin_turn(
        engine.trictrac,
        board,
        engine.variant,
        :white,
        dice
      )

    runtime =
      engine.runtime
      |> Map.put(:trictrac, trictrac)
      |> Map.put(:board, board)
      |> Map.put(:dice, dice)

    engine = %{
      engine
      | runtime: runtime,
        trictrac: trictrac,
        board: board,
        turn_color: :white,
        dice: dice
    }

    assert {:ok, engine} = Engine.confirm(engine, "nick", "tab-a")
    snapshot = Engine.snapshot(engine)
    refute "pile de misere" in get_in(snapshot, ["trictrac", "last_events"])

    trictrac =
      Backgammon.Rules.Trictrac.Classique.begin_turn(
        engine.trictrac,
        board,
        engine.variant,
        :white,
        dice
      )

    runtime =
      engine.runtime
      |> Map.put(:trictrac, trictrac)
      |> Map.put(:board, board)
      |> Map.put(:dice, dice)

    engine = %{
      engine
      | runtime: runtime,
        trictrac: trictrac,
        board: board,
        turn_color: :white,
        dice: dice
    }

    assert {:ok, engine} = Engine.confirm(engine, "nick", "tab-a")
    snapshot = Engine.snapshot(engine)
    assert "pile de misere" in get_in(snapshot, ["trictrac", "last_events"])

    assert Enum.any?(get_in(snapshot, ["trictrac", "score_history"]), fn event ->
             event["label"] == "pile de misere" and event["metadata"]["mode"] == "conservation"
           end)
  end

  test "toc own-die scoring turn awards one hole and queues reprise" do
    engine = Engine.new("toc-settle", "toc")
    assert {:ok, engine, _} = Engine.join(engine, "nick", "tab-a")
    assert {:ok, engine, _} = Engine.join(engine, "jane", "tab-b")

    assert {:ok, engine} =
             Engine.submit_match_options(
               engine,
               %{"holeTarget" => "7", "doublesMode" => "off"},
               "nick",
               "tab-a"
             )

    start_points =
      Enum.map(0..23, fn index ->
        cond do
          index == 0 -> %{white: 1, black: 0}
          true -> %{white: 0, black: 0}
        end
      end)

    end_points =
      Enum.map(0..23, fn _ ->
        %{white: 0, black: 0}
      end)

    start_board = %{engine.board | points: start_points, outside: %{white: 14, black: 0}}
    end_board = %{engine.board | points: end_points, outside: %{white: 15, black: 0}}
    dice = %{values: [1, 2], moves: [1, 2], moves_left: [], moves_played: [1]}

    trictrac =
      Backgammon.Rules.Trictrac.Classique.begin_turn(
        %{engine.trictrac | score: [%{points: 8, trous: 0}, %{points: 0, trous: 0}]},
        start_board,
        engine.variant,
        :white,
        dice
      )

    runtime =
      engine.runtime
      |> Map.put(:trictrac, trictrac)
      |> Map.put(:board, end_board)
      |> Map.put(:dice, dice)

    engine = %{
      engine
      | runtime: runtime,
        trictrac: trictrac,
        board: end_board,
        turn_color: :white,
        dice: dice
    }

    assert {:ok, engine} = Engine.confirm(engine, "nick", "tab-a")
    snapshot = Engine.snapshot(engine)

    assert snapshot["match"]["score"]["white"] == 1
    assert snapshot["match"]["winner"] == nil
    assert snapshot["pending_turn_decision"]["key"] == "reprise"
    assert snapshot["turn"]["color"] == "white"
    assert Enum.at(snapshot["board"]["points"], 0)["pieces"] == []
  end

  test "toc s'en aller resets the board and preserves hole score" do
    engine = Engine.new("toc-reprise", "toc")
    assert {:ok, engine, _} = Engine.join(engine, "nick", "tab-a")
    assert {:ok, engine, _} = Engine.join(engine, "jane", "tab-b")

    assert {:ok, engine} =
             Engine.submit_match_options(
               engine,
               %{"holeTarget" => "7", "doublesMode" => "off"},
               "nick",
               "tab-a"
             )

    start_points =
      Enum.map(0..23, fn index ->
        if index == 0, do: %{white: 1, black: 0}, else: %{white: 0, black: 0}
      end)

    end_points = Enum.map(0..23, fn _ -> %{white: 0, black: 0} end)
    start_board = %{engine.board | points: start_points, outside: %{white: 14, black: 0}}
    end_board = %{engine.board | points: end_points, outside: %{white: 15, black: 0}}
    dice = %{values: [1, 2], moves: [1, 2], moves_left: [], moves_played: [1]}

    trictrac =
      Backgammon.Rules.Trictrac.Classique.begin_turn(
        %{engine.trictrac | score: [%{points: 8, trous: 0}, %{points: 0, trous: 0}]},
        start_board,
        engine.variant,
        :white,
        dice
      )

    runtime =
      engine.runtime
      |> Map.put(:trictrac, trictrac)
      |> Map.put(:board, end_board)
      |> Map.put(:dice, dice)

    engine = %{
      engine
      | runtime: runtime,
        trictrac: trictrac,
        board: end_board,
        turn_color: :white,
        dice: dice
    }

    assert {:ok, engine} = Engine.confirm(engine, "nick", "tab-a")
    assert {:ok, engine} = Engine.submit_turn_decision(engine, "s'en aller", "nick", "tab-a")
    snapshot = Engine.snapshot(engine)

    assert snapshot["pending_turn_decision"] == nil
    assert snapshot["turn"]["color"] == "white"
    assert snapshot["turn"]["number"] == 2
    assert snapshot["match"]["score"]["white"] == 1
    assert Enum.at(snapshot["board"]["points"], 23)["pieces"] == List.duplicate("white", 15)
  end

  test "plein confirm rejects breaking a required grand jan conservation" do
    engine = Engine.new("plein-conserve", "plein")
    assert {:ok, engine, _} = Engine.join(engine, "nick", "tab-a")
    assert {:ok, engine, _} = Engine.join(engine, "jane", "tab-b")

    start_points =
      Enum.map(0..23, fn index ->
        cond do
          index == 17 -> %{white: 4, black: 0}
          index in 12..16 -> %{white: 2, black: 0}
          true -> %{white: 0, black: 0}
        end
      end)

    end_points =
      Enum.map(0..23, fn index ->
        cond do
          index == 17 -> %{white: 3, black: 0}
          index == 16 -> %{white: 3, black: 0}
          index == 12 -> %{white: 1, black: 0}
          index == 11 -> %{white: 1, black: 0}
          index in 13..15 -> %{white: 2, black: 0}
          true -> %{white: 0, black: 0}
        end
      end)

    start_board = %{engine.board | points: start_points}
    end_board = %{engine.board | points: end_points}
    dice = %{values: [1, 1], moves: [1, 1], moves_left: [], moves_played: [1, 1]}

    trictrac =
      Backgammon.Rules.Trictrac.Classique.begin_turn(
        engine.trictrac,
        start_board,
        engine.variant,
        :white,
        dice
      )

    runtime =
      engine.runtime
      |> Map.put(:board, end_board)
      |> Map.put(:trictrac, trictrac)
      |> Map.put(:dice, dice)

    engine = %{
      engine
      | runtime: runtime,
        board: end_board,
        trictrac: trictrac,
        turn_color: :white,
        dice: dice
    }

    assert {:error, "Turn obligations not fulfilled."} = Engine.confirm(engine, "nick", "tab-a")
  end

  test "plein confirm allows breaking petit jan shapes when no grand jan obligation is at stake" do
    engine = Engine.new("plein-petit-break", "plein")
    assert {:ok, engine, _} = Engine.join(engine, "nick", "tab-a")
    assert {:ok, engine, _} = Engine.join(engine, "jane", "tab-b")

    start_points =
      Enum.map(0..23, fn index ->
        cond do
          index in 18..23 -> %{white: 2, black: 0}
          true -> %{white: 0, black: 0}
        end
      end)

    end_points =
      Enum.map(0..23, fn index ->
        cond do
          index == 17 -> %{white: 2, black: 0}
          index == 18 -> %{white: 1, black: 0}
          index == 19 -> %{white: 1, black: 0}
          index in 20..23 -> %{white: 2, black: 0}
          true -> %{white: 0, black: 0}
        end
      end)

    start_board = %{engine.board | points: start_points}
    end_board = %{engine.board | points: end_points}
    dice = %{values: [2, 1], moves: [2, 1], moves_left: [], moves_played: [2, 1]}

    trictrac =
      Backgammon.Rules.Trictrac.Classique.begin_turn(
        engine.trictrac,
        start_board,
        engine.variant,
        :white,
        dice
      )

    runtime =
      engine.runtime
      |> Map.put(:board, end_board)
      |> Map.put(:trictrac, trictrac)
      |> Map.put(:dice, dice)

    engine = %{
      engine
      | runtime: runtime,
        board: end_board,
        trictrac: trictrac,
        turn_color: :white,
        dice: dice
    }

    assert {:ok, _engine} = Engine.confirm(engine, "nick", "tab-a")
  end

  test "trictrac takes the empty coin de repos by puissance onto your own coin" do
    engine = Engine.new("tt-coin", "trictrac_classique")
    assert {:ok, engine, _} = Engine.join(engine, "nick", "tab-a")
    assert {:ok, engine, _} = Engine.join(engine, "jane", "tab-b")

    points =
      Enum.map(0..23, fn index ->
        cond do
          index == 17 -> %{white: 2, black: 0}
          true -> %{white: 0, black: 0}
        end
      end)

    board = %{engine.board | points: points}
    runtime = %{engine.runtime | board: board}

    engine = %{
      engine
      | runtime: runtime,
        board: board,
        turn_color: :white,
        dice: %{values: [6, 5], moves: [6, 5], moves_left: [6, 5], moves_played: []}
    }

    legal =
      Backgammon.Rules.RaceCore.legal_moves(
        Map.put(runtime, :dice, engine.dice),
        engine.variant,
        :white
      )

    assert Enum.any?(legal, &(&1.to == 12 and Map.get(&1, :count) == 2))
    refute Enum.any?(legal, &(&1.to == 11))
  end

  test "trictrac cannot take the coin de repos with a single man" do
    engine = Engine.new("tt-single-coin", "trictrac_classique")
    assert {:ok, engine, _} = Engine.join(engine, "nick", "tab-a")
    assert {:ok, engine, _} = Engine.join(engine, "jane", "tab-b")

    points =
      Enum.map(0..23, fn index ->
        cond do
          index == 18 -> %{white: 1, black: 0}
          true -> %{white: 0, black: 0}
        end
      end)

    board = %{engine.board | points: points}
    runtime = %{engine.runtime | board: board}

    engine = %{
      engine
      | runtime: runtime,
        board: board,
        turn_color: :white,
        dice: %{values: [6, 5], moves: [6, 5], moves_left: [6], moves_played: []}
    }

    legal =
      Backgammon.Rules.RaceCore.legal_moves(
        Map.put(runtime, :dice, engine.dice),
        engine.variant,
        :white
      )

    refute Enum.any?(legal, &(&1.to == 12))
  end

  test "trictrac cannot make surcases on its coin de repos by puissance" do
    engine = Engine.new("tt-power-surcase", "trictrac_classique")
    assert {:ok, engine, _} = Engine.join(engine, "nick", "tab-a")
    assert {:ok, engine, _} = Engine.join(engine, "jane", "tab-b")

    points =
      Enum.map(0..23, fn index ->
        cond do
          index == 17 -> %{white: 2, black: 0}
          index == 12 -> %{white: 2, black: 0}
          true -> %{white: 0, black: 0}
        end
      end)

    board = %{engine.board | points: points}
    runtime = %{engine.runtime | board: board}

    engine = %{
      engine
      | runtime: runtime,
        board: board,
        turn_color: :white,
        dice: %{values: [6, 5], moves: [6, 5], moves_left: [6], moves_played: []}
    }

    legal =
      Backgammon.Rules.RaceCore.legal_moves(
        Map.put(runtime, :dice, engine.dice),
        engine.variant,
        :white
      )

    refute Enum.any?(legal, &(&1.from == 17 and &1.to == 12))
  end

  test "trictrac synthetic mid-turn state with one checker on coin must immediately return it to two" do
    engine = Engine.new("tt-coin-follow-in", "trictrac_classique")
    assert {:ok, engine, _} = Engine.join(engine, "nick", "tab-a")
    assert {:ok, engine, _} = Engine.join(engine, "jane", "tab-b")

    points =
      Enum.map(0..23, fn index ->
        cond do
          index == 12 -> %{white: 1, black: 0}
          index == 18 -> %{white: 1, black: 0}
          index == 16 -> %{white: 1, black: 0}
          true -> %{white: 0, black: 0}
        end
      end)

    board = %{engine.board | points: points}
    runtime = %{engine.runtime | board: board}
    dice = %{values: [7, 6], moves: [7, 6], moves_left: [6], moves_played: [7]}

    legal =
      Backgammon.Rules.RaceCore.legal_moves(
        Map.put(runtime, :dice, dice),
        engine.variant,
        :white
      )

    assert Enum.any?(legal, &(&1.from == 18 and &1.to == 12 and &1.die == 6))
    refute Enum.any?(legal, &(&1.from == 16 and &1.to == 10 and &1.die == 6))
  end

  test "trictrac synthetic mid-turn state with one checker on coin may resolve to zero or back to two" do
    engine = Engine.new("tt-coin-follow-out", "trictrac_classique")
    assert {:ok, engine, _} = Engine.join(engine, "nick", "tab-a")
    assert {:ok, engine, _} = Engine.join(engine, "jane", "tab-b")

    points =
      Enum.map(0..23, fn index ->
        cond do
          index == 12 -> %{white: 1, black: 0}
          index == 15 -> %{white: 1, black: 0}
          index == 10 -> %{white: 1, black: 0}
          true -> %{white: 0, black: 0}
        end
      end)

    board = %{engine.board | points: points}
    runtime = %{engine.runtime | board: board}
    dice = %{values: [3, 2], moves: [3, 2], moves_left: [3], moves_played: [2]}

    legal =
      Backgammon.Rules.RaceCore.legal_moves(
        Map.put(runtime, :dice, dice),
        engine.variant,
        :white
      )

    assert Enum.any?(legal, &(&1.from == 12 and &1.to == 9 and &1.die == 3))
    assert Enum.any?(legal, &(&1.from == 15 and &1.to == 12 and &1.die == 3))
    refute Enum.any?(legal, &(&1.from == 10 and &1.to == 7 and &1.die == 3))
  end

  test "trictrac cannot confirm a turn that leaves exactly one checker on its own coin" do
    engine = Engine.new("tt-coin-confirm", "trictrac_classique")
    assert {:ok, engine, _} = Engine.join(engine, "nick", "tab-a")
    assert {:ok, engine, _} = Engine.join(engine, "jane", "tab-b")
    assert {:ok, engine} = reject_margot(engine)

    start_points =
      Enum.map(0..23, fn index ->
        cond do
          index == 12 -> %{white: 2, black: 0}
          index == 18 -> %{white: 1, black: 0}
          true -> %{white: 0, black: 0}
        end
      end)

    end_points =
      Enum.map(0..23, fn index ->
        cond do
          index == 12 -> %{white: 1, black: 0}
          index == 9 -> %{white: 1, black: 0}
          index == 18 -> %{white: 1, black: 0}
          true -> %{white: 0, black: 0}
        end
      end)

    start_board = %{engine.board | points: start_points}
    end_board = %{engine.board | points: end_points}
    dice = %{values: [3, 2], moves: [3, 2], moves_left: [], moves_played: [3, 2]}

    trictrac =
      Backgammon.Rules.Trictrac.Classique.begin_turn(
        engine.trictrac,
        start_board,
        engine.variant,
        :white,
        dice
      )

    runtime =
      engine.runtime
      |> Map.put(:board, end_board)
      |> Map.put(:trictrac, trictrac)
      |> Map.put(:dice, dice)

    engine = %{
      engine
      | runtime: runtime,
        board: end_board,
        trictrac: trictrac,
        turn_color: :white,
        turn_number: 1,
        dice: dice
    }

    assert {:error, "Coin de repos must end the turn with 0 or at least 2 checkers."} =
             Engine.confirm(engine, "nick", "tab-a")
  end

  test "plein still allows confirming a turn with a single checker on its own coin" do
    engine = Engine.new("plein-coin-confirm", "plein")
    assert {:ok, engine, _} = Engine.join(engine, "nick", "tab-a")
    assert {:ok, engine, _} = Engine.join(engine, "jane", "tab-b")

    start_points =
      Enum.map(0..23, fn index ->
        cond do
          index == 12 -> %{white: 1, black: 0}
          index in 18..23 -> %{white: 2, black: 0}
          true -> %{white: 0, black: 0}
        end
      end)

    board = %{engine.board | points: start_points}
    dice = %{values: [6, 5], moves: [6, 5], moves_left: [], moves_played: [6, 5]}

    trictrac =
      Backgammon.Rules.Trictrac.Classique.begin_turn(
        engine.trictrac,
        board,
        engine.variant,
        :white,
        dice
      )

    assert {:ok, _analysis} =
             Backgammon.Rules.Trictrac.Classique.validate_turn(
               trictrac,
               board,
               engine.variant,
               :white
             )
  end

  test "trictrac jan interdit blocks entering an opponent jan table they can still fill" do
    engine = Engine.new("tt-jan-interdit", "trictrac_classique")
    assert {:ok, engine, _} = Engine.join(engine, "nick", "tab-a")
    assert {:ok, engine, _} = Engine.join(engine, "jane", "tab-b")

    points =
      Enum.map(0..23, fn index ->
        cond do
          index == 6 -> %{white: 1, black: 0}
          index in 0..5 -> %{white: 0, black: 2}
          true -> %{white: 0, black: 0}
        end
      end)

    board = %{engine.board | points: points}
    runtime = %{engine.runtime | board: board}

    engine = %{
      engine
      | runtime: runtime,
        board: board,
        turn_color: :white,
        dice: %{values: [1, 1], moves: [1, 1], moves_left: [1], moves_played: []}
    }

    legal =
      Backgammon.Rules.RaceCore.legal_moves(
        Map.put(runtime, :dice, engine.dice),
        engine.variant,
        :white
      )

    refute Enum.any?(legal, &(&1.to == 5))
  end

  test "trictrac can move by the sum through an empty coin de repos" do
    engine = Engine.new("tt-empty-coin-rest", "trictrac_classique")
    assert {:ok, engine, _} = Engine.join(engine, "nick", "tab-a")
    assert {:ok, engine, _} = Engine.join(engine, "jane", "tab-b")

    points =
      Enum.map(0..23, fn index ->
        cond do
          index == 17 -> %{white: 1, black: 0}
          true -> %{white: 0, black: 0}
        end
      end)

    board = %{engine.board | points: points}
    runtime = %{engine.runtime | board: board}

    engine = %{
      engine
      | runtime: runtime,
        board: board,
        turn_color: :white,
        dice: %{values: [6, 2], moves: [6, 2], moves_left: [6, 2], moves_played: []}
    }

    legal =
      Backgammon.Rules.RaceCore.legal_moves(
        Map.put(runtime, :dice, engine.dice),
        engine.variant,
        :white
      )

    assert Enum.any?(legal, fn move ->
             move.from == 17 and move.to == 9 and move.die == 8 and
               move.coin_mode == :intermediate_coin and move.via == 11
           end)

    engine = %{engine | legal_moves: legal}
    snapshot = Engine.snapshot(engine)

    assert Enum.any?(snapshot["legal_moves"], fn move ->
             move["from"] == 17 and move["to"] == 9 and move["sequence"] == [6, 2] and
               move["via"] == 11
           end)
  end

  test "trictrac combined coin-rest move consumes both dice" do
    engine = Engine.new("tt-empty-coin-apply", "trictrac_classique")
    assert {:ok, engine, _} = Engine.join(engine, "nick", "tab-a")
    assert {:ok, engine, _} = Engine.join(engine, "jane", "tab-b")

    points =
      Enum.map(0..23, fn index ->
        cond do
          index == 17 -> %{white: 1, black: 0}
          true -> %{white: 0, black: 0}
        end
      end)

    board = %{engine.board | points: points}
    runtime = %{engine.runtime | board: board}
    dice = %{values: [6, 2], moves: [6, 2], moves_left: [6, 2], moves_played: []}

    legal_moves =
      Backgammon.Rules.RaceCore.legal_moves(Map.put(runtime, :dice, dice), engine.variant, :white)

    engine = %{
      engine
      | runtime: Map.put(runtime, :dice, dice) |> Map.put(:legal_moves, legal_moves),
        board: board,
        turn_color: :white,
        dice: dice,
        legal_moves: legal_moves
    }

    assert {:ok, moved} = Engine.move(engine, %{"from" => 17, "to" => 9}, "nick", "tab-a")
    assert moved.dice.moves_left == []
    assert moved.dice.moves_played == [6, 2]
    assert Enum.at(moved.board.points, 9).white == 1
  end

  test "trictrac blocks repos pour passer through an occupied passage" do
    engine = Engine.new("tt-passage-ferme", "trictrac_classique")
    assert {:ok, engine, _} = Engine.join(engine, "nick", "tab-a")
    assert {:ok, engine, _} = Engine.join(engine, "jane", "tab-b")

    points =
      Enum.map(0..23, fn index ->
        cond do
          index == 8 -> %{white: 1, black: 0}
          index == 6 -> %{white: 0, black: 1}
          true -> %{white: 0, black: 0}
        end
      end)

    board = %{engine.board | points: points}
    runtime = %{engine.runtime | board: board}

    engine = %{
      engine
      | runtime: runtime,
        board: board,
        turn_color: :white,
        dice: %{values: [2, 2], moves: [2, 2], moves_left: [2, 2], moves_played: []}
    }

    legal =
      Backgammon.Rules.RaceCore.legal_moves(
        Map.put(runtime, :dice, engine.dice),
        engine.variant,
        :white
      )

    refute Enum.any?(legal, fn move ->
             move.from == 8 and move.to == 4 and move.sequence == [2, 2] and move.via == 6
           end)
  end

  test "trictrac allows repos pour battre through a discovered passage" do
    engine = Engine.new("tt-passage-battre", "trictrac_classique")
    assert {:ok, engine, _} = Engine.join(engine, "nick", "tab-a")
    assert {:ok, engine, _} = Engine.join(engine, "jane", "tab-b")

    points =
      Enum.map(0..23, fn index ->
        cond do
          index == 8 -> %{white: 1, black: 0}
          index == 6 -> %{white: 0, black: 1}
          index == 4 -> %{white: 0, black: 1}
          true -> %{white: 0, black: 0}
        end
      end)

    board = %{engine.board | points: points}
    runtime = %{engine.runtime | board: board}
    dice = %{values: [2, 2], moves: [2, 2], moves_left: [2, 2], moves_played: []}

    legal_moves =
      Backgammon.Rules.RaceCore.legal_moves(Map.put(runtime, :dice, dice), engine.variant, :white)

    assert Enum.any?(legal_moves, fn move ->
             move.from == 8 and move.to == 4 and move.sequence == [2, 2] and move.via == 6 and
               move.hit? == true and move.intermediate_hit == 6
           end)

    engine = %{
      engine
      | runtime: Map.put(runtime, :dice, dice) |> Map.put(:legal_moves, legal_moves),
        board: board,
        turn_color: :white,
        dice: dice,
        legal_moves: legal_moves
    }

    assert {:ok, moved} =
             Engine.move(engine, %{"from" => 8, "to" => 4, "sequence" => [2, 2]}, "nick", "tab-a")

    assert moved.board.bar.black == 2
    assert Enum.at(moved.board.points, 4).white == 1
  end

  test "trictrac allows point sortant by the sum of two deficient dice" do
    engine = Engine.new("tt-point-sortant", "trictrac_classique")
    assert {:ok, engine, _} = Engine.join(engine, "nick", "tab-a")
    assert {:ok, engine, _} = Engine.join(engine, "jane", "tab-b")

    points =
      Enum.map(0..23, fn index ->
        cond do
          index == 2 -> %{white: 1, black: 0}
          true -> %{white: 0, black: 0}
        end
      end)

    board = %{engine.board | points: points}
    runtime = %{engine.runtime | board: board}

    engine = %{
      engine
      | runtime: runtime,
        board: board,
        turn_color: :white,
        dice: %{values: [2, 1], moves: [2, 1], moves_left: [2, 1], moves_played: []}
    }

    legal =
      Backgammon.Rules.RaceCore.legal_moves(
        Map.put(runtime, :dice, engine.dice),
        engine.variant,
        :white
      )

    refute Enum.any?(legal, &(&1.from == 2 and &1.to == "home" and &1.dice_used == [2]))

    assert Enum.any?(legal, fn move ->
             move.from == 2 and move.to == "home" and move.sequence == [2, 1] and
               move.coin_mode == :point_sortant
           end)
  end

  test "trictrac points excedants only bear the farthest checker" do
    engine = Engine.new("tt-point-excedant", "trictrac_classique")
    assert {:ok, engine, _} = Engine.join(engine, "nick", "tab-a")
    assert {:ok, engine, _} = Engine.join(engine, "jane", "tab-b")

    points =
      Enum.map(0..23, fn index ->
        cond do
          index == 3 -> %{white: 1, black: 0}
          index == 0 -> %{white: 1, black: 0}
          true -> %{white: 0, black: 0}
        end
      end)

    board = %{engine.board | points: points}
    runtime = %{engine.runtime | board: board}

    engine = %{
      engine
      | runtime: runtime,
        board: board,
        turn_color: :white,
        dice: %{values: [6, 6], moves: [6, 6], moves_left: [6], moves_played: []}
    }

    legal =
      Backgammon.Rules.RaceCore.legal_moves(
        Map.put(runtime, :dice, engine.dice),
        engine.variant,
        :white
      )

    assert Enum.any?(
             legal,
             &(&1.from == 3 and &1.to == "home" and &1.coin_mode == :sortie_excedant)
           )

    refute Enum.any?(legal, &(&1.from == 0 and &1.to == "home"))
  end

  test "trictrac points defaillants must still be played and cannot bear off alone" do
    engine = Engine.new("tt-point-defaillant", "trictrac_classique")
    assert {:ok, engine, _} = Engine.join(engine, "nick", "tab-a")
    assert {:ok, engine, _} = Engine.join(engine, "jane", "tab-b")

    points =
      Enum.map(0..23, fn index ->
        cond do
          index == 3 -> %{white: 1, black: 0}
          true -> %{white: 0, black: 0}
        end
      end)

    board = %{engine.board | points: points}
    runtime = %{engine.runtime | board: board}

    engine = %{
      engine
      | runtime: runtime,
        board: board,
        turn_color: :white,
        dice: %{values: [2, 2], moves: [2, 2], moves_left: [2], moves_played: []}
    }

    legal =
      Backgammon.Rules.RaceCore.legal_moves(
        Map.put(runtime, :dice, engine.dice),
        engine.variant,
        :white
      )

    assert Enum.any?(legal, &(&1.from == 3 and &1.to == 1 and &1.die == 2))
    refute Enum.any?(legal, &(&1.from == 3 and &1.to == "home"))
  end

  test "trictrac confirm rejects breaking a conserved jan" do
    engine = Engine.new("tt-conserve", "trictrac_classique")
    assert {:ok, engine, _} = Engine.join(engine, "nick", "tab-a")
    assert {:ok, engine, _} = Engine.join(engine, "jane", "tab-b")

    start_points =
      Enum.map(0..23, fn index ->
        cond do
          index == 23 -> %{white: 4, black: 0}
          index in 18..22 -> %{white: 2, black: 0}
          true -> %{white: 0, black: 0}
        end
      end)

    end_points =
      Enum.map(0..23, fn index ->
        cond do
          index == 23 -> %{white: 3, black: 0}
          index == 22 -> %{white: 3, black: 0}
          index == 18 -> %{white: 1, black: 0}
          index == 17 -> %{white: 1, black: 0}
          index in 19..21 -> %{white: 2, black: 0}
          true -> %{white: 0, black: 0}
        end
      end)

    start_board = %{engine.board | points: start_points, outside: %{white: 0, black: 0}}
    end_board = %{engine.board | points: end_points, outside: %{white: 0, black: 0}}
    dice = %{values: [1, 1], moves: [1, 1], moves_left: [], moves_played: [1, 1]}

    trictrac =
      Backgammon.Rules.Trictrac.Classique.begin_turn(
        engine.trictrac,
        start_board,
        engine.variant,
        :white,
        dice
      )

    runtime =
      engine.runtime
      |> Map.put(:board, end_board)
      |> Map.put(:trictrac, trictrac)
      |> Map.put(:dice, dice)

    engine = %{
      engine
      | runtime: runtime,
        board: end_board,
        trictrac: trictrac,
        turn_color: :white,
        dice: dice
    }

    assert {:error, "Turn obligations not fulfilled."} = Engine.confirm(engine, "nick", "tab-a")
  end

  test "combine s'en aller keeps the turn and resets the board while preserving honneurs score" do
    engine = Engine.new("tt-combine", "trictrac_combine")
    assert {:ok, engine, _} = Engine.join(engine, "nick", "tab-a")
    assert {:ok, engine, _} = Engine.join(engine, "jane", "tab-b")

    assert {:ok, engine} = start_aecrire_variant(engine)

    start_points =
      Enum.map(0..23, fn index ->
        cond do
          index == 0 -> %{white: 1, black: 0}
          true -> %{white: 0, black: 0}
        end
      end)

    end_points =
      Enum.map(0..23, fn _ ->
        %{white: 0, black: 0}
      end)

    start_board = %{engine.board | points: start_points, outside: %{white: 14, black: 0}}
    end_board = %{engine.board | points: end_points, outside: %{white: 15, black: 0}}
    dice = %{values: [1, 2], moves: [1, 2], moves_left: [], moves_played: [1]}

    trictrac =
      engine.trictrac
      |> Map.put(:score, [%{points: 8, trous: 0}, %{points: 0, trous: 0}])
      |> Map.put(:suspension_state, %{
        suspended_track: "classique",
        frozen_by: :white,
        resume_pending: true
      })
      |> put_in([:track_classique_honneurs, :current_partie, :trous], %{white: 0, black: 0})
      |> Backgammon.Rules.Trictrac.Classique.begin_turn(
        start_board,
        engine.variant,
        :white,
        dice
      )

    runtime =
      engine.runtime
      |> Map.put(:trictrac, trictrac)
      |> Map.put(:board, end_board)
      |> Map.put(:dice, dice)

    engine = %{
      engine
      | runtime: runtime,
        trictrac: trictrac,
        board: end_board,
        turn_color: :white,
        dice: dice
    }

    assert {:ok, engine} = Engine.confirm(engine, "nick", "tab-a")
    assert {:ok, engine} = Engine.submit_turn_decision(engine, "s'en aller", "nick", "tab-a")
    snapshot = Engine.snapshot(engine)

    assert snapshot["pending_turn_decision"] == nil
    assert snapshot["turn"]["color"] == "white"
    assert get_in(snapshot, ["trictrac", "score", Access.at(0), "trous"]) == 2
    assert get_in(snapshot, ["trictrac", "suspension_state", "resume_pending"]) == false
    assert Enum.at(snapshot["board"]["points"], 23)["pieces"] == List.duplicate("white", 15)
  end

  test "combine reaching douze trous queues continuation instead of ending immediately" do
    engine = Engine.new("tt-combine-continue", "trictrac_combine")
    assert {:ok, engine, _} = Engine.join(engine, "nick", "tab-a")
    assert {:ok, engine, _} = Engine.join(engine, "jane", "tab-b")

    assert {:ok, engine} = start_aecrire_variant(engine)

    start_points =
      Enum.map(0..23, fn index ->
        cond do
          index == 0 -> %{white: 1, black: 0}
          true -> %{white: 0, black: 0}
        end
      end)

    end_points =
      Enum.map(0..23, fn _ ->
        %{white: 0, black: 0}
      end)

    start_board = %{engine.board | points: start_points, outside: %{white: 14, black: 0}}
    end_board = %{engine.board | points: end_points, outside: %{white: 15, black: 0}}
    dice = %{values: [1, 2], moves: [1, 2], moves_left: [], moves_played: [1]}

    trictrac =
      engine.trictrac
      |> Map.put(:score, [%{points: 8, trous: 11}, %{points: 0, trous: 0}])
      |> put_in([:track_classique_honneurs, :current_partie, :trous], %{white: 11, black: 0})
      |> Backgammon.Rules.Trictrac.Classique.begin_turn(
        start_board,
        engine.variant,
        :white,
        dice
      )

    runtime =
      engine.runtime
      |> Map.put(:trictrac, trictrac)
      |> Map.put(:board, end_board)
      |> Map.put(:dice, dice)

    engine = %{
      engine
      | runtime: runtime,
        trictrac: trictrac,
        board: end_board,
        turn_color: :white,
        dice: dice
    }

    assert {:ok, engine} = Engine.confirm(engine, "nick", "tab-a")
    snapshot = Engine.snapshot(engine)

    assert snapshot["match"]["is_over"] == false
    assert snapshot["pending_turn_decision"]["key"] == "reprise"

    assert Enum.map(get_in(snapshot, ["trictrac", "turn_event_queue"]), & &1["key"]) == [
             "reprise",
             "continuation",
             "suspension"
           ]
  end

  test "combine arreter after continuation ends the classique track cleanly" do
    engine = Engine.new("tt-combine-stop", "trictrac_combine")
    assert {:ok, engine, _} = Engine.join(engine, "nick", "tab-a")
    assert {:ok, engine, _} = Engine.join(engine, "jane", "tab-b")

    assert {:ok, engine} = start_aecrire_variant(engine)

    start_points =
      Enum.map(0..23, fn index ->
        cond do
          index == 0 -> %{white: 1, black: 0}
          true -> %{white: 0, black: 0}
        end
      end)

    end_points =
      Enum.map(0..23, fn _ ->
        %{white: 0, black: 0}
      end)

    start_board = %{engine.board | points: start_points, outside: %{white: 14, black: 0}}
    end_board = %{engine.board | points: end_points, outside: %{white: 15, black: 0}}
    dice = %{values: [1, 2], moves: [1, 2], moves_left: [], moves_played: [1]}

    trictrac =
      engine.trictrac
      |> Map.put(:score, [%{points: 8, trous: 11}, %{points: 0, trous: 0}])
      |> put_in([:track_classique_honneurs, :current_partie, :trous], %{white: 11, black: 0})
      |> Backgammon.Rules.Trictrac.Classique.begin_turn(
        start_board,
        engine.variant,
        :white,
        dice
      )

    runtime =
      engine.runtime
      |> Map.put(:trictrac, trictrac)
      |> Map.put(:board, end_board)
      |> Map.put(:dice, dice)

    engine = %{
      engine
      | runtime: runtime,
        trictrac: trictrac,
        board: end_board,
        turn_color: :white,
        dice: dice
    }

    assert {:ok, engine} = Engine.confirm(engine, "nick", "tab-a")
    assert {:ok, engine} = Engine.submit_turn_decision(engine, "tenir", "nick", "tab-a")
    assert {:ok, engine} = Engine.submit_turn_decision(engine, "arreter", "nick", "tab-a")
    snapshot = Engine.snapshot(engine)

    assert snapshot["match"]["is_over"] == true
    assert snapshot["match"]["winner"] == "white"
    assert snapshot["match"]["winner_kind"] == "trous"
  end

  test "combine settles honneurs only when continuation stops" do
    trictrac =
      Backgammon.Rules.Trictrac.Combine.ensure(%{
        score: [%{points: 0, trous: 11}, %{points: 0, trous: 0}]
      })
      |> put_in([:track_classique_honneurs, :current_partie, :trous], %{white: 11, black: 0})

    trictrac =
      Backgammon.Rules.Trictrac.Combine.record_turn(
        trictrac,
        :white,
        %{white: 1, black: 0},
        0
      )

    assert Backgammon.Rules.Trictrac.Combine.continuation_due?(trictrac, :white)
    assert trictrac.track_classique_honneurs.honneurs.white == 0

    trictrac =
      Backgammon.Rules.Trictrac.Combine.apply_continuation(
        trictrac,
        :white,
        "arreter"
      )

    assert trictrac.track_classique_honneurs.honneurs.white == 4
    assert trictrac.track_classique_honneurs.classes.white.quadruple == 1
    assert trictrac.track_classique_honneurs.winner == :white
  end

  test "combine carries surplus trous into the next honneurs partie" do
    trictrac =
      Backgammon.Rules.Trictrac.Combine.ensure(%{
        score: [%{points: 0, trous: 11}, %{points: 0, trous: 0}]
      })
      |> put_in([:track_classique_honneurs, :current_partie, :trous], %{white: 11, black: 0})

    trictrac =
      trictrac
      |> Backgammon.Rules.Trictrac.Combine.record_turn(:white, %{white: 3, black: 0}, 0)
      |> Backgammon.Rules.Trictrac.Combine.apply_continuation(:white, "arreter")

    assert trictrac.track_classique_honneurs.honneurs.white == 4
    assert trictrac.track_classique_honneurs.current_partie.trous == %{white: 2, black: 0}
    assert trictrac.track_classique_honneurs.current_partie.pending_result == nil
  end

  test "combine triple honneur only belongs to the player who entered second" do
    trictrac =
      Backgammon.Rules.Trictrac.Combine.ensure(%{
        score: [%{points: 0, trous: 8}, %{points: 0, trous: 0}]
      })
      |> put_in([:track_classique_honneurs, :current_partie, :trous], %{white: 8, black: 0})

    trictrac =
      trictrac
      |> Backgammon.Rules.Trictrac.Combine.record_turn(:black, %{white: 0, black: 1}, 0)
      |> Backgammon.Rules.Trictrac.Combine.record_turn(:white, %{white: 4, black: 0}, 0)
      |> Backgammon.Rules.Trictrac.Combine.apply_continuation(:white, "arreter")

    assert trictrac.track_classique_honneurs.classes.white.double == 1
    assert trictrac.track_classique_honneurs.classes.white.triple == 0
  end

  test "combine suspended track only resumes on a true releve move" do
    trictrac =
      Backgammon.Rules.Trictrac.Combine.ensure(%{
        suspension_state: %{suspended_track: "classique", frozen_by: :white, resume_pending: true}
      })

    still_suspended = Backgammon.Rules.Trictrac.Combine.maybe_resume(trictrac, 1, 1, false)
    assert still_suspended.suspension_state.resume_pending == true

    resumed = Backgammon.Rules.Trictrac.Combine.maybe_resume(trictrac, 1, 1, true)
    assert resumed.suspension_state.resume_pending == false
    assert resumed.suspension_state.suspended_track == nil
  end

  test "combine true releve clears a pending suspended track" do
    trictrac =
      Backgammon.Rules.Trictrac.Combine.ensure(%{
        score: [%{points: 0, trous: 2}, %{points: 0, trous: 0}],
        suspension_state: %{suspended_track: "classique", frozen_by: :white, resume_pending: true}
      })

    resumed = Backgammon.Rules.Trictrac.Combine.resume_on_true_releve(trictrac)

    assert Map.from_struct(resumed.suspension_state) == %{
             suspended_track: nil,
             frozen_by: nil,
             resume_pending: false
           }
  end

  test "combine ensure seeds a blank current partie from raw score on partial track state" do
    trictrac =
      Backgammon.Rules.Trictrac.Combine.ensure(%{
        score: [%{points: 0, trous: 5}, %{points: 0, trous: 2}],
        track_classique_honneurs: %{current_partie: %{trous: %{white: 0, black: 0}}},
        suspension_state: %{resume_pending: true}
      })

    assert trictrac.track_classique_honneurs.current_partie.trous == %{white: 5, black: 2}

    assert Map.from_struct(trictrac.suspension_state) == %{
             suspended_track: nil,
             frozen_by: nil,
             resume_pending: true
           }
  end

  test "toc doubles-on awards a double hole on a doubled scoring turn" do
    engine = Engine.new("toc-double-settle", "toc")
    assert {:ok, engine, _} = Engine.join(engine, "nick", "tab-a")
    assert {:ok, engine, _} = Engine.join(engine, "jane", "tab-b")

    assert {:ok, engine} =
             Engine.submit_match_options(
               engine,
               %{"holeTarget" => "7", "doublesMode" => "on"},
               "nick",
               "tab-a"
             )

    start_points =
      Enum.map(0..23, fn index ->
        cond do
          index == 0 -> %{white: 1, black: 0}
          true -> %{white: 0, black: 0}
        end
      end)

    end_points =
      Enum.map(0..23, fn _ ->
        %{white: 0, black: 0}
      end)

    start_board = %{engine.board | points: start_points, outside: %{white: 14, black: 0}}
    end_board = %{engine.board | points: end_points, outside: %{white: 15, black: 0}}
    dice = %{values: [1, 1], moves: [1, 1], moves_left: [], moves_played: [1]}

    trictrac =
      Backgammon.Rules.Trictrac.Classique.begin_turn(
        %{engine.trictrac | score: [%{points: 6, trous: 0}, %{points: 0, trous: 0}]},
        start_board,
        engine.variant,
        :white,
        dice
      )

    runtime =
      engine.runtime
      |> Map.put(:trictrac, trictrac)
      |> Map.put(:board, end_board)
      |> Map.put(:dice, dice)
      |> put_in([:variant_state, :last_roll_double], true)

    engine = %{
      engine
      | runtime: runtime,
        trictrac: trictrac,
        board: end_board,
        turn_color: :white,
        dice: dice
    }

    assert {:ok, engine} = Engine.confirm(engine, "nick", "tab-a")
    snapshot = Engine.snapshot(engine)

    assert snapshot["match"]["score"]["white"] == 2
    assert snapshot["match"]["winner"] == nil
    assert snapshot["pending_turn_decision"]["key"] == "reprise"
  end

  test "toc opponent-beneficiary scoring awards the hole without a reprise choice" do
    engine = Engine.new("toc-opponent-benefit", "toc")
    assert {:ok, engine, _} = Engine.join(engine, "nick", "tab-a")
    assert {:ok, engine, _} = Engine.join(engine, "jane", "tab-b")

    assert {:ok, engine} =
             Engine.submit_match_options(
               engine,
               %{"holeTarget" => "7", "doublesMode" => "off"},
               "nick",
               "tab-a"
             )

    start_points =
      Enum.map(0..23, fn index ->
        cond do
          index == 12 -> %{white: 2, black: 0}
          index == 16 -> %{white: 1, black: 0}
          index == 20 -> %{white: 1, black: 0}
          index == 13 -> %{white: 0, black: 2}
          index == 14 -> %{white: 0, black: 2}
          true -> %{white: 0, black: 0}
        end
      end)

    end_points =
      Enum.map(0..23, fn index ->
        cond do
          index == 12 -> %{white: 2, black: 0}
          index == 16 -> %{white: 1, black: 0}
          index == 19 -> %{white: 1, black: 0}
          index == 13 -> %{white: 0, black: 2}
          index == 14 -> %{white: 0, black: 2}
          true -> %{white: 0, black: 0}
        end
      end)

    start_board = %{engine.board | points: start_points}
    end_board = %{engine.board | points: end_points}
    dice = %{values: [3, 2], moves: [3, 2], moves_left: [], moves_played: [1]}

    trictrac =
      Backgammon.Rules.Trictrac.Classique.begin_turn(
        engine.trictrac,
        start_board,
        engine.variant,
        :white,
        dice
      )

    runtime =
      engine.runtime
      |> Map.put(:trictrac, trictrac)
      |> Map.put(:board, end_board)
      |> Map.put(:dice, dice)

    engine = %{
      engine
      | runtime: runtime,
        trictrac: trictrac,
        board: end_board,
        turn_color: :white,
        dice: dice
    }

    assert {:ok, engine} = Engine.confirm(engine, "nick", "tab-a")
    snapshot = Engine.snapshot(engine)

    assert snapshot["match"]["score"]["black"] == 1
    assert snapshot["pending_turn_decision"] == nil
    assert snapshot["turn"]["color"] == "black"
  end

  test "plein allows a single checker to occupy its own coin de repos" do
    engine = Engine.new("plein-single-coin", "plein")
    assert {:ok, engine, _} = Engine.join(engine, "nick", "tab-a")
    assert {:ok, engine, _} = Engine.join(engine, "jane", "tab-b")

    points =
      Enum.map(0..23, fn index ->
        cond do
          index == 17 -> %{white: 1, black: 0}
          true -> %{white: 0, black: 0}
        end
      end)

    board = %{engine.board | points: points}

    runtime =
      engine.runtime
      |> Map.put(:board, board)
      |> Map.put(:dice, %{values: [6, 5], moves: [6, 5], moves_left: [5], moves_played: [6]})

    legal =
      Backgammon.Rules.RaceCore.legal_moves(
        runtime,
        engine.variant,
        :white
      )

    assert Enum.any?(legal, &(&1.from == 17 and &1.to == 12 and &1.die == 5 and &1.count == 1))
  end

  test "plein does not generate sortie moves even from an exact bear-off point" do
    engine = Engine.new("plein-no-sortie", "plein")
    assert {:ok, engine, _} = Engine.join(engine, "nick", "tab-a")
    assert {:ok, engine, _} = Engine.join(engine, "jane", "tab-b")

    points =
      Enum.map(0..23, fn index ->
        if index == 0, do: %{white: 1, black: 0}, else: %{white: 0, black: 0}
      end)

    board = %{engine.board | points: points}

    runtime =
      engine.runtime
      |> Map.put(:board, board)
      |> Map.put(:dice, %{values: [1, 2], moves: [1, 2], moves_left: [1], moves_played: [2]})

    legal =
      Backgammon.Rules.RaceCore.legal_moves(
        runtime,
        engine.variant,
        :white
      )

    refute Enum.any?(legal, &(&1.to == "home"))
  end

  test "plein wins only from finalized grand jan events" do
    engine = Engine.new("plein-win", "plein")
    assert {:ok, engine, _} = Engine.join(engine, "nick", "tab-a")
    assert {:ok, engine, _} = Engine.join(engine, "jane", "tab-b")

    start_points =
      Enum.map(0..23, fn index ->
        cond do
          index in 12..16 -> %{white: 2, black: 0}
          index == 17 -> %{white: 1, black: 0}
          index in 18..20 -> %{white: 1, black: 0}
          true -> %{white: 0, black: 0}
        end
      end)

    end_points =
      Enum.map(0..23, fn index ->
        cond do
          index in 12..17 -> %{white: 2, black: 0}
          index in 19..20 -> %{white: 1, black: 0}
          true -> %{white: 0, black: 0}
        end
      end)

    start_board = %{engine.board | points: start_points}
    end_board = %{engine.board | points: end_points}
    dice = %{values: [2, 1], moves: [2, 1], moves_left: [], moves_played: [1]}

    trictrac =
      Backgammon.Rules.Trictrac.Classique.begin_turn(
        engine.trictrac,
        start_board,
        engine.variant,
        :white,
        dice
      )

    runtime =
      engine.runtime
      |> Map.put(:board, end_board)
      |> Map.put(:trictrac, trictrac)
      |> Map.put(:dice, dice)

    engine = %{
      engine
      | runtime: runtime,
        board: end_board,
        trictrac: trictrac,
        turn_color: :white,
        dice: dice
    }

    assert {:ok, engine} = Engine.confirm(engine, "nick", "tab-a")
    snapshot = Engine.snapshot(engine)

    assert snapshot["match"]["is_over"] == true
    assert snapshot["match"]["winner"] == "white"
    assert snapshot["match"]["winner_kind"] == "plein"
  end

  test "same display name can join from two tabs when client ids differ" do
    engine = Engine.new("selfplay", "backgammon")
    assert {:ok, engine, %{"color" => "white"}} = Engine.join(engine, "nick", "tab-a")
    assert {:ok, engine, %{"color" => "black"}} = Engine.join(engine, "nick", "tab-b")
    assert {:ok, engine} = Engine.roll(engine, "nick", "tab-a")
    assert length(engine.dice.values) in [2, 4]
  end

  test "engine roll uses the configured dice implementation" do
    Application.put_env(:backgammon, :dice_impl, DeterministicDice)

    engine = Engine.new("fixed-roll", "backgammon")
    assert {:ok, engine, _} = Engine.join(engine, "nick", "tab-a")
    assert {:ok, engine, _} = Engine.join(engine, "jane", "tab-b")
    assert {:ok, engine} = Engine.roll(engine, "nick", "tab-a")

    assert engine.dice.values == [4, 2]
    assert engine.dice.moves_left == [4, 2]
  end

  test "backgammon supports roll move and undo round trip" do
    engine = Engine.new("moves", "backgammon")
    assert {:ok, engine, _} = Engine.join(engine, "nick", "tab-a")
    assert {:ok, engine, _} = Engine.join(engine, "jane", "tab-b")
    assert {:ok, engine} = Engine.roll(engine, "nick", "tab-a")

    move = hd(engine.legal_moves)

    assert {:ok, moved} =
             Engine.move(engine, %{"from" => move.from, "to" => move.to}, "nick", "tab-a")

    assert length(moved.dice.moves_played) == 1

    assert {:ok, undone} = Engine.undo(moved, "nick", "tab-a")
    assert undone.dice.moves_played == []
  end

  test "tourne case requires options before play" do
    engine = Engine.new("tourne", "tourne_case")
    assert {:ok, engine, _} = Engine.join(engine, "nick", "tab-a")
    assert {:ok, engine, _} = Engine.join(engine, "jane", "tab-b")
    snapshot = Engine.snapshot(engine)

    assert snapshot["status"] == "awaiting_match_options"
    assert snapshot["pending_match_options"]["rule"] == "TourneCase"
  end

  test "tourne case starts with a higher-die opening roll after options" do
    Application.put_env(:backgammon, :dice_impl, SequenceDice)
    Process.put({SequenceDice, :values}, [2, 5])

    engine = Engine.new("tourne-opening", "tourne_case")
    assert {:ok, engine, _} = Engine.join(engine, "nick", "tab-a")
    assert {:ok, engine, _} = Engine.join(engine, "jane", "tab-b")

    assert {:ok, engine} =
             Engine.submit_match_options(engine, %{"doubleWin" => true}, "nick", "tab-a")

    snapshot = Engine.snapshot(engine)
    assert snapshot["status"] == "playing"
    assert snapshot["turn"] == nil
    assert snapshot["opening_roll"]["order"] == "highest"
    assert snapshot["opening_roll"]["rolls"] == %{"white" => nil, "black" => nil}

    assert {:ok, engine} = Engine.roll(engine, "nick", "tab-a")
    assert Engine.snapshot(engine)["opening_roll"]["rolls"]["white"] == 2

    assert {:ok, engine} = Engine.roll(engine, "jane", "tab-b")
    assert engine.turn_color == :black
    assert engine.turn_number == 1
    assert Engine.snapshot(engine)["opening_roll"] == nil
  end

  test "tourne case rerolls tied opening throws until a starter is found" do
    Application.put_env(:backgammon, :dice_impl, SequenceDice)
    Process.put({SequenceDice, :values}, [4, 4, 6, 1])

    engine = Engine.new("tourne-opening-tie", "tourne_case")
    assert {:ok, engine, _} = Engine.join(engine, "nick", "tab-a")
    assert {:ok, engine, _} = Engine.join(engine, "jane", "tab-b")

    assert {:ok, engine} =
             Engine.submit_match_options(engine, %{"doubleWin" => true}, "nick", "tab-a")

    assert {:ok, engine} = Engine.roll(engine, "nick", "tab-a")
    assert {:ok, engine} = Engine.roll(engine, "jane", "tab-b")
    assert engine.turn_color == nil
    assert Engine.snapshot(engine)["opening_roll"]["rolls"] == %{"white" => nil, "black" => nil}

    assert {:ok, engine} = Engine.roll(engine, "nick", "tab-a")
    assert {:ok, engine} = Engine.roll(engine, "jane", "tab-b")
    assert engine.turn_color == :white
    assert engine.turn_number == 1
  end

  test "host can submit toc options and start play" do
    engine = Engine.new("toc", "toc")
    assert {:ok, engine, _} = Engine.join(engine, "nick", "tab-a")
    assert {:ok, engine, _} = Engine.join(engine, "jane", "tab-b")

    assert {:ok, engine} =
             Engine.submit_match_options(
               engine,
               %{"holeTarget" => "7", "doublesMode" => "off"},
               "nick",
               "tab-a"
             )

    snapshot = Engine.snapshot(engine)
    assert snapshot["status"] == "playing"
    assert snapshot["match"]["length"] == 7
    assert snapshot["match"]["options"]["doublesMode"] == "off"
  end

  test "toc requires explicit target and doubles settings" do
    engine = Engine.new("toc", "toc")
    assert {:ok, engine, _} = Engine.join(engine, "nick", "tab-a")
    assert {:ok, engine, _} = Engine.join(engine, "jane", "tab-b")
    snapshot = Engine.snapshot(engine)

    assert snapshot["pending_match_options"]["rule"] == "Toc"
    assert Enum.any?(snapshot["pending_match_options"]["options"], &(&1["key"] == "holeTarget"))
    assert Enum.any?(snapshot["pending_match_options"]["options"], &(&1["key"] == "doublesMode"))
  end

  test "brade requires explicit match length" do
    engine = Engine.new("brade", "brade")
    assert {:ok, engine, _} = Engine.join(engine, "nick", "tab-a")
    assert {:ok, engine, _} = Engine.join(engine, "jane", "tab-b")
    snapshot = Engine.snapshot(engine)

    assert snapshot["pending_match_options"]["rule"] == "Brade"
    assert Enum.any?(snapshot["pending_match_options"]["options"], &(&1["key"] == "matchLength"))
  end

  test "tourne case can win double when all three men reach the coin first" do
    engine = Engine.new("tourne-win", "tourne_case")
    assert {:ok, engine, _} = Engine.join(engine, "nick", "tab-a")
    assert {:ok, engine, _} = Engine.join(engine, "jane", "tab-b")

    assert {:ok, engine} =
             Engine.submit_match_options(engine, %{"doubleWin" => true}, "nick", "tab-a")

    runtime = %{engine.runtime | positions: %{white: [11, 11, 11], black: [-1, -1, -1]}}
    board = runtime.board

    engine =
      %{
        engine
        | runtime: %{runtime | board: board},
          board: board,
          turn_color: :white,
          dice: %{values: [1, 1], moves: [1], moves_left: [], moves_played: [1]}
      }

    assert {:ok, engine} = Engine.confirm(engine, "nick", "tab-a")
    snapshot = Engine.snapshot(engine)
    assert snapshot["match"]["winner"] == "white"
    assert snapshot["match"]["winner_kind"] == "double"
  end

  test "tourne case settles as a single win when double win is disabled" do
    engine = Engine.new("tourne-single", "tourne_case")
    assert {:ok, engine, _} = Engine.join(engine, "nick", "tab-a")
    assert {:ok, engine, _} = Engine.join(engine, "jane", "tab-b")

    assert {:ok, engine} =
             Engine.submit_match_options(engine, %{"doubleWin" => false}, "nick", "tab-a")

    runtime = %{engine.runtime | positions: %{white: [11, 11, 11], black: [-1, -1, -1]}}
    board = runtime.board

    engine =
      %{
        engine
        | runtime: %{runtime | board: board},
          board: board,
          turn_color: :white,
          dice: %{values: [1, 1], moves: [1], moves_left: [], moves_played: [1]}
      }

    assert {:ok, engine} = Engine.confirm(engine, "nick", "tab-a")
    snapshot = Engine.snapshot(engine)
    assert snapshot["match"]["winner"] == "white"
    assert snapshot["match"]["winner_kind"] == "single"
  end

  test "tourne case only advances the front checker when moving another would pass" do
    runtime =
      Backgammon.Rules.TourneCase.new()
      |> Map.put(:positions, %{white: [0, 1, 2], black: [-1, -1, -1]})
      |> Map.put(:dice, %{values: [1, 1], moves: [1], moves_left: [1], moves_played: []})

    legal = Backgammon.Rules.TourneCase.legal_moves(runtime, :white)

    assert legal == [%{from: 2, to: 3, die: 1, piece_index: 2}]
  end

  test "tourne case lower-die-only play can force a non-hit" do
    runtime =
      Backgammon.Rules.TourneCase.new()
      |> Map.put(:positions, %{white: [0, 2, 5], black: [-1, -1, 3]})
      |> Map.put(:dice, %{values: [4, 3], moves: [3], moves_left: [3], moves_played: []})

    assert Backgammon.Rules.TourneCase.legal_moves(runtime, :white) == [
             %{from: 5, to: 8, die: 3, piece_index: 2}
           ]

    assert {:ok, runtime} =
             Backgammon.Rules.TourneCase.move(runtime, :white, %{"from" => 5, "to" => 8})

    assert runtime.positions.black == [-1, -1, 3]
    assert runtime.board.bar.black == 2
  end

  test "tourne case keeps advancing the same checker across turns when others trail behind" do
    runtime =
      Backgammon.Rules.TourneCase.new()
      |> Map.put(:positions, %{white: [-1, -1, -1], black: [-1, -1, -1]})
      |> Map.put(:dice, %{values: [5, 5], moves: [5], moves_left: [5], moves_played: []})

    assert {:ok, runtime} =
             Backgammon.Rules.TourneCase.move(runtime, :white, %{"from" => "bar", "to" => 4})

    runtime = %{runtime | dice: %{values: [1, 1], moves: [1], moves_left: [1], moves_played: []}}

    assert Backgammon.Rules.TourneCase.legal_moves(runtime, :white) == [
             %{from: 4, to: 5, die: 1, piece_index: 2}
           ]
  end

  test "tourne case rehydrates legacy position overrides and clears stale continuation ids" do
    runtime =
      Backgammon.Rules.TourneCase.new()
      |> Map.put(:pieces, %{
        white: [%{id: 0, position: -1}, %{id: 1, position: -1}, %{id: 2, position: -1}],
        black: [%{id: 0, position: -1}, %{id: 1, position: -1}, %{id: 2, position: -1}]
      })
      |> Map.put(:positions, %{white: [0, 1, 2], black: [-1, -1, -1]})
      |> Map.put(:forced_piece, %{white: 99, black: nil})
      |> Map.put(:dice, %{values: [1, 1], moves: [1], moves_left: [1], moves_played: []})

    legal = Backgammon.Rules.TourneCase.legal_moves(runtime, :white)

    assert legal == [%{from: 2, to: 3, die: 1, piece_index: 2}]
  end

  test "tourne case roll rehydrates legacy position overrides into checker identity" do
    Application.put_env(:backgammon, :dice_impl, DeterministicDice)

    runtime =
      Backgammon.Rules.TourneCase.new()
      |> Map.put(:pieces, %{
        white: [%{id: 0, position: -1}, %{id: 1, position: -1}, %{id: 2, position: -1}],
        black: [%{id: 0, position: -1}, %{id: 1, position: -1}, %{id: 2, position: -1}]
      })
      |> Map.put(:positions, %{white: [0, 1, 2], black: [-1, -1, -1]})

    runtime = Backgammon.Rules.TourneCase.roll(runtime)

    assert Enum.sort(Enum.map(runtime.pieces.white, & &1.position)) == [0, 1, 2]
    assert runtime.dice.moves_left == [2]
  end

  test "tourne case hit sends the opposing checker back into play" do
    runtime =
      Backgammon.Rules.TourneCase.new()
      |> Map.put(:positions, %{white: [-1, -1, 2], black: [-1, -1, 3]})
      |> Map.put(:dice, %{values: [1, 5], moves: [1], moves_left: [1], moves_played: []})

    assert {:ok, runtime} =
             Backgammon.Rules.TourneCase.move(runtime, :white, %{"from" => 2, "to" => 3})

    assert runtime.positions.black == [-1, -1, -1]
    assert runtime.board.bar.black == 3
  end

  test "tourne case coin checkers remain safe from hits" do
    runtime =
      Backgammon.Rules.TourneCase.new()
      |> Map.put(:positions, %{white: [-1, -1, 11], black: [-1, -1, 10]})
      |> Map.put(:dice, %{values: [1, 1], moves: [1], moves_left: [1], moves_played: []})

    assert {:ok, runtime} =
             Backgammon.Rules.TourneCase.move(runtime, :black, %{"from" => 13, "to" => "home"})

    assert runtime.positions.white == [-1, -1, 11]
    assert runtime.board.bar.white == 2
  end

  test "tourne case clears continuation state when the forced checker reaches the coin" do
    runtime =
      Backgammon.Rules.TourneCase.new()
      |> Map.put(:positions, %{white: [-1, -1, 10], black: [-1, -1, -1]})
      |> Map.put(:forced_piece, %{white: 2, black: nil})
      |> Map.put(:dice, %{values: [1, 1], moves: [1], moves_left: [1], moves_played: []})

    assert {:ok, runtime} =
             Backgammon.Rules.TourneCase.move(runtime, :white, %{"from" => 10, "to" => "home"})

    assert runtime.forced_piece.white == nil
  end

  test "tourne case clears continuation state when the forced checker is hit" do
    runtime =
      Backgammon.Rules.TourneCase.new()
      |> Map.put(:positions, %{white: [0, 2, 4], black: [-1, -1, 3]})
      |> Map.put(:forced_piece, %{white: 2, black: nil})
      |> Map.put(:dice, %{values: [1, 1], moves: [1], moves_left: [1], moves_played: []})

    assert {:ok, runtime} =
             Backgammon.Rules.TourneCase.move(runtime, :black, %{"from" => 20, "to" => 19})

    assert runtime.forced_piece.white == nil
  end

  test "dames rabattues keeps the turn after a doublet" do
    engine = Engine.new("rab-double", "dames_rabattues")
    assert {:ok, engine, _} = Engine.join(engine, "nick", "tab-a")
    assert {:ok, engine, _} = Engine.join(engine, "jane", "tab-b")

    runtime =
      Map.merge(engine.runtime, %{
        dice: %{values: [3, 3], moves: [3, 3], moves_left: [], moves_played: [3, 3]},
        carry_turn: true
      })

    engine = %{engine | runtime: runtime, dice: runtime.dice, turn_color: :white, turn_number: 1}

    assert {:ok, engine} = Engine.confirm(engine, "nick", "tab-a")
    snapshot = Engine.snapshot(engine)

    assert snapshot["turn"]["color"] == "white"
    assert snapshot["dice"] == nil
  end

  test "dames rabattues begins with a higher-die opening roll" do
    Application.put_env(:backgammon, :dice_impl, SequenceDice)
    Process.put({SequenceDice, :values}, [3, 5])

    engine = Engine.new("rab-opening", "dames_rabattues")
    assert {:ok, engine, _} = Engine.join(engine, "nick", "tab-a")
    assert {:ok, engine, _} = Engine.join(engine, "jane", "tab-b")

    snapshot = Engine.snapshot(engine)
    assert snapshot["status"] == "playing"
    assert snapshot["turn"] == nil
    assert snapshot["opening_roll"]["order"] == "highest"
    assert snapshot["opening_roll"]["rolls"] == %{"white" => nil, "black" => nil}

    assert {:ok, engine} = Engine.roll(engine, "nick", "tab-a")
    assert Engine.snapshot(engine)["opening_roll"]["rolls"]["white"] == 3

    assert {:ok, engine} = Engine.roll(engine, "jane", "tab-b")
    assert engine.turn_color == :black
    assert engine.turn_number == 1
    assert Engine.snapshot(engine)["opening_roll"] == nil
  end

  test "dames rabattues direct entrypoints accept raw new runtimes" do
    Application.put_env(:backgammon, :dice_impl, DeterministicDice)

    runtime = Backgammon.Rules.Rabattues.new()

    assert Backgammon.Rules.Rabattues.legal_moves(runtime, :white) == []

    runtime = Backgammon.Rules.Rabattues.roll(runtime)

    assert runtime.dice.values == [4, 2]
    assert runtime.dice.moves_left == [4, 2]
    assert runtime.carry_turn == false

    assert Enum.sort_by(Backgammon.Rules.Rabattues.legal_moves(runtime, :white), & &1.die) == [
             %{from: 22, to: 16, die: 2},
             %{from: 20, to: 14, die: 4}
           ]
  end

  test "dames rabattues tracks rabattre and lever by player" do
    runtime =
      Backgammon.Rules.Rabattues.new()
      |> Map.put(:phase, :rabattre)
      |> Map.put(:phases, %{white: :rabattre, black: :rabattre})
      |> Map.put(:piles, %{
        white: %{1 => 0, 2 => 0, 3 => 0, 4 => 0, 5 => 0, 6 => 0},
        black: %{1 => 2, 2 => 2, 3 => 2, 4 => 3, 5 => 3, 6 => 3}
      })
      |> Map.put(:down, %{
        white: %{1 => 2, 2 => 2, 3 => 2, 4 => 3, 5 => 3, 6 => 3},
        black: %{}
      })
      |> Map.put(:dice, %{values: [1, 2], moves: [1, 2], moves_left: [1], moves_played: []})

    assert [%{from: 17, to: 23, die: 1}] = Backgammon.Rules.Rabattues.legal_moves(runtime, :white)
    assert [%{from: 0, to: 6, die: 1}] = Backgammon.Rules.Rabattues.legal_moves(runtime, :black)
  end

  test "dames rabattues derives lever once a player has fully rabattu all men" do
    runtime =
      Backgammon.Rules.Rabattues.new()
      |> Map.put(:phase, :rabattre)
      |> Map.put(:phases, %{white: :rabattre, black: :rabattre})
      |> Map.put(:piles, %{
        white: %{1 => 0, 2 => 0, 3 => 0, 4 => 0, 5 => 0, 6 => 0},
        black: %{1 => 2, 2 => 2, 3 => 2, 4 => 3, 5 => 3, 6 => 3}
      })
      |> Map.put(:down, %{
        white: %{1 => 2, 2 => 2, 3 => 2, 4 => 3, 5 => 3, 6 => 3},
        black: %{}
      })
      |> Map.put(:dice, %{values: [1, 2], moves: [1, 2], moves_left: [1], moves_played: []})

    assert Backgammon.Rules.Rabattues.play_phase(runtime, :white) == :lever
    assert [%{from: 17, to: 23, die: 1}] = Backgammon.Rules.Rabattues.legal_moves(runtime, :white)
  end

  test "dames rabattues winner is derived from done state instead of the stored phase" do
    runtime =
      Backgammon.Rules.Rabattues.new()
      |> Map.put(:phase, :rabattre)
      |> Map.put(:phases, %{white: :rabattre, black: :rabattre})
      |> Map.put(:lever_ready, %{white: true, black: false})

    assert Backgammon.Rules.Rabattues.winner(runtime, :white) == "levered"
  end

  test "dames rabattues lets the opponent play a missed number" do
    engine = Engine.new("rab-assist", "dames_rabattues")
    assert {:ok, engine, _} = Engine.join(engine, "nick", "tab-a")
    assert {:ok, engine, _} = Engine.join(engine, "jane", "tab-b")

    runtime =
      Map.merge(engine.runtime, %{
        phase: :rabattre,
        piles: %{
          white: %{1 => 0, 2 => 2, 3 => 2, 4 => 3, 5 => 3, 6 => 3},
          black: %{1 => 2, 2 => 2, 3 => 2, 4 => 3, 5 => 3, 6 => 3}
        },
        dice: %{values: [1, 2], moves: [1, 2], moves_left: [1], moves_played: [2]},
        roller_color: :white,
        carry_turn: false
      })

    engine = %{engine | runtime: runtime, dice: runtime.dice, turn_color: :white, turn_number: 1}

    assert {:ok, engine} = Engine.confirm(engine, "nick", "tab-a")
    snapshot = Engine.snapshot(engine)

    assert snapshot["turn"]["color"] == "black"
    assert snapshot["dice"]["moves_left"] == [1]

    assert Enum.any?(
             snapshot["legal_moves"],
             &(&1["from"] == 0 and &1["to"] == 6 and &1["die"] == 1)
           )
  end

  test "dames rabattues does not transfer missed numbers once the roller is in lever" do
    engine = Engine.new("rab-lever-exception", "dames_rabattues")
    assert {:ok, engine, _} = Engine.join(engine, "nick", "tab-a")
    assert {:ok, engine, _} = Engine.join(engine, "jane", "tab-b")

    runtime =
      Map.merge(engine.runtime, %{
        phase: :lever,
        phases: %{white: :lever, black: :rabattre},
        lever_ready: %{white: true, black: false},
        piles: %{
          white: %{1 => 2, 2 => 0, 3 => 0, 4 => 0, 5 => 0, 6 => 0},
          black: %{1 => 2, 2 => 2, 3 => 2, 4 => 3, 5 => 3, 6 => 3}
        },
        down: %{
          white: %{1 => 0, 2 => 2, 3 => 2, 4 => 3, 5 => 3, 6 => 3},
          black: %{}
        },
        dice: %{values: [1, 2], moves: [1, 2], moves_left: [1], moves_played: [2]},
        roller_color: :white,
        carry_turn: false
      })

    engine = %{engine | runtime: runtime, dice: runtime.dice, turn_color: :white, turn_number: 1}

    assert {:ok, engine} = Engine.confirm(engine, "nick", "tab-a")
    snapshot = Engine.snapshot(engine)

    assert snapshot["turn"]["color"] == "black"
    assert snapshot["dice"] == nil
    assert snapshot["legal_moves"] == []
  end

  test "dames rabattues does not allow lever before all of that player's men are rabattues" do
    runtime =
      Backgammon.Rules.Rabattues.new()
      |> Map.put(:phase, :lever)
      |> Map.put(:phases, %{white: :lever, black: :lever})
      |> Map.put(:piles, %{
        white: %{1 => 1, 2 => 0, 3 => 0, 4 => 0, 5 => 0, 6 => 0},
        black: %{1 => 0, 2 => 0, 3 => 0, 4 => 0, 5 => 0, 6 => 0}
      })
      |> Map.put(:down, %{
        white: %{1 => 1, 2 => 2, 3 => 2, 4 => 3, 5 => 3, 6 => 3},
        black: %{1 => 2, 2 => 2, 3 => 2, 4 => 3, 5 => 3, 6 => 3}
      })
      |> Map.put(:dice, %{values: [1, 2], moves: [1, 2], moves_left: [1], moves_played: []})

    assert Backgammon.Rules.Rabattues.legal_moves(runtime, :white) == [
             %{from: 23, to: 17, die: 1}
           ]
  end

  test "dames rabattues keeps a lever doublet with unusable repeated numbers on the roller" do
    engine = Engine.new("rab-double-lever-pass", "dames_rabattues")
    assert {:ok, engine, _} = Engine.join(engine, "nick", "tab-a")
    assert {:ok, engine, _} = Engine.join(engine, "jane", "tab-b")

    runtime =
      Map.merge(engine.runtime, %{
        phase: :lever,
        phases: %{white: :lever, black: :rabattre},
        lever_ready: %{white: true, black: false},
        piles: %{
          white: %{1 => 2, 2 => 0, 3 => 0, 4 => 0, 5 => 0, 6 => 0},
          black: %{1 => 2, 2 => 2, 3 => 2, 4 => 3, 5 => 3, 6 => 3}
        },
        down: %{
          white: %{1 => 0, 2 => 2, 3 => 2, 4 => 3, 5 => 3, 6 => 3},
          black: %{}
        },
        dice: %{values: [1, 1], moves: [1, 1], moves_left: [1, 1], moves_played: []},
        roller_color: :white,
        carry_turn: true
      })

    engine = %{engine | runtime: runtime, dice: runtime.dice, turn_color: :white, turn_number: 1}

    assert {:ok, engine} = Engine.confirm(engine, "nick", "tab-a")
    snapshot = Engine.snapshot(engine)

    assert snapshot["turn"]["color"] == "white"
    assert snapshot["dice"] == nil
    assert snapshot["legal_moves"] == []
  end

  test "brade option submission stores match length" do
    engine = Engine.new("brade-start", "brade")
    assert {:ok, engine, _} = Engine.join(engine, "nick", "tab-a")
    assert {:ok, engine, _} = Engine.join(engine, "jane", "tab-b")

    assert {:ok, engine} =
             Engine.submit_match_options(engine, %{"matchLength" => "3"}, "nick", "tab-a")

    snapshot = Engine.snapshot(engine)

    assert snapshot["status"] == "playing"
    assert snapshot["match"]["length"] == 3
    assert snapshot["turn"] == nil
    assert snapshot["dice"] == nil
    assert snapshot["opening_roll"]["order"] == "lowest"
  end

  test "brade resolves the first-game teker opener with the lower die starting" do
    Application.put_env(:backgammon, :dice_impl, SequenceDice)
    Process.put({SequenceDice, :values}, [4, 2])

    engine = Engine.new("brade-teker", "brade")
    assert {:ok, engine, _} = Engine.join(engine, "nick", "tab-a")
    assert {:ok, engine, _} = Engine.join(engine, "jane", "tab-b")

    assert {:ok, engine} =
             Engine.submit_match_options(engine, %{"matchLength" => "3"}, "nick", "tab-a")

    assert engine.turn_color == nil
    assert {:ok, engine} = Engine.roll(engine, "nick", "tab-a")
    assert engine.turn_color == nil
    assert engine.dice == nil
    assert get_in(engine.runtime, [:variant_state, :brade_teker_rolls, :white]) == 4

    assert {:ok, engine} = Engine.roll(engine, "jane", "tab-b")
    assert engine.turn_color == :black
    assert engine.turn_number == 1
    assert engine.dice == nil
    assert engine.runtime.variant_state.brade_teker_rolls == %{white: nil, black: nil}
  end

  test "brade rerolls teker ties until a starter is found" do
    Application.put_env(:backgammon, :dice_impl, SequenceDice)
    Process.put({SequenceDice, :values}, [4, 4, 2, 5])

    engine = Engine.new("brade-teker-tie", "brade")
    assert {:ok, engine, _} = Engine.join(engine, "nick", "tab-a")
    assert {:ok, engine, _} = Engine.join(engine, "jane", "tab-b")

    assert {:ok, engine} =
             Engine.submit_match_options(engine, %{"matchLength" => "3"}, "nick", "tab-a")

    assert {:ok, engine} = Engine.roll(engine, "nick", "tab-a")
    assert {:ok, engine} = Engine.roll(engine, "jane", "tab-b")
    assert engine.turn_color == nil
    assert engine.runtime.variant_state.brade_teker_rolls == %{white: nil, black: nil}

    assert {:ok, engine} = Engine.roll(engine, "nick", "tab-a")
    assert {:ok, engine} = Engine.roll(engine, "jane", "tab-b")
    assert engine.turn_color == :white
    assert engine.turn_number == 1
  end

  test "brade home with munk scores the stronger home result" do
    engine = Engine.new("brade-home", "brade")
    assert {:ok, engine, _} = Engine.join(engine, "nick", "tab-a")
    assert {:ok, engine, _} = Engine.join(engine, "jane", "tab-b")

    assert {:ok, engine} =
             Engine.submit_match_options(engine, %{"matchLength" => "3"}, "nick", "tab-a")

    board = %{engine.board | outside: %{white: 15, black: 0}, bar: %{white: 0, black: 2}}
    runtime = %{engine.runtime | board: board}

    engine = %{
      engine
      | runtime: runtime,
        board: board,
        turn_color: :white,
        dice: %{values: [3, 2], moves: [3, 2], moves_left: [], moves_played: [3, 2]}
    }

    assert {:ok, engine} = Engine.confirm(engine, "nick", "tab-a")
    snapshot = Engine.snapshot(engine)

    assert snapshot["match"]["results"] == [
             %{"winner" => "white", "points" => 2, "kind" => "home_munk"}
           ]
  end

  test "brade later games still start with the loser and do not teker again" do
    engine = Engine.new("brade-loser-start", "brade")
    assert {:ok, engine, _} = Engine.join(engine, "nick", "tab-a")
    assert {:ok, engine, _} = Engine.join(engine, "jane", "tab-b")

    assert {:ok, engine} =
             Engine.submit_match_options(engine, %{"matchLength" => "3"}, "nick", "tab-a")

    board = %{engine.board | outside: %{white: 15, black: 0}, bar: %{white: 0, black: 0}}
    runtime = %{engine.runtime | board: board}
    dice = %{values: [1, 1], moves: [1, 1], moves_left: [], moves_played: [1, 1]}

    engine = %{
      engine
      | runtime: Map.put(runtime, :dice, dice),
        board: board,
        turn_color: :white,
        turn_number: 1,
        dice: dice
    }

    assert {:ok, engine} = Engine.confirm(engine, "nick", "tab-a")
    assert engine.turn_color == :black
    assert engine.turn_number == 2
    assert engine.runtime.variant_state.brade_teker_rolls == %{white: nil, black: nil}
  end

  test "brade bar entry cannot land on your own occupied point" do
    engine = Engine.new("brade-entry", "brade")
    assert {:ok, engine, _} = Engine.join(engine, "nick", "tab-a")
    assert {:ok, engine, _} = Engine.join(engine, "jane", "tab-b")

    assert {:ok, engine} =
             Engine.submit_match_options(engine, %{"matchLength" => "3"}, "nick", "tab-a")

    points =
      Enum.map(0..23, fn index ->
        cond do
          index == 21 -> %{white: 1, black: 0}
          true -> %{white: 0, black: 0}
        end
      end)

    board = %{engine.board | points: points, bar: %{white: 1, black: 0}}
    runtime = %{engine.runtime | board: board}

    engine = %{
      engine
      | runtime: runtime,
        board: board,
        turn_color: :white,
        dice: %{values: [3, 1], moves: [3, 1], moves_left: [3, 1], moves_played: []}
    }

    legal =
      Backgammon.Rules.RaceCore.legal_moves(
        Map.put(runtime, :dice, engine.dice),
        engine.variant,
        :white
      )

    refute Enum.any?(legal, &(&1.to == 21))
  end

  test "brade cannot form a case on an ordinary far-side point" do
    engine = Engine.new("brade-far-side-case", "brade")
    assert {:ok, engine, _} = Engine.join(engine, "nick", "tab-a")
    assert {:ok, engine, _} = Engine.join(engine, "jane", "tab-b")

    assert {:ok, engine} =
             Engine.submit_match_options(engine, %{"matchLength" => "3"}, "nick", "tab-a")

    points =
      Enum.map(0..23, fn index ->
        cond do
          index == 0 -> %{white: 0, black: 1}
          index == 1 -> %{white: 0, black: 1}
          true -> %{white: 0, black: 0}
        end
      end)

    board = %{engine.board | points: points, bar: %{white: 0, black: 0}}
    dice = %{values: [1, 1], moves: [1, 1], moves_left: [1], moves_played: []}
    runtime = engine.runtime |> Map.put(:board, board) |> Map.put(:dice, dice)

    legal = Backgammon.Rules.RaceCore.legal_moves(runtime, engine.variant, :black)

    refute Enum.any?(legal, &(&1.from == 0 and &1.to == 1 and &1.die == 1))
    assert Enum.any?(legal, &(&1.from == 1 and &1.to == 2 and &1.die == 1))
  end

  test "brade can still form a case on the far-side coin of rest" do
    engine = Engine.new("brade-coin-case", "brade")
    assert {:ok, engine, _} = Engine.join(engine, "nick", "tab-a")
    assert {:ok, engine, _} = Engine.join(engine, "jane", "tab-b")

    assert {:ok, engine} =
             Engine.submit_match_options(engine, %{"matchLength" => "3"}, "nick", "tab-a")

    points =
      Enum.map(0..23, fn index ->
        cond do
          index == 13 -> %{white: 1, black: 0}
          index == 12 -> %{white: 1, black: 0}
          true -> %{white: 0, black: 0}
        end
      end)

    board = %{engine.board | points: points, bar: %{white: 0, black: 0}}
    dice = %{values: [1, 1], moves: [1, 1], moves_left: [1], moves_played: []}
    runtime = engine.runtime |> Map.put(:board, board) |> Map.put(:dice, dice)

    legal = Backgammon.Rules.RaceCore.legal_moves(runtime, engine.variant, :white)

    assert Enum.any?(legal, &(&1.from == 13 and &1.to == 12 and &1.die == 1))
  end

  test "brade can still form a case anywhere on its own side" do
    engine = Engine.new("brade-own-side-case", "brade")
    assert {:ok, engine, _} = Engine.join(engine, "nick", "tab-a")
    assert {:ok, engine, _} = Engine.join(engine, "jane", "tab-b")

    assert {:ok, engine} =
             Engine.submit_match_options(engine, %{"matchLength" => "3"}, "nick", "tab-a")

    points =
      Enum.map(0..23, fn index ->
        cond do
          index == 6 -> %{white: 1, black: 0}
          index == 5 -> %{white: 1, black: 0}
          true -> %{white: 0, black: 0}
        end
      end)

    board = %{engine.board | points: points, bar: %{white: 0, black: 0}}
    dice = %{values: [1, 1], moves: [1, 1], moves_left: [1], moves_played: []}
    runtime = engine.runtime |> Map.put(:board, board) |> Map.put(:dice, dice)

    legal = Backgammon.Rules.RaceCore.legal_moves(runtime, engine.variant, :white)

    assert Enum.any?(legal, &(&1.from == 6 and &1.to == 5 and &1.die == 1))
  end

  test "brade filters out far-side casing branches that cannot spend the remaining die" do
    engine = Engine.new("brade-case-branch", "brade")
    assert {:ok, engine, _} = Engine.join(engine, "nick", "tab-a")
    assert {:ok, engine, _} = Engine.join(engine, "jane", "tab-b")

    assert {:ok, engine} =
             Engine.submit_match_options(engine, %{"matchLength" => "3"}, "nick", "tab-a")

    points =
      Enum.map(0..23, fn index ->
        cond do
          index == 23 -> %{white: 1, black: 0}
          index == 22 -> %{white: 1, black: 0}
          index == 20 -> %{white: 0, black: 2}
          true -> %{white: 0, black: 0}
        end
      end)

    board = %{engine.board | points: points, bar: %{white: 0, black: 0}}
    dice = %{values: [2, 1], moves: [2, 1], moves_left: [2, 1], moves_played: []}
    runtime = engine.runtime |> Map.put(:board, board) |> Map.put(:dice, dice)

    legal = Backgammon.Rules.RaceCore.legal_moves(runtime, engine.variant, :white)

    refute Enum.any?(legal, &(&1.from == 23 and &1.to == 21 and &1.die == 2))
    assert Enum.any?(legal, &(&1.from == 22 and &1.to == 21 and &1.die == 1))
  end

  test "brade can explode an entry case when there are too many captured men to re-enter" do
    engine = Engine.new("brade-explode", "brade")
    assert {:ok, engine, _} = Engine.join(engine, "nick", "tab-a")
    assert {:ok, engine, _} = Engine.join(engine, "jane", "tab-b")

    assert {:ok, engine} =
             Engine.submit_match_options(engine, %{"matchLength" => "3"}, "nick", "tab-a")

    points =
      Enum.map(0..23, fn index ->
        cond do
          index in [18, 19, 20, 21] -> %{white: 0, black: 2}
          index == 23 -> %{white: 0, black: 1}
          true -> %{white: 0, black: 0}
        end
      end)

    board = %{engine.board | points: points, bar: %{white: 3, black: 0}}
    runtime = %{engine.runtime | board: board}
    dice = %{values: [3, 1], moves: [3, 1], moves_left: [3, 1], moves_played: []}
    engine = %{engine | runtime: runtime, board: board, turn_color: :white, dice: dice}

    legal =
      Backgammon.Rules.RaceCore.legal_moves(Map.put(runtime, :dice, dice), engine.variant, :white)

    assert Enum.any?(legal, &(&1.from == "bar" and &1.to == 21 and &1.hit?))

    engine = %{engine | legal_moves: legal}

    assert {:ok, engine} =
             Engine.move(engine, %{"from" => "bar", "to" => 21, "die" => 3}, "nick", "tab-a")

    snapshot = Engine.snapshot(engine)
    assert Enum.at(snapshot["board"]["points"], 21)["pieces"] == ["white"]
    assert snapshot["board"]["bar"]["white"] == 2
    assert snapshot["board"]["bar"]["black"] == 2
  end

  test "brade can explode a six-case path block during normal movement" do
    engine = Engine.new("brade-path-explode", "brade")
    assert {:ok, engine, _} = Engine.join(engine, "nick", "tab-a")
    assert {:ok, engine, _} = Engine.join(engine, "jane", "tab-b")

    assert {:ok, engine} =
             Engine.submit_match_options(engine, %{"matchLength" => "3"}, "nick", "tab-a")

    points =
      Enum.map(0..23, fn index ->
        cond do
          index == 23 -> %{white: 1, black: 0}
          index in 16..22 -> %{white: 0, black: 2}
          true -> %{white: 0, black: 0}
        end
      end)

    board = %{engine.board | points: points, bar: %{white: 0, black: 0}}
    dice = %{values: [3, 1], moves: [3, 1], moves_left: [3], moves_played: []}
    runtime = engine.runtime |> Map.put(:board, board) |> Map.put(:dice, dice)
    engine = %{engine | runtime: runtime, board: board, turn_color: :white, dice: dice}

    legal = Backgammon.Rules.RaceCore.legal_moves(runtime, engine.variant, :white)
    assert Enum.any?(legal, &(&1.from == 23 and &1.to == 20 and &1.hit?))

    engine = %{engine | legal_moves: legal}

    assert {:ok, engine} =
             Engine.move(engine, %{"from" => 23, "to" => 20, "die" => 3}, "nick", "tab-a")

    snapshot = Engine.snapshot(engine)
    assert Enum.at(snapshot["board"]["points"], 20)["pieces"] == ["white"]
    assert snapshot["board"]["bar"]["black"] == 2
  end

  test "brade junker exception blocks entry and path explosions" do
    engine = Engine.new("brade-junker", "brade")
    assert {:ok, engine, _} = Engine.join(engine, "nick", "tab-a")
    assert {:ok, engine, _} = Engine.join(engine, "jane", "tab-b")

    assert {:ok, engine} =
             Engine.submit_match_options(engine, %{"matchLength" => "3"}, "nick", "tab-a")

    entry_points =
      Enum.map(0..23, fn index ->
        cond do
          index in 18..23 -> %{white: 0, black: 2}
          true -> %{white: 0, black: 0}
        end
      end)

    entry_board = %{
      engine.board
      | points: entry_points,
        bar: %{white: 1, black: 0},
        outside: %{white: 14, black: 0}
    }

    entry_runtime = %{engine.runtime | board: entry_board}
    entry_dice = %{values: [3, 1], moves: [3, 1], moves_left: [3, 1], moves_played: []}

    entry_legal =
      Backgammon.Rules.RaceCore.legal_moves(
        Map.put(entry_runtime, :dice, entry_dice),
        engine.variant,
        :white
      )

    refute Enum.any?(entry_legal, &(&1.from == "bar" and &1.hit?))

    path_points =
      Enum.map(0..23, fn index ->
        cond do
          index == 23 -> %{white: 1, black: 0}
          index in 16..22 -> %{white: 0, black: 2}
          true -> %{white: 0, black: 0}
        end
      end)

    path_board = %{
      engine.board
      | points: path_points,
        bar: %{white: 0, black: 0},
        outside: %{white: 14, black: 0}
    }

    path_runtime = %{engine.runtime | board: path_board}
    path_dice = %{values: [3, 1], moves: [3, 1], moves_left: [3], moves_played: []}

    path_legal =
      Backgammon.Rules.RaceCore.legal_moves(
        Map.put(path_runtime, :dice, path_dice),
        engine.variant,
        :white
      )

    refute Enum.any?(path_legal, &(&1.from == 23 and &1.to == 20 and &1.hit?))
  end

  test "brade jan counts all six entry points even when the attacker occupies them" do
    engine = Engine.new("brade-jan-capacity", "brade")
    assert {:ok, engine, _} = Engine.join(engine, "nick", "tab-a")
    assert {:ok, engine, _} = Engine.join(engine, "jane", "tab-b")

    assert {:ok, engine} =
             Engine.submit_match_options(engine, %{"matchLength" => "3"}, "nick", "tab-a")

    occupied_entry_points =
      Enum.map(0..23, fn index ->
        cond do
          index in 18..23 -> %{white: 2, black: 0}
          true -> %{white: 0, black: 0}
        end
      end)

    board =
      %{
        engine.board
        | points: occupied_entry_points,
          bar: %{white: 0, black: 6},
          outside: %{white: 0, black: 0}
      }

    runtime = %{engine.runtime | board: board}
    dice = %{values: [1, 1], moves: [1, 1], moves_left: [], moves_played: [1, 1]}

    engine = %{
      engine
      | runtime: Map.put(runtime, :dice, dice),
        board: board,
        turn_color: :white,
        dice: dice
    }

    assert {:ok, engine} = Engine.confirm(engine, "nick", "tab-a")
    snapshot = Engine.snapshot(engine)

    assert snapshot["match"]["is_over"] == false
    assert snapshot["turn"]["color"] == "black"
  end

  test "brade still scores jan once the victim has more than six captured men" do
    engine = Engine.new("brade-jan-win", "brade")
    assert {:ok, engine, _} = Engine.join(engine, "nick", "tab-a")
    assert {:ok, engine, _} = Engine.join(engine, "jane", "tab-b")

    assert {:ok, engine} =
             Engine.submit_match_options(engine, %{"matchLength" => "3"}, "nick", "tab-a")

    occupied_entry_points =
      Enum.map(0..23, fn index ->
        cond do
          index in 18..23 -> %{white: 2, black: 0}
          true -> %{white: 0, black: 0}
        end
      end)

    board =
      %{
        engine.board
        | points: occupied_entry_points,
          bar: %{white: 0, black: 7},
          outside: %{white: 0, black: 0}
      }

    runtime = %{engine.runtime | board: board}
    dice = %{values: [1, 1], moves: [1, 1], moves_left: [], moves_played: [1, 1]}

    engine = %{
      engine
      | runtime: Map.put(runtime, :dice, dice),
        board: board,
        turn_color: :white,
        dice: dice
    }

    assert {:ok, engine} = Engine.confirm(engine, "nick", "tab-a")
    snapshot = Engine.snapshot(engine)

    assert snapshot["match"]["results"] == [
             %{"winner" => "white", "points" => 4, "kind" => "jan"}
           ]
  end

  test "brade does not upgrade an ordinary jan to sprangjan just because the winner has a checker on the bar" do
    engine = Engine.new("brade-plain-jan", "brade")
    assert {:ok, engine, _} = Engine.join(engine, "nick", "tab-a")
    assert {:ok, engine, _} = Engine.join(engine, "jane", "tab-b")

    assert {:ok, engine} =
             Engine.submit_match_options(engine, %{"matchLength" => "3"}, "nick", "tab-a")

    occupied_entry_points =
      Enum.map(0..23, fn index ->
        cond do
          index in 18..23 -> %{white: 2, black: 0}
          true -> %{white: 0, black: 0}
        end
      end)

    board =
      %{
        engine.board
        | points: occupied_entry_points,
          bar: %{white: 1, black: 7},
          outside: %{white: 0, black: 0}
      }

    runtime = %{engine.runtime | board: board}
    dice = %{values: [1, 1], moves: [1, 1], moves_left: [], moves_played: [1, 1]}

    engine = %{
      engine
      | runtime: Map.put(runtime, :dice, dice),
        board: board,
        turn_color: :white,
        dice: dice
    }

    assert {:ok, engine} = Engine.confirm(engine, "nick", "tab-a")
    snapshot = Engine.snapshot(engine)

    assert snapshot["match"]["results"] == [
             %{"winner" => "white", "points" => 4, "kind" => "jan"}
           ]
  end

  test "brade clears a sprängjan cause marker when the turn ends without a win" do
    engine = Engine.new("brade-clear-cause", "brade")
    assert {:ok, engine, _} = Engine.join(engine, "nick", "tab-a")
    assert {:ok, engine, _} = Engine.join(engine, "jane", "tab-b")

    assert {:ok, engine} =
             Engine.submit_match_options(engine, %{"matchLength" => "3"}, "nick", "tab-a")

    runtime =
      engine.runtime
      |> Map.put(:dice, %{values: [1, 2], moves: [1, 2], moves_left: [], moves_played: [1, 2]})
      |> put_in([:variant_state, :brade_turn_cause], %{
        white: %{last_inward_signature: 111, qualifying_signature: 222},
        black: %{last_inward_signature: nil, qualifying_signature: nil}
      })

    engine = %{
      engine
      | runtime: runtime,
        board: runtime.board,
        turn_color: :white,
        dice: runtime.dice
    }

    assert {:ok, engine} = Engine.confirm(engine, "nick", "tab-a")
    assert engine.runtime.variant_state.brade_turn_cause == empty_brade_turn_cause()
    assert engine.turn_color == :black
  end

  test "brade scores sprangjan after an inward explosion makes re-entry impossible" do
    engine = Engine.new("brade-sprangjan", "brade")
    assert {:ok, engine, _} = Engine.join(engine, "nick", "tab-a")
    assert {:ok, engine, _} = Engine.join(engine, "jane", "tab-b")

    assert {:ok, engine} =
             Engine.submit_match_options(engine, %{"matchLength" => "3"}, "nick", "tab-a")

    points =
      Enum.map(0..23, fn index ->
        cond do
          index == 6 -> %{white: 1, black: 0}
          index in 0..5 -> %{white: 0, black: 2}
          true -> %{white: 0, black: 0}
        end
      end)

    board = %{
      engine.board
      | points: points,
        bar: %{white: 0, black: 5},
        outside: %{white: 0, black: 0}
    }

    dice = %{values: [2, 1], moves: [2, 1], moves_left: [2], moves_played: []}
    runtime = engine.runtime |> Map.put(:board, board) |> Map.put(:dice, dice)
    legal_moves = Backgammon.Rules.RaceCore.legal_moves(runtime, engine.variant, :white)

    assert Enum.any?(legal_moves, &(&1.from == 6 and &1.to == 4 and &1.die == 2 and &1.hit?))

    engine =
      %{
        engine
        | runtime: runtime,
          board: board,
          turn_color: :white,
          turn_number: 1,
          dice: dice,
          legal_moves: legal_moves
      }

    assert {:ok, engine} =
             Engine.move(engine, %{"from" => 6, "to" => 4, "die" => 2}, "nick", "tab-a")

    snapshot = Engine.snapshot(engine)

    assert snapshot["match"]["results"] == [
             %{"winner" => "white", "points" => 6, "kind" => "sprangjan"}
           ]

    assert snapshot["dice"] == nil
  end

  test "brade resets any sprängjan cause marker when starting the next game" do
    engine = Engine.new("brade-reset-cause", "brade")
    assert {:ok, engine, _} = Engine.join(engine, "nick", "tab-a")
    assert {:ok, engine, _} = Engine.join(engine, "jane", "tab-b")

    assert {:ok, engine} =
             Engine.submit_match_options(engine, %{"matchLength" => "3"}, "nick", "tab-a")

    board = %{engine.board | outside: %{white: 15, black: 0}, bar: %{white: 0, black: 0}}

    runtime =
      engine.runtime
      |> Map.put(:board, board)
      |> Map.put(:dice, %{values: [1, 1], moves: [1, 1], moves_left: [], moves_played: [1, 1]})
      |> put_in([:variant_state, :brade_turn_cause], %{
        white: %{last_inward_signature: 111, qualifying_signature: 222},
        black: %{last_inward_signature: nil, qualifying_signature: nil}
      })

    engine = %{engine | runtime: runtime, board: board, turn_color: :white, dice: runtime.dice}

    assert {:ok, engine} = Engine.confirm(engine, "nick", "tab-a")
    assert engine.runtime.variant_state.brade_turn_cause == empty_brade_turn_cause()
    assert engine.match.results == [%{winner: "white", points: 1, kind: "home"}]
    assert engine.turn_color == :black
  end

  test "brade does not upgrade a jan unless the current board matches the qualifying inward explosion" do
    engine = Engine.new("brade-stale-cause", "brade")
    assert {:ok, engine, _} = Engine.join(engine, "nick", "tab-a")
    assert {:ok, engine, _} = Engine.join(engine, "jane", "tab-b")

    assert {:ok, engine} =
             Engine.submit_match_options(engine, %{"matchLength" => "3"}, "nick", "tab-a")

    occupied_entry_points =
      Enum.map(0..23, fn index ->
        cond do
          index in 18..23 -> %{white: 2, black: 0}
          true -> %{white: 0, black: 0}
        end
      end)

    board =
      %{
        engine.board
        | points: occupied_entry_points,
          bar: %{white: 0, black: 7},
          outside: %{white: 0, black: 0}
      }

    runtime =
      engine.runtime
      |> Map.put(:board, board)
      |> Map.put(:dice, %{values: [1, 1], moves: [1, 1], moves_left: [], moves_played: [1, 1]})
      |> put_in([:variant_state, :brade_turn_cause], %{
        white: %{last_inward_signature: 999, qualifying_signature: 999},
        black: %{last_inward_signature: nil, qualifying_signature: nil}
      })

    engine = %{engine | runtime: runtime, board: board, turn_color: :white, dice: runtime.dice}

    assert {:ok, engine} = Engine.confirm(engine, "nick", "tab-a")
    assert engine.match.results == [%{winner: "white", points: 4, kind: "jan"}]
  end

  test "brade ends immediately when a winning move is made before all dice are spent" do
    engine = Engine.new("brade-immediate", "brade")
    assert {:ok, engine, _} = Engine.join(engine, "nick", "tab-a")
    assert {:ok, engine, _} = Engine.join(engine, "jane", "tab-b")

    assert {:ok, engine} =
             Engine.submit_match_options(engine, %{"matchLength" => "3"}, "nick", "tab-a")

    points =
      Enum.map(0..23, fn index ->
        cond do
          index == 0 -> %{white: 1, black: 0}
          true -> %{white: 0, black: 0}
        end
      end)

    board = %{
      engine.board
      | points: points,
        outside: %{white: 14, black: 0},
        bar: %{white: 0, black: 0}
    }

    dice = %{values: [1, 6], moves: [1, 6], moves_left: [1, 6], moves_played: []}
    runtime = engine.runtime |> Map.put(:board, board) |> Map.put(:dice, dice)
    legal_moves = Backgammon.Rules.RaceCore.legal_moves(runtime, engine.variant, :white)

    engine = %{
      engine
      | runtime: runtime,
        board: board,
        turn_color: :white,
        turn_number: 1,
        dice: dice,
        legal_moves: legal_moves
    }

    assert {:ok, engine} =
             Engine.move(engine, %{"from" => 0, "to" => "home", "die" => 1}, "nick", "tab-a")

    snapshot = Engine.snapshot(engine)

    assert snapshot["match"]["results"] == [
             %{"winner" => "white", "points" => 1, "kind" => "home"}
           ]

    assert snapshot["dice"] == nil
    assert snapshot["legal_moves"] == []
  end

  test "brade keeps a higher-reduction winning line legal on the final turn" do
    engine = Engine.new("brade-winning-branch", "brade")
    assert {:ok, engine, _} = Engine.join(engine, "nick", "tab-a")
    assert {:ok, engine, _} = Engine.join(engine, "jane", "tab-b")

    assert {:ok, engine} =
             Engine.submit_match_options(engine, %{"matchLength" => "3"}, "nick", "tab-a")

    points =
      Enum.map(0..23, fn index ->
        cond do
          index == 5 -> %{white: 1, black: 0}
          index == 3 -> %{white: 0, black: 1}
          true -> %{white: 0, black: 0}
        end
      end)

    board = %{
      engine.board
      | points: points,
        outside: %{white: 14, black: 0},
        bar: %{white: 0, black: 0}
    }

    dice = %{values: [6, 2], moves: [6, 2], moves_left: [6, 2], moves_played: []}
    runtime = engine.runtime |> Map.put(:board, board) |> Map.put(:dice, dice)
    legal_moves = Backgammon.Rules.RaceCore.legal_moves(runtime, engine.variant, :white)

    assert Enum.any?(legal_moves, &(&1.from == 5 and &1.to == "home" and &1.die == 6))
    assert Enum.any?(legal_moves, &(&1.from == 5 and &1.to == 3 and &1.die == 2 and &1.hit?))

    engine =
      %{
        engine
        | runtime: runtime,
          board: board,
          turn_color: :white,
          turn_number: 1,
          dice: dice,
          legal_moves: legal_moves
      }

    assert {:ok, engine} =
             Engine.move(engine, %{"from" => 5, "to" => 3, "die" => 2}, "nick", "tab-a")

    assert {:ok, engine} =
             Engine.move(engine, %{"from" => 3, "to" => "home", "die" => 6}, "nick", "tab-a")

    snapshot = Engine.snapshot(engine)

    assert snapshot["match"]["results"] == [
             %{"winner" => "white", "points" => 2, "kind" => "home_munk"}
           ]

    assert snapshot["dice"] == nil
  end

  test "brade alle can end immediately on a winning prefix" do
    engine = Engine.new("brade-alle-prefix", "brade")
    assert {:ok, engine, _} = Engine.join(engine, "nick", "tab-a")
    assert {:ok, engine, _} = Engine.join(engine, "jane", "tab-b")

    assert {:ok, engine} =
             Engine.submit_match_options(engine, %{"matchLength" => "3"}, "nick", "tab-a")

    points =
      Enum.map(0..23, fn index ->
        cond do
          index == 0 -> %{white: 1, black: 0}
          true -> %{white: 0, black: 0}
        end
      end)

    board = %{
      engine.board
      | points: points,
        outside: %{white: 14, black: 0},
        bar: %{white: 0, black: 0}
    }

    dice = %{
      values: [1, 1, 1, 1],
      moves: [1, 1, 1, 1],
      moves_left: [1, 1, 1, 1],
      moves_played: []
    }

    runtime = engine.runtime |> Map.put(:board, board) |> Map.put(:dice, dice)
    legal_moves = Backgammon.Rules.RaceCore.legal_moves(runtime, engine.variant, :white)

    assert Enum.any?(legal_moves, &(&1.from == 0 and &1.to == "home" and &1.die == 1))

    engine =
      %{
        engine
        | runtime: runtime,
          board: board,
          turn_color: :white,
          turn_number: 1,
          dice: dice,
          legal_moves: legal_moves
      }

    assert {:ok, engine} =
             Engine.move(engine, %{"from" => 0, "to" => "home", "die" => 1}, "nick", "tab-a")

    snapshot = Engine.snapshot(engine)

    assert snapshot["match"]["results"] == [
             %{"winner" => "white", "points" => 1, "kind" => "home"}
           ]

    assert snapshot["dice"] == nil
    assert snapshot["legal_moves"] == []
  end

  test "brade bearing off requires a checker in last position" do
    engine = Engine.new("brade-home-rule", "brade")
    assert {:ok, engine, _} = Engine.join(engine, "nick", "tab-a")
    assert {:ok, engine, _} = Engine.join(engine, "jane", "tab-b")

    assert {:ok, engine} =
             Engine.submit_match_options(engine, %{"matchLength" => "3"}, "nick", "tab-a")

    points =
      Enum.map(0..23, fn index ->
        cond do
          index == 3 -> %{white: 1, black: 0}
          index == 0 -> %{white: 14, black: 0}
          true -> %{white: 0, black: 0}
        end
      end)

    board = %{engine.board | points: points, outside: %{white: 0, black: 0}}
    runtime = %{engine.runtime | board: board}

    engine = %{
      engine
      | runtime: runtime,
        board: board,
        turn_color: :white,
        dice: %{values: [6, 1], moves: [6, 1], moves_left: [6], moves_played: []}
    }

    legal =
      Backgammon.Rules.RaceCore.legal_moves(
        Map.put(runtime, :dice, engine.dice),
        engine.variant,
        :white
      )

    refute Enum.any?(legal, &(&1.from == 0 and &1.to == "home"))
  end

  test "brade exact home numbers still belong to the checker in last position" do
    engine = Engine.new("brade-last-exact", "brade")
    assert {:ok, engine, _} = Engine.join(engine, "nick", "tab-a")
    assert {:ok, engine, _} = Engine.join(engine, "jane", "tab-b")

    assert {:ok, engine} =
             Engine.submit_match_options(engine, %{"matchLength" => "3"}, "nick", "tab-a")

    points =
      Enum.map(0..23, fn index ->
        cond do
          index == 2 -> %{white: 1, black: 0}
          index == 1 -> %{white: 1, black: 0}
          index == 0 -> %{white: 13, black: 0}
          true -> %{white: 0, black: 0}
        end
      end)

    board = %{engine.board | points: points, outside: %{white: 0, black: 0}}
    runtime = %{engine.runtime | board: board}
    dice = %{values: [2, 1], moves: [2, 1], moves_left: [2], moves_played: []}

    legal =
      Backgammon.Rules.RaceCore.legal_moves(Map.put(runtime, :dice, dice), engine.variant, :white)

    assert Enum.any?(legal, &(&1.from == 2 and &1.to == 0 and &1.die == 2))
    refute Enum.any?(legal, &(&1.from == 1 and &1.to == "home" and &1.die == 2))
  end

  test "brade keeps the minimum-reduction branch during ordinary home play" do
    engine = Engine.new("brade-min-reduction", "brade")
    assert {:ok, engine, _} = Engine.join(engine, "nick", "tab-a")
    assert {:ok, engine, _} = Engine.join(engine, "jane", "tab-b")

    assert {:ok, engine} =
             Engine.submit_match_options(engine, %{"matchLength" => "3"}, "nick", "tab-a")

    points =
      Enum.map(0..23, fn index ->
        cond do
          index == 4 -> %{white: 1, black: 0}
          index == 2 -> %{white: 1, black: 0}
          index == 0 -> %{white: 13, black: 0}
          true -> %{white: 0, black: 0}
        end
      end)

    board = %{
      engine.board
      | points: points,
        outside: %{white: 0, black: 0},
        bar: %{white: 0, black: 0}
    }

    runtime = %{engine.runtime | board: board}
    dice = %{values: [6, 4], moves: [6, 4], moves_left: [6, 4], moves_played: []}

    legal =
      Backgammon.Rules.RaceCore.legal_moves(Map.put(runtime, :dice, dice), engine.variant, :white)

    assert Enum.any?(legal, &(&1.from == 4 and &1.to == "home" and &1.die == 6))
    refute Enum.any?(legal, &(&1.from == 4 and &1.to == 0 and &1.die == 4))
  end

  test "brade can detect a crown beau jeu" do
    engine = Engine.new("brade-crown", "brade")
    assert {:ok, engine, _} = Engine.join(engine, "nick", "tab-a")
    assert {:ok, engine, _} = Engine.join(engine, "jane", "tab-b")

    assert {:ok, engine} =
             Engine.submit_match_options(engine, %{"matchLength" => "3"}, "nick", "tab-a")

    points =
      Enum.map(0..23, fn index ->
        cond do
          index in 0..4 -> %{white: 3, black: 0}
          true -> %{white: 0, black: 0}
        end
      end)

    board = %{
      engine.board
      | points: points,
        outside: %{white: 0, black: 0},
        bar: %{white: 0, black: 0}
    }

    runtime = %{engine.runtime | board: board}

    engine = %{
      engine
      | runtime: runtime,
        board: board,
        turn_color: :white,
        dice: %{values: [5, 4], moves: [5, 4], moves_left: [], moves_played: [5, 4]}
    }

    assert {:ok, engine} = Engine.confirm(engine, "nick", "tab-a")
    snapshot = Engine.snapshot(engine)

    assert snapshot["match"]["results"] == [
             %{"winner" => "white", "points" => 2, "kind" => "crown"}
           ]
  end

  test "brade tie break compares the full sequence of best games" do
    engine = Engine.new("brade-tiebreak", "brade")
    assert {:ok, engine, _} = Engine.join(engine, "nick", "tab-a")
    assert {:ok, engine, _} = Engine.join(engine, "jane", "tab-b")

    assert {:ok, engine} =
             Engine.submit_match_options(engine, %{"matchLength" => "5"}, "nick", "tab-a")

    results = [
      %{winner: "white", points: 2, kind: "crown"},
      %{winner: "white", points: 1, kind: "home"},
      %{winner: "black", points: 2, kind: "home_munk"},
      %{winner: "black", points: 2, kind: "double_crown"}
    ]

    runtime =
      engine.runtime
      |> Map.put(:variant_state, Map.put(engine.runtime.variant_state, :results, results))
      |> Map.put(:board, %{engine.board | outside: %{white: 15, black: 0}})

    engine =
      %{
        engine
        | runtime: runtime,
          board: runtime.board,
          turn_color: :white,
          dice: %{values: [1, 1], moves: [1, 1], moves_left: [], moves_played: [1, 1]}
      }
      |> put_in([:match, :score], %{white: 3, black: 4})

    assert {:ok, engine} = Engine.confirm(engine, "nick", "tab-a")
    snapshot = Engine.snapshot(engine)
    assert snapshot["match"]["winner"] == "black"
    assert snapshot["match"]["winner_kind"] == "brade_match"
  end
end
