defmodule HermesTrictrac.Rules.Trictrac.Classique.Branches do
  alias HermesTrictrac.Rules.Trictrac.Classique.{BranchAnalysis, Moves, State}

  def best_end_branches(board, variant, color, dice) do
    moves = full_turn_moves(dice)

    branches =
      enumerate_branches(board, variant, color, moves)

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
    dice = %{
      values: moves_left,
      moves: moves_left,
      moves_left: moves_left,
      moves_played: []
    }

    enumerate_runtime_branches(%{board: board, dice: dice}, variant, color, played)
  end

  defp enumerate_runtime_branches(runtime, variant, color, played) do
    moves =
      runtime
      |> Moves.legal_moves(variant, color)
      |> Enum.uniq_by(fn move ->
        {move.from, move.to, move.die, Map.get(move, :dice_used), Map.get(move, :via),
         Map.get(move, :sequence)}
      end)

    moves_left = Map.get(runtime.dice || %{}, :moves_left, [])

    cond do
      moves_left == [] ->
        [%{board: runtime.board, played: played}]

      moves == [] ->
        [%{board: runtime.board, played: played}]

      true ->
        Enum.flat_map(moves, fn move ->
          used = Map.get(move, :dice_used, [move.die])
          next_board = Moves.apply_step_move(runtime.board, color, move)
          next_moves = State.remove_all_used(moves_left, used)
          dice = runtime.dice || %{}

          next_runtime = %{
            runtime
            | board: next_board,
              dice:
                dice
                |> Map.put(:moves_left, next_moves)
                |> Map.put(:moves_played, Map.get(dice, :moves_played, []) ++ used)
          }

          enumerate_runtime_branches(
            next_runtime,
            variant,
            color,
            played + length(used)
          )
        end)
    end
  end

  defp full_turn_moves(dice) do
    cond do
      is_list(Map.get(dice || %{}, :moves)) and Map.get(dice, :moves) != [] ->
        Map.get(dice, :moves)

      is_list(Map.get(dice || %{}, :moves_left)) and Map.get(dice, :moves_left) != [] ->
        Map.get(dice, :moves_left)

      true ->
        State.dice_values(dice)
    end
  end
end
