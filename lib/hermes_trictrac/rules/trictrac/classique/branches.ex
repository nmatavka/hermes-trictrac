defmodule HermesTrictrac.Rules.Trictrac.Classique.Branches do
  alias HermesTrictrac.Rules.Trictrac.Classique.{BranchAnalysis, Moves, State}

  def best_end_branches(board, variant, color, dice) do
    branches = enumerate_leaf_states(board, variant, color, dice)
    max_played = max_played(branches)

    %BranchAnalysis{
      branches:
        branches
        |> Enum.filter(&(&1.played == max_played))
        |> Enum.map(& &1.board),
      max_played: max_played
    }
  end

  def best_end_states(runtime, variant, color) when is_map(runtime) do
    branches = enumerate_runtime_leaf_states(runtime, variant, color)
    max_played = max_played(branches)

    branches
    |> Enum.filter(&(&1.played == max_played))
    |> Enum.map(&%{board: &1.board, dice: &1.dice, played: &1.played})
  end

  def best_end_state_by(runtime, variant, color, scorer)
      when is_map(runtime) and is_function(scorer, 2) do
    best_end_state_by(runtime, variant, color, scorer, [])
  end

  def best_end_state_by(runtime, variant, color, scorer, opts)
      when is_map(runtime) and is_function(scorer, 2) and is_list(opts) do
    best =
      if greedy_branch_mode?(opts) do
        greedy_runtime_leaf_state(runtime, variant, color, scorer, 0, opts)
      else
        memo = :ets.new(:trictrac_branch_leaf_cache, [:set, :public])

        try do
          best_runtime_leaf_state(runtime, variant, color, scorer, 0, memo, opts)
        after
          :ets.delete(memo)
        end
      end

    case best do
      nil ->
        nil

      best ->
        %{
          runtime: best.runtime,
          board: best.board,
          dice: best.dice,
          played: best.played,
          score: best.score,
          sort_key: best.sort_key
        }
    end
  end

  def enumerate_branches(board, variant, color, moves_left, played \\ 0) do
    dice = %{
      values: moves_left,
      moves: moves_left,
      moves_left: moves_left,
      moves_played: []
    }

    enumerate_runtime_leaf_states(%{board: board, dice: dice}, variant, color, played)
    |> Enum.map(&%{board: &1.board, played: &1.played})
  end

  defp enumerate_leaf_states(board, variant, color, dice) do
    moves = full_turn_moves(dice)
    enumerate_runtime_leaf_states(
      %{
        board: board,
        dice: %{
          values: moves,
          moves: moves,
          moves_left: moves,
          moves_played: []
        }
      },
      variant,
      color
    )
  end

  defp enumerate_runtime_leaf_states(runtime, variant, color, played \\ 0) do
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
        [%{board: runtime.board, dice: runtime.dice, played: played}]

      moves == [] ->
        [%{board: runtime.board, dice: runtime.dice, played: played}]

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

          enumerate_runtime_leaf_states(
            next_runtime,
            variant,
            color,
            played + length(used)
          )
        end)
    end
  end

  defp best_runtime_leaf_state(runtime, variant, color, scorer, played, memo, opts) do
    key = branch_leaf_memo_key(runtime, color, played, opts)

    case :ets.lookup(memo, key) do
      [{^key, best}] ->
        best

      [] ->
        best = compute_best_runtime_leaf_state(runtime, variant, color, scorer, played, memo, opts)
        true = :ets.insert(memo, {key, best})
        best
    end
  end

  defp compute_best_runtime_leaf_state(runtime, variant, color, scorer, played, memo, opts) do
    moves =
      runtime
      |> Moves.legal_moves(variant, color)
      |> Enum.uniq_by(fn move ->
        {move.from, move.to, move.die, Map.get(move, :dice_used), Map.get(move, :via),
         Map.get(move, :sequence)}
      end)
      |> maybe_limit_branch_moves(runtime, opts)

    moves_left = Map.get(runtime.dice || %{}, :moves_left, [])

    cond do
      moves_left == [] ->
        finalize_leaf(runtime, scorer, played)

      moves == [] ->
        finalize_leaf(runtime, scorer, played)

      true ->
        Enum.reduce(moves, nil, fn move, best ->
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

          candidate =
            best_runtime_leaf_state(
              next_runtime,
              variant,
              color,
              scorer,
              played + length(used),
              memo,
              opts
            )

          choose_better_leaf(best, candidate)
        end)
    end
  end

  defp branch_leaf_memo_key(runtime, color, played, opts) do
    {color, played, runtime.board, branch_leaf_dice_key(runtime.dice || %{}, opts)}
  end

  defp branch_leaf_dice_key(dice, opts) do
    if Keyword.get(opts, :canonical_dice_for_memo, false) do
      %{
        values: canonical_dice_component(Map.get(dice, :values, [])),
        moves: canonical_dice_component(Map.get(dice, :moves, [])),
        moves_left: canonical_dice_component(Map.get(dice, :moves_left, [])),
        moves_played: canonical_dice_component(Map.get(dice, :moves_played, []))
      }
    else
      %{
        values: Map.get(dice, :values, []),
        moves: Map.get(dice, :moves, []),
        moves_left: Map.get(dice, :moves_left, []),
        moves_played: Map.get(dice, :moves_played, [])
      }
    end
  end

  defp canonical_dice_component(values) when is_list(values), do: Enum.sort(values)
  defp canonical_dice_component(value), do: value

  defp maybe_limit_branch_moves(moves, runtime, opts) do
    max_branch_moves = Keyword.get(opts, :max_branch_moves, 0)
    move_ranker = Keyword.get(opts, :move_ranker)

    cond do
      !is_integer(max_branch_moves) or max_branch_moves <= 0 ->
        moves

      !is_function(move_ranker, 2) ->
        moves

      length(moves) <= max_branch_moves ->
        moves

      true ->
        moves
        |> Enum.sort(fn left, right ->
          compare_ranked_moves(
            {move_ranker.(runtime, left), move_sort_key(left)},
            {move_ranker.(runtime, right), move_sort_key(right)}
          )
        end)
        |> Enum.take(max_branch_moves)
    end
  end

  defp greedy_branch_mode?(opts) do
    Keyword.get(opts, :max_branch_moves, 0) == 1 and is_function(Keyword.get(opts, :move_ranker), 2)
  end

  defp greedy_runtime_leaf_state(runtime, variant, color, scorer, played, opts) do
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
        finalize_leaf(runtime, scorer, played)

      moves == [] ->
        finalize_leaf(runtime, scorer, played)

      true ->
        move = greedy_best_move(moves, runtime, opts, played)
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

        greedy_runtime_leaf_state(next_runtime, variant, color, scorer, played + length(used), opts)
    end
  end

  defp greedy_best_move([move], _runtime, _opts, _played), do: move

  defp greedy_best_move([first | rest], runtime, opts, played) do
    move_ranker = Keyword.fetch!(opts, :move_ranker)
    moves =
      [first | rest]
      |> maybe_filter_greedy_moves_by_primary_rank(opts)

    case moves do
      [move] ->
        move

      [filtered_first | filtered_rest] ->
        parallelism = greedy_root_parallelism(opts, played)

        if parallelism > 1 do
          parallel_greedy_best_move([filtered_first | filtered_rest], runtime, move_ranker, parallelism)
        else
          serial_greedy_best_move([filtered_first | filtered_rest], runtime, move_ranker)
        end
    end
  end

  defp maybe_filter_greedy_moves_by_primary_rank(moves, opts) do
    case Keyword.get(opts, :move_primary_ranker) do
      primary_ranker when is_function(primary_ranker, 1) and length(moves) > 1 ->
        best_primary_rank =
          Enum.reduce(tl(moves), primary_ranker.(hd(moves)), fn move, best_rank ->
            rank = primary_ranker.(move)
            if rank > best_rank, do: rank, else: best_rank
          end)

        Enum.filter(moves, &(primary_ranker.(&1) == best_primary_rank))

      _ ->
        moves
    end
  end

  defp serial_greedy_best_move([first | rest], runtime, move_ranker) do
    Enum.reduce(rest, first, fn candidate, best ->
      if compare_ranked_moves(
           {move_ranker.(runtime, candidate), move_sort_key(candidate)},
           {move_ranker.(runtime, best), move_sort_key(best)}
         ) do
        candidate
      else
        best
      end
    end)
  end

  defp parallel_greedy_best_move(moves, runtime, move_ranker, parallelism) do
    moves
    |> Task.async_stream(
      fn move ->
        {move_ranker.(runtime, move), move_sort_key(move), move}
      end,
      ordered: true,
      max_concurrency: min(length(moves), parallelism),
      timeout: :infinity
    )
    |> Enum.reduce(nil, fn {:ok, {rank, sort_key, move}}, best ->
      if is_nil(best) or compare_ranked_moves({rank, sort_key}, {elem(best, 0), elem(best, 1)}) do
        {rank, sort_key, move}
      else
        best
      end
    end)
    |> elem(2)
  end

  defp greedy_root_parallelism(opts, 0) do
    case Keyword.get(opts, :parallel_root_move_ranking, 1) do
      value when is_integer(value) and value > 1 -> value
      _ -> 1
    end
  end

  defp greedy_root_parallelism(_opts, _played), do: 1

  defp compare_ranked_moves({left_rank, left_sort}, {right_rank, right_sort}) do
    cond do
      left_rank > right_rank -> true
      left_rank < right_rank -> false
      left_sort < right_sort -> true
      true -> false
    end
  end

  defp move_sort_key(move) do
    {
      move.from,
      move.to,
      move.die,
      Map.get(move, :dice_used),
      Map.get(move, :via),
      Map.get(move, :sequence)
    }
  end

  defp finalize_leaf(runtime, scorer, played) do
    {score, sort_key} = scorer.(runtime, played)

    %{
      runtime: runtime,
      board: runtime.board,
      dice: runtime.dice,
      played: played,
      score: score,
      sort_key: sort_key
    }
  end

  defp choose_better_leaf(nil, candidate), do: candidate
  defp choose_better_leaf(candidate, nil), do: candidate

  defp choose_better_leaf(best, candidate) do
    cond do
      candidate.played > best.played -> candidate
      candidate.played < best.played -> best
      candidate.score > best.score -> candidate
      candidate.score < best.score -> best
      candidate.sort_key < best.sort_key -> candidate
      true -> best
    end
  end

  defp max_played(branches) do
    branches
    |> Enum.map(& &1.played)
    |> Enum.max(fn -> 0 end)
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
