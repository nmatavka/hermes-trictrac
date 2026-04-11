defmodule HermesTrictrac.Rules.Trictrac.Classique.ScoreEntry do
  use HermesTrictrac.Rules.Trictrac.AccessStruct,
    fields: [
      points: 0,
      trous: 0,
      bredouille: false,
      doubling_active: true,
      grande_bredouille: false,
      etendard: false
    ]
end

defmodule HermesTrictrac.Rules.Trictrac.Classique.OpeningState do
  use HermesTrictrac.Rules.Trictrac.AccessStruct,
    fields: [
      first_type: nil,
      first_values: nil,
      jan_rencontre_checked: false,
      coups_by_type: %{white: 0, black: 0},
      releve_count: 0,
      depart_done_by_type: %{
        white: %{two_tables: false, meseas: false, six_tables: false},
        black: %{two_tables: false, meseas: false, six_tables: false}
      }
    ]
end

defmodule HermesTrictrac.Rules.Trictrac.Classique.ScoreEvent do
  use HermesTrictrac.Rules.Trictrac.AccessStruct,
    fields: [
      label: nil,
      piece_type: nil,
      beneficiary: nil,
      points: 0,
      trous_delta: 0,
      turn_number: nil,
      source: nil,
      metadata: %{}
    ]
end

defmodule HermesTrictrac.Rules.Trictrac.Classique.ConservationCandidate do
  use HermesTrictrac.Rules.Trictrac.AccessStruct,
    fields: [
      key: nil,
      points: 0,
      allow_sortie: false,
      outside_before: 0
    ]
end

defmodule HermesTrictrac.Rules.Trictrac.Classique.Obligation do
  use HermesTrictrac.Rules.Trictrac.AccessStruct,
    fields: [
      piece_type: nil,
      must_fill: [],
      must_conserve: []
    ]
end

defmodule HermesTrictrac.Rules.Trictrac.Classique.TurnState do
  alias HermesTrictrac.Rules.Trictrac.Classique.Obligation

  use HermesTrictrac.Rules.Trictrac.AccessStruct,
    fields: [
      piece_type: nil,
      events: [],
      score_by_type: %{white: 0, black: 0},
      obligations: %Obligation{},
      conservation_candidates: [],
      pile_misere_candidate: nil,
      pile_misere_pending: false,
      trous_before: %{white: 0, black: 0},
      trous_after: %{white: 0, black: 0},
      can_reprise: false,
      reprise_color: nil,
      start_board: nil,
      dice: nil
    ]
end

defmodule HermesTrictrac.Rules.Trictrac.Classique.BranchAnalysis do
  use HermesTrictrac.Rules.Trictrac.AccessStruct,
    fields: [
      branches: [],
      max_played: 0
    ]
end

defmodule HermesTrictrac.Rules.Trictrac.Classique.TurnAnalysis do
  alias HermesTrictrac.Rules.Trictrac.Classique.Obligation

  use HermesTrictrac.Rules.Trictrac.AccessStruct,
    fields: [
      opening: nil,
      obligations: %Obligation{},
      conservation_candidates: [],
      pile_misere_candidate: nil,
      pile_misere_pending: false,
      events: []
    ]
end
