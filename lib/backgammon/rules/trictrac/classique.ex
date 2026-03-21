defmodule Backgammon.Rules.Trictrac.Classique do
  alias Backgammon.Rules.Trictrac.Classique.{
    Branches,
    Events,
    Moves,
    Opening,
    Scoring,
    State,
    Validation
  }

  def ensure(trictrac), do: State.ensure(trictrac)
  def apply_options(trictrac, options), do: State.apply_options(trictrac, options)

  def begin_turn(trictrac, board, variant, color, dice) do
    trictrac = State.ensure(trictrac)
    branches_info = Branches.best_end_branches(board, variant, color, dice)
    unplayable = max(0, State.impuissance_base(dice) - branches_info.max_played)

    opening =
      trictrac.opening
      |> Opening.remember_first_throw(color, dice)
      |> update_in([:coups_by_type, color], &((&1 || 0) + 1))

    trictrac
    |> Map.put(:opening, opening)
    |> put_in([:pending_impuissance_by_type, color], unplayable * 2)
    |> put_in(
      [:coin_rest_start_count_by_type, color],
      Moves.coin_count_from_board(board, State.own_coin(color), color)
    )
    |> Map.put(:turn, %{
      State.turn_state()
      | piece_type: color,
        trous_before: %{
          white: State.trous_for(trictrac, :white),
          black: State.trous_for(trictrac, :black)
        },
        start_board: board,
        dice: dice
    })
  end

  def finalize_turn(trictrac, board, variant, color, turn_number) do
    trictrac = State.ensure(trictrac)
    turn = trictrac.turn || State.turn_state()
    dice = turn.dice || %{values: [], moves: [], moves_left: [], moves_played: []}
    start_board = turn.start_board || board
    analysis = Events.detect_turn_events(start_board, board, variant, color, dice, trictrac)

    trictrac =
      Enum.reduce(analysis.events, trictrac, fn event, acc ->
        beneficiary = beneficiary_atom(event.beneficiary)

        Scoring.apply_points(
          acc,
          beneficiary,
          event.points,
          event.label,
          turn_number,
          event.source,
          event.metadata
        )
      end)

    trous_after = %{
      white: State.trous_for(trictrac, :white),
      black: State.trous_for(trictrac, :black)
    }

    can_reprise = trous_after[color] > turn.trous_before[color]

    trictrac
    |> put_in([:opening], analysis.opening)
    |> put_in([:turn, :events], analysis.events)
    |> put_in([:turn, :obligations], analysis.obligations)
    |> put_in([:turn, :conservation_candidates], analysis.conservation_candidates)
    |> put_in([:turn, :pile_misere_candidate], analysis.pile_misere_candidate)
    |> put_in([:turn, :pile_misere_pending], analysis.pile_misere_pending)
    |> put_in([:pile_misere_pending_by_type, color], analysis.pile_misere_pending)
    |> put_in([:turn, :trous_after], trous_after)
    |> put_in([:turn, :can_reprise], can_reprise)
    |> Scoring.maybe_record_sortie_event(color, turn_number)
    |> Map.put(:last_events, Enum.map(analysis.events, &State.event_label/1))
  end

  def destination_forbidden_by_jan_interdit?(board, color, destination),
    do: Moves.destination_forbidden_by_jan_interdit?(board, color, destination)

  def validate_turn(trictrac, board, variant, color) do
    trictrac = State.ensure(trictrac)
    turn = trictrac.turn || State.turn_state()
    start_board = turn.start_board || board
    dice = turn.dice || %{values: [], moves: [], moves_left: [], moves_played: []}
    analysis = Events.detect_turn_events(start_board, board, variant, color, dice, trictrac)

    cond do
      not Validation.coin_rest_satisfied?(board, variant, color) ->
        {:error, :coin_rest}

      Validation.obligations_satisfied?(board, color, analysis.obligations) ->
        {:ok, analysis}

      true ->
        {:error, analysis.obligations}
    end
  end

  def set_turn_event_queue(trictrac, events), do: State.set_turn_event_queue(trictrac, events)
  def shift_turn_event_queue(trictrac), do: State.shift_turn_event_queue(trictrac)
  def current_pending_event(trictrac), do: State.current_pending_event(trictrac)
  def clear_scores(trictrac), do: State.clear_scores(trictrac)
  def reset_opening_for_releve(trictrac), do: State.reset_opening_for_releve(trictrac)
  def sortie_awarded?(trictrac), do: State.sortie_awarded?(trictrac)

  def mark_sortie_releve(trictrac, color, turn_number),
    do: State.mark_sortie_releve(trictrac, color, turn_number)

  def trous_for(trictrac, color), do: State.trous_for(trictrac, color)
  def points_for(trictrac, color), do: State.points_for(trictrac, color)
  def own_coin(color), do: State.own_coin(color)
  def opp_coin(color), do: State.opp_coin(color)
  def table_full?(board, color, key), do: Moves.table_full?(board, color, key)

  def apply_points(trictrac, color, points, label, turn_number, source \\ nil, metadata \\ %{}),
    do: Scoring.apply_points(trictrac, color, points, label, turn_number, source, metadata)

  def legal_moves(runtime, variant, color), do: Moves.legal_moves(runtime, variant, color)

  defp beneficiary_atom("white"), do: :white
  defp beneficiary_atom("black"), do: :black
  defp beneficiary_atom(:white), do: :white
  defp beneficiary_atom(:black), do: :black
end
