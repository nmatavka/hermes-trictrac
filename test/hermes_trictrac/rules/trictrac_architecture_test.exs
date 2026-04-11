defmodule HermesTrictrac.Rules.TrictracArchitectureTest do
  use ExUnit.Case, async: true

  alias HermesTrictrac.Rules.Engine
  alias HermesTrictrac.Rules.Snapshot
  alias HermesTrictrac.Rules.Trictrac.Classique
  alias HermesTrictrac.Rules.Trictrac.Classique.{
    BranchAnalysis,
    Branches,
    ConservationCandidate,
    Obligation,
    ScoreEvent,
    Validation
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
          must_conserve: [%ConservationCandidate{key: :retour, allow_sortie: true, outside_before: 0}]
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
    assert get_in(snapshot, ["trictrac", "turn", "obligations", "must_conserve", Access.at(0), "key"]) == "retour"
    refute inspect(snapshot["trictrac"]) =~ "__struct__"
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
