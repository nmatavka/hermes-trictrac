defmodule HermesTrictrac.Rules.Trictrac.Classique.Types do
  @type color :: :white | :black
  @type table_key :: :petit | :grand | :retour
  @type board :: map()
  @type dice :: map()
  @type score_rule :: atom()
  @type score_source :: atom() | String.t()
end

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

  @type t :: %__MODULE__{
          points: integer(),
          trous: integer(),
          bredouille: boolean(),
          doubling_active: boolean(),
          grande_bredouille: boolean(),
          etendard: boolean()
        }
end

defmodule HermesTrictrac.Rules.Trictrac.Classique.OpeningState do
  alias HermesTrictrac.Rules.Trictrac.Classique.Types

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

  @type depart_done :: %{
          two_tables: boolean(),
          meseas: boolean(),
          six_tables: boolean()
        }

  @type t :: %__MODULE__{
          first_type: Types.color() | nil,
          first_values: [integer()] | nil,
          jan_rencontre_checked: boolean(),
          coups_by_type: %{Types.color() => non_neg_integer()},
          releve_count: non_neg_integer(),
          depart_done_by_type: %{Types.color() => depart_done()}
        }
end

defmodule HermesTrictrac.Rules.Trictrac.Classique.ScoreEvent do
  alias HermesTrictrac.Rules.Trictrac.Classique.Types

  use HermesTrictrac.Rules.Trictrac.AccessStruct,
    fields: [
      rule: nil,
      label: nil,
      piece_type: nil,
      beneficiary: nil,
      points: 0,
      trous_delta: 0,
      turn_number: nil,
      source: nil,
      metadata: %{}
    ]

  @type t :: %__MODULE__{
          rule: Types.score_rule() | nil,
          label: String.t() | nil,
          piece_type: String.t() | nil,
          beneficiary: String.t() | nil,
          points: integer(),
          trous_delta: integer(),
          turn_number: integer() | nil,
          source: Types.score_source() | nil,
          metadata: map()
        }
end

defmodule HermesTrictrac.Rules.Trictrac.Classique.ConservationCandidate do
  alias HermesTrictrac.Rules.Trictrac.Classique.Types

  use HermesTrictrac.Rules.Trictrac.AccessStruct,
    fields: [
      key: nil,
      points: 0,
      allow_sortie: false,
      outside_before: 0
    ]

  @type t :: %__MODULE__{
          key: Types.table_key() | nil,
          points: integer(),
          allow_sortie: boolean(),
          outside_before: non_neg_integer()
        }
end

defmodule HermesTrictrac.Rules.Trictrac.Classique.Obligation do
  alias HermesTrictrac.Rules.Trictrac.Classique.{ConservationCandidate, Types}

  use HermesTrictrac.Rules.Trictrac.AccessStruct,
    fields: [
      piece_type: nil,
      must_fill: [],
      must_conserve: []
    ]

  @type t :: %__MODULE__{
          piece_type: String.t() | nil,
          must_fill: [Types.table_key()],
          must_conserve: [ConservationCandidate.t()]
        }
end

defmodule HermesTrictrac.Rules.Trictrac.Classique.TurnState do
  alias HermesTrictrac.Rules.Trictrac.Classique.{
    ConservationCandidate,
    Obligation,
    ScoreEvent,
    Types
  }

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

  @type t :: %__MODULE__{
          piece_type: Types.color() | nil,
          events: [ScoreEvent.t()],
          score_by_type: %{Types.color() => integer()},
          obligations: Obligation.t(),
          conservation_candidates: [ConservationCandidate.t()],
          pile_misere_candidate: map() | nil,
          pile_misere_pending: boolean(),
          trous_before: %{Types.color() => integer()},
          trous_after: %{Types.color() => integer()},
          can_reprise: boolean(),
          reprise_color: Types.color() | nil,
          start_board: Types.board() | nil,
          dice: Types.dice() | nil
        }
end

defmodule HermesTrictrac.Rules.Trictrac.Classique.BranchAnalysis do
  alias HermesTrictrac.Rules.Trictrac.Classique.Types

  use HermesTrictrac.Rules.Trictrac.AccessStruct,
    fields: [
      branches: [],
      max_played: 0
    ]

  @type t :: %__MODULE__{
          branches: [Types.board()],
          max_played: non_neg_integer()
        }
end

defmodule HermesTrictrac.Rules.Trictrac.Classique.TurnAnalysis do
  alias HermesTrictrac.Rules.Trictrac.Classique.{
    ConservationCandidate,
    Obligation,
    OpeningState,
    ScoreEvent
  }

  use HermesTrictrac.Rules.Trictrac.AccessStruct,
    fields: [
      opening: nil,
      obligations: %Obligation{},
      conservation_candidates: [],
      pile_misere_candidate: nil,
      pile_misere_pending: false,
      events: []
    ]

  @type t :: %__MODULE__{
          opening: OpeningState.t() | nil,
          obligations: Obligation.t(),
          conservation_candidates: [ConservationCandidate.t()],
          pile_misere_candidate: map() | nil,
          pile_misere_pending: boolean(),
          events: [ScoreEvent.t()]
        }
end
