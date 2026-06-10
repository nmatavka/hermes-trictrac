defmodule HermesTrictrac.Rules.TrictracArchitectureTest do
  use ExUnit.Case, async: true

  alias HermesTrictrac.Rules.Engine
  alias HermesTrictrac.Rules.Snapshot
  alias HermesTrictrac.Rules.Trictrac.Classique

  alias HermesTrictrac.Rules.Trictrac.Classique.{
    BranchAnalysis,
    Branches,
    ConservationCandidate,
    Constants,
    Dice,
    Events.Context,
    Events.RuleResult,
    Moves,
    Obligation,
    Opening,
    OpeningState,
    Scoring,
    ScoreEvent,
    State,
    Validation,
    Events.Ways
  }

  test "best_end_branches returns a typed analysis with playable end boards" do
    board =
      empty_board()
      |> put_piece(:white, 23, 2)
      |> put_piece(:white, 22, 2)

    analysis =
      Branches.best_end_branches(board, %{id: "trictrac_classique", total_pieces: 15}, :white, %{
        values: [1, 1],
        moves: [],
        moves_left: [1, 1, 1, 1],
        moves_played: []
      })

    assert %BranchAnalysis{} = analysis
    assert analysis.max_played > 0
    assert length(analysis.branches) > 0
  end

  test "best_end_state_by matches scored best leaf selection without materializing all winners" do
    variant = %{id: "trictrac_classique", total_pieces: 15}

    board =
      empty_board()
      |> put_piece(:white, 23, 2)
      |> put_piece(:white, 22, 2)
      |> put_piece(:white, 20, 1)

    dice = %{values: [2, 1], moves: [2, 1], moves_left: [2, 1], moves_played: []}
    runtime = %{board: board, dice: dice}

    scorer = fn leaf_runtime, _played ->
      score =
        Moves.pieces_at(leaf_runtime.board, 23, :white) +
          Moves.pieces_at(leaf_runtime.board, 22, :white) * 10

      {score, :erlang.term_to_binary(leaf_runtime.board, [:deterministic])}
    end

    expected =
      runtime
      |> Branches.best_end_states(variant, :white)
      |> Enum.map(fn leaf ->
        leaf_runtime = %{board: leaf.board, dice: leaf.dice}
        {score, sort_key} = scorer.(leaf_runtime, leaf.played)
        %{board: leaf.board, dice: leaf.dice, played: leaf.played, score: score, sort_key: sort_key}
      end)
      |> Enum.reduce(nil, fn candidate, best ->
        cond do
          best == nil -> candidate
          candidate.played > best.played -> candidate
          candidate.played < best.played -> best
          candidate.score > best.score -> candidate
          candidate.score < best.score -> best
          candidate.sort_key < best.sort_key -> candidate
          true -> best
        end
      end)

    best = Branches.best_end_state_by(runtime, variant, :white, scorer)

    assert best.played == expected.played
    assert best.score == expected.score
    assert best.sort_key == expected.sort_key
    assert best.board == expected.board
    assert best.dice == expected.dice
  end

  test "best_end_state_by supports canonical dice memoization without changing best leaf selection" do
    variant = %{id: "trictrac_classique", total_pieces: 15}

    board =
      empty_board()
      |> put_piece(:white, 23, 2)
      |> put_piece(:white, 22, 2)
      |> put_piece(:white, 20, 1)

    runtime_a = %{board: board, dice: %{values: [2, 1], moves: [2, 1], moves_left: [2, 1], moves_played: []}}
    runtime_b = %{board: board, dice: %{values: [2, 1], moves: [2, 1], moves_left: [1, 2], moves_played: []}}

    scorer = fn leaf_runtime, _played ->
      score =
        Moves.pieces_at(leaf_runtime.board, 23, :white) +
          Moves.pieces_at(leaf_runtime.board, 22, :white) * 10

      {score, :erlang.term_to_binary(leaf_runtime.board, [:deterministic])}
    end

    best_a = Branches.best_end_state_by(runtime_a, variant, :white, scorer, canonical_dice_for_memo: true)
    best_b = Branches.best_end_state_by(runtime_b, variant, :white, scorer, canonical_dice_for_memo: true)

    assert best_a.played == best_b.played
    assert best_a.score == best_b.score
    assert best_a.sort_key == best_b.sort_key
    assert best_a.board == best_b.board
  end

  test "best_end_state_by greedy branch-width-1 mode matches explicit greedy leaf walk" do
    variant = %{id: "trictrac_classique", total_pieces: 15}

    board =
      empty_board()
      |> put_piece(:white, 23, 2)
      |> put_piece(:white, 22, 2)
      |> put_piece(:white, 20, 1)

    runtime = %{board: board, dice: %{values: [2, 1], moves: [2, 1], moves_left: [2, 1], moves_played: []}}

    scorer = fn leaf_runtime, _played ->
      score =
        Moves.pieces_at(leaf_runtime.board, 23, :white) +
          Moves.pieces_at(leaf_runtime.board, 22, :white) * 10

      {score, :erlang.term_to_binary(leaf_runtime.board, [:deterministic])}
    end

    move_ranker = fn current_runtime, move ->
      used = Map.get(move, :dice_used, [move.die])
      next_board = Moves.apply_step_move(current_runtime.board, :white, move)
      score = Moves.pieces_at(next_board, 23, :white) + Moves.pieces_at(next_board, 22, :white) * 10
      {length(used), score}
    end

    best =
      Branches.best_end_state_by(
        runtime,
        variant,
        :white,
        scorer,
        max_branch_moves: 1,
        move_ranker: move_ranker
      )

    greedy =
      greedy_reference_leaf(
        runtime,
        variant,
        :white,
        scorer,
        move_ranker,
        0
      )

    assert best.played == greedy.played
    assert best.score == greedy.score
    assert best.sort_key == greedy.sort_key
    assert best.board == greedy.board
    assert best.dice == greedy.dice
  end

  test "best_end_state_by greedy primary ranker skips secondary scoring for discarded root moves" do
    variant = %{id: "trictrac_classique", total_pieces: 15}

    board =
      empty_board()
      |> put_piece(:white, 23, 2)
      |> put_piece(:white, 22, 2)
      |> put_piece(:white, 20, 1)

    runtime = %{board: board, dice: %{values: [2, 1], moves: [2, 1], moves_left: [2, 1], moves_played: []}}
    root_moves_left = runtime.dice.moves_left
    root_board = runtime.board
    rank_counts = :ets.new(:rank_counts, [:set, :public])

    scorer = fn leaf_runtime, _played ->
      score =
        Moves.pieces_at(leaf_runtime.board, 23, :white) +
          Moves.pieces_at(leaf_runtime.board, 22, :white) * 10

      {score, :erlang.term_to_binary(leaf_runtime.board, [:deterministic])}
    end

    tuple_move_ranker = fn current_runtime, move ->
      used = Map.get(move, :dice_used, [move.die])
      next_board = Moves.apply_step_move(current_runtime.board, :white, move)
      score = Moves.pieces_at(next_board, 23, :white) + Moves.pieces_at(next_board, 22, :white) * 10
      {length(used), score}
    end

    filtered_move_ranker = fn current_runtime, move ->
      used = Map.get(move, :dice_used, [move.die])

      if current_runtime.board == root_board and Map.get(current_runtime.dice || %{}, :moves_left, []) == root_moves_left do
        :ets.update_counter(rank_counts, length(used), {2, 1}, {length(used), 0})
      end

      next_board = Moves.apply_step_move(current_runtime.board, :white, move)
      Moves.pieces_at(next_board, 23, :white) + Moves.pieces_at(next_board, 22, :white) * 10
    end

    try do
      baseline =
        Branches.best_end_state_by(
          runtime,
          variant,
          :white,
          scorer,
          max_branch_moves: 1,
          move_ranker: tuple_move_ranker
        )

      filtered =
        Branches.best_end_state_by(
          runtime,
          variant,
          :white,
          scorer,
          max_branch_moves: 1,
          move_primary_ranker: fn move ->
            move
            |> Map.get(:dice_used, [move.die])
            |> length()
          end,
          move_ranker: filtered_move_ranker
        )

      assert filtered.played == baseline.played
      assert filtered.score == baseline.score
      assert filtered.sort_key == baseline.sort_key
      assert filtered.board == baseline.board
      assert filtered.dice == baseline.dice
      assert root_rank_count(rank_counts, 1) == 0
      assert root_rank_count(rank_counts, 2) == 10
    after
      :ets.delete(rank_counts)
    end
  end

  test "best_end_branches ignores raw coin-rest singleton branches for conservation" do
    variant = %{id: "trictrac_classique", family: :trictrac, total_pieces: 15}

    board =
      empty_board()
      |> Map.put(:outside, %{white: 1, black: 0})
      |> fill_range(:white, 18, 23, 2)
      |> put_piece(:white, State.own_coin(:white), 2)

    dice = %{values: [6, 1], moves: [6, 1], moves_left: [6, 1], moves_played: []}
    analysis = Branches.best_end_branches(board, variant, :white, dice)

    refute Enum.any?(analysis.branches, &Moves.all_paired?(&1, :white, 18, 23))

    refute Enum.any?(
             analysis.branches,
             &(Moves.pieces_at(&1, State.own_coin(:white), :white) == 1)
           )

    assert Validation.build_conservation_candidates(board, variant, :white, dice, analysis) == []
  end

  test "petit jan conservation is not forced when spare men cannot pass into protected cases" do
    variant = %{id: "trictrac_classique", family: :trictrac, total_pieces: 15}

    board =
      empty_board()
      |> fill_range(:white, 18, 23, 2)
      |> put_piece(:white, 17, 2)
      |> put_piece(:white, 15, 1)
      |> put_piece(:black, 0, 13)
      |> put_piece(:black, 10, 2)

    dice = %{values: [6, 1], moves: [6, 1], moves_left: [6, 1], moves_played: []}
    analysis = Branches.best_end_branches(board, variant, :white, dice)

    refute Enum.any?(analysis.branches, &Moves.all_paired?(&1, :white, 18, 23))
    assert Validation.build_conservation_candidates(board, variant, :white, dice, analysis) == []
  end

  test "material jan fillability distinguishes blocked, grand-only, and open retour phases" do
    variant = %{id: "trictrac_classique", family: :trictrac, total_pieces: 15}

    petit_alive_board =
      empty_board()
      |> fill_range(:black, 0, 5, 2)

    grand_only_board =
      empty_board()
      |> put_piece(:black, 11, 6)
      |> put_piece(:black, 10, 4)
      |> put_piece(:black, 8, 3)
      |> put_piece(:black, 6, 2)

    grand_dead_board =
      empty_board()
      |> put_piece(:black, 11, 7)
      |> put_piece(:black, 10, 5)
      |> put_piece(:black, 8, 1)
      |> put_piece(:black, 0, 2)

    assert Moves.can_opponent_still_fill_jan?(petit_alive_board, variant, :black, 18)
    assert Moves.can_opponent_still_fill_jan?(petit_alive_board, variant, :black, 12)

    refute Moves.can_opponent_still_fill_jan?(grand_only_board, variant, :black, 18)
    assert Moves.can_opponent_still_fill_jan?(grand_only_board, variant, :black, 12)

    refute Moves.can_opponent_still_fill_jan?(grand_dead_board, variant, :black, 18)
    refute Moves.can_opponent_still_fill_jan?(grand_dead_board, variant, :black, 12)
  end

  test "obligation building and satisfaction stay paired" do
    start_board =
      empty_board()
      |> fill_range(:white, 13, 17, 2)
      |> put_piece(:white, 12, 1)

    end_board = put_piece(start_board, :white, 12, 2)
    branches_info = %BranchAnalysis{branches: [end_board], max_played: 1}

    obligations =
      Validation.build_obligations(
        start_board,
        end_board,
        %{id: "trictrac_classique", total_pieces: 15},
        :white,
        %{values: [1, 1], moves: [], moves_left: [1, 1], moves_played: []},
        branches_info,
        [%ConservationCandidate{key: :grand, points: 4, allow_sortie: false, outside_before: 0}]
      )

    assert %Obligation{} = obligations
    assert obligations.must_fill == [:grand]
    assert Validation.obligations_satisfied?(end_board, :white, obligations)
    refute Validation.obligations_satisfied?(start_board, :white, obligations)
  end

  test "snapshot serializes nested trictrac structs without __struct__ leakage" do
    engine = Engine.new("tt-struct-snapshot", "trictrac_classique")

    trictrac =
      engine.trictrac
      |> Classique.ensure()
      |> put_in(
        [:turn, :events],
        [
          %ScoreEvent{
            label: "sortie",
            beneficiary: "white",
            points: 4,
            source: :SORTIE,
            metadata: %{resolution: :earned_now}
          }
        ]
      )
      |> put_in(
        [:turn, :obligations],
        %Obligation{
          piece_type: "white",
          must_fill: [:grand],
          must_conserve: [
            %ConservationCandidate{key: :retour, allow_sortie: true, outside_before: 0}
          ]
        }
      )
      |> put_in(
        [:score_history],
        [
          %ScoreEvent{
            label: "sortie",
            beneficiary: "white",
            points: 4,
            trous_delta: 0,
            turn_number: 1,
            source: :SORTIE,
            metadata: %{resolution: :earned_now}
          }
        ]
      )

    snapshot = Snapshot.build(%{engine | trictrac: trictrac})

    assert get_in(snapshot, ["trictrac", "turn", "events", Access.at(0), "source"]) == "SORTIE"
    assert get_in(snapshot, ["trictrac", "turn", "obligations", "must_fill"]) == ["grand"]

    assert get_in(snapshot, [
             "trictrac",
             "turn",
             "obligations",
             "must_conserve",
             Access.at(0),
             "key"
           ]) == "retour"

    refute inspect(snapshot["trictrac"]) =~ "__struct__"
  end

  test "rule result carries a typed event context" do
    context = %Context{
      start_board: empty_board(),
      end_board: empty_board(),
      variant: %{id: "trictrac_classique", total_pieces: 15},
      color: :white,
      dice: %{values: [1, 2]},
      trictrac: Classique.ensure(%{}),
      opening: State.opening_state(),
      coup_index: 1,
      board_changed: false,
      branches_info: %BranchAnalysis{},
      is_double: false,
      conservation_candidates: [],
      pile_misere: {nil, false}
    }

    assert %RuleResult{context: ^context, events: []} = RuleResult.new(context)
  end

  test "dice helpers normalize throws and reject malformed doubles" do
    assert Dice.normalized_throw(%{values: [6, 1]}) == [1, 6]
    assert Dice.faces(%{values: [3, 3, 3, 3]}) == {:ok, {3, 3}}
    assert Dice.double?(%{values: [2, 2, 2, 2]})
    refute Dice.double?(%{values: [2, 3, 2]})
  end

  test "jan de rencontre ignores dice order" do
    opening = %OpeningState{
      first_type: :white,
      first_values: [1, 6],
      jan_rencontre_checked: false
    }

    {events, updated_opening} =
      Opening.detect_jan_rencontre(
        [],
        :black,
        %{values: [6, 1]},
        opening,
        %{id: "trictrac_classique", total_pieces: 15}
      )

    assert updated_opening.jan_rencontre_checked

    assert Enum.any?(events, fn event ->
             event.label == "jan de rencontre" and event.beneficiary == "black"
           end)
  end

  test "opening coin jan detection handles expanded doubles without crashing" do
    depart_done = %OpeningState{}.depart_done_by_type.white

    assert {events, ^depart_done} =
             Opening.detect_coin_jans(
               [],
               empty_board(),
               empty_board(),
               :white,
               %{values: [3, 3, 3, 3]},
               1,
               depart_done,
               %{id: "trictrac_classique", total_pieces: 15}
             )

    assert events == []
  end

  test "state options and score source normalization tolerate serialized inputs" do
    assert State.apply_options(%{}, nil).options["margotEnabled"] == false

    assert State.normalize_source("jan de rencontre") ==
             Constants.score_source("jan de rencontre")

    assert State.normalize_source("JAN_RENCONTRE") == :JAN_RENCONTRE
    assert State.normalize_rule("jan de rencontre") == :jan_rencontre
    assert State.normalize_rule("JAN_RENCONTRE") == :jan_rencontre
  end

  test "turn scoring events include both piece type and beneficiary" do
    event = Scoring.event(:white, :sortie, 4)

    assert event.rule == :sortie
    assert event.label == "sortie"
    assert event.source == :SORTIE
    assert event.piece_type == "white"
    assert event.beneficiary == "white"
  end

  test "retour remplissage preserves an exact own-coin pair" do
    table = Enum.find(Constants.jan_tables(), &(&1.key == :retour))
    variant = %{id: "trictrac_classique", total_pieces: 15}

    exact_pair_board =
      empty_board()
      |> fill_range(:white, 0, 4, 2)
      |> put_piece(:white, 5, 1)
      |> put_piece(:white, State.own_coin(:white), 2)

    surcase_board =
      put_piece(exact_pair_board, :white, State.own_coin(:white), 3)

    dice = %{values: [4, 3]}

    assert Ways.remplissage_way_count(exact_pair_board, :white, table, dice, variant) == 0
    assert Ways.remplissage_way_count(surcase_board, :white, table, dice, variant) == 1
  end

  defp empty_board do
    %{
      points: Enum.map(0..23, fn _ -> %{white: 0, black: 0} end),
      bar: %{white: 0, black: 0},
      outside: %{white: 0, black: 0}
    }
  end

  defp put_piece(board, color, point, count) do
    put_in(board, [:points, Access.at(point), color], count)
  end

  defp fill_range(board, color, first, last, count) do
    Enum.reduce(first..last, board, fn point, acc ->
      put_piece(acc, color, point, count)
    end)
  end

  defp greedy_reference_leaf(runtime, variant, color, scorer, move_ranker, played) do
    moves =
      runtime
      |> Moves.legal_moves(variant, color)
      |> Enum.uniq_by(fn move ->
        {move.from, move.to, move.die, Map.get(move, :dice_used), Map.get(move, :via),
         Map.get(move, :sequence)}
      end)

    moves_left = Map.get(runtime.dice || %{}, :moves_left, [])

    cond do
      moves_left == [] or moves == [] ->
        {score, sort_key} = scorer.(runtime, played)
        %{board: runtime.board, dice: runtime.dice, played: played, score: score, sort_key: sort_key}

      true ->
        move =
          Enum.reduce(tl(moves), hd(moves), fn candidate, best ->
            candidate_rank =
              {move_ranker.(runtime, candidate),
               {candidate.from, candidate.to, candidate.die, Map.get(candidate, :dice_used), Map.get(candidate, :via),
                Map.get(candidate, :sequence)}}

            best_rank =
              {move_ranker.(runtime, best),
               {best.from, best.to, best.die, Map.get(best, :dice_used), Map.get(best, :via),
                Map.get(best, :sequence)}}

            if compare_ranked_move(candidate_rank, best_rank), do: candidate, else: best
          end)

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

        greedy_reference_leaf(next_runtime, variant, color, scorer, move_ranker, played + length(used))
    end
  end

  defp compare_ranked_move({left_rank, left_sort}, {right_rank, right_sort}) do
    cond do
      left_rank > right_rank -> true
      left_rank < right_rank -> false
      left_sort < right_sort -> true
      true -> false
    end
  end

  defp root_rank_count(table, rank) do
    case :ets.lookup(table, rank) do
      [{^rank, count}] -> count
      [] -> 0
    end
  end
end
