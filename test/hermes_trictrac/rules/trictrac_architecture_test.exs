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
end
