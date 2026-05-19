defmodule HermesTrictrac.Rules.Trictrac.Classique.Events.Context do
  @enforce_keys [
    :start_board,
    :end_board,
    :variant,
    :color,
    :dice,
    :trictrac,
    :opening,
    :coup_index,
    :board_changed,
    :branches_info,
    :is_double,
    :conservation_candidates,
    :pile_misere
  ]

  defstruct [
    :start_board,
    :end_board,
    :variant,
    :color,
    :dice,
    :trictrac,
    :opening,
    :coup_index,
    :board_changed,
    :branches_info,
    :is_double,
    :conservation_candidates,
    :pile_misere,
    depart_done: %{two_tables: false, meseas: false, six_tables: false},
    obligations: nil,
    pile_misere_candidate: nil,
    pile_misere_pending: false
  ]

  @type t :: %__MODULE__{}
end
