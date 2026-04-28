defmodule HermesTrictrac.Rules.Trictrac.Classique.Branches do
  alias HermesTrictrac.Rules.Trictrac.Classique.{BranchAnalysis, Moves, State}

  def best_end_branches(board, variant, color, dice) do
    branches =
      enumerate_branches(board, variant, color, State.dice_values(dice))

    max_played =
      branches
      |> Enum.map(& &1.played)
      |> Enum.max(fn -> 0 end)

    %BranchAnalysis{
      branches:
        branches
        |> Enum.filter(&(&1.played == max_played))
        |> Enum.map(& &1.board),
      max_played: max_played
    }
  end

  def enumerate_branches(board, variant, color, moves_left, played \\ 0) do
    moves =
      board
      |> Moves.raw_legal_moves(variant, color, moves_left)
      |> Enum.uniq_by(fn move ->
        {move.from, move.to, move.die, Map.get(move, :dice_used), Map.get(move, :via),
         Map.get(move, :sequence)}
      end)

    cond do
      moves_left == [] ->
        [%{board: board, played: played}]

      moves == [] ->
        [%{board: board, played: played}]

      true ->
        Enum.flat_map(moves, fn move ->
          next_board = Moves.apply_step_move(board, color, move)
          next_moves = State.remove_all_used(moves_left, Map.get(move, :dice_used, [move.die]))

          enumerate_branches(
            next_board,
            variant,
            color,
            next_moves,
            played + length(Map.get(move, :dice_used, [move.die]))
          )
        end)
    end
  end
end
