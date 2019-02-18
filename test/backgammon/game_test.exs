defmodule GameTest do
  use ExUnit.Case

  alias Backgammon.Game
  alias Backgammon.MoveGenerator

  test "possible moves for red with knocked pieces" do
    slots = [%{idx: 0}, %{idx: 1}, %{idx: 2}, %{idx: 3}]
    game = %{
      slots: slots,
      whose_turn: :red,
      knocked: %{
        red: 1,
        white: 1
      },
      current_dice: [1],
    }
    moves = MoveGenerator.possible_moves(game)
    assert moves == [[:knocked, 3]]

    game = %{game | whose_turn: :white}
    moves = MoveGenerator.possible_moves(game)
    assert moves == [[:knocked, 0]]
  end

  test "changes turn when no possible moves" do
    slots = [%{idx: 0, owner: :white, num: 1}, %{idx: 1}]
    game = %{
      slots: slots,
      whose_turn: :white,
      knocked: %{
        red: 0,
        white: 0,
      },
      home: %{
        red: 0,
        white: 0
      },
      current_dice: [1, 5],
      players: %{
        x: :white,
        y: :red
      }
    }
    {:ok, g} = Game.move(game, [0, 1], :x)
    assert g.whose_turn == :red
    assert g.current_dice == []
  end

end
