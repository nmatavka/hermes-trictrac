defmodule HermesTrictrac.Rules.Trictrac.Classique.State do
  alias HermesTrictrac.Rules.Trictrac.Classique.{
    ConservationCandidate,
    Constants,
    Obligation,
    OpeningState,
    ScoreEntry,
    ScoreEvent,
    TurnState
  }

  alias HermesTrictrac.Rules.Trictrac.Classique.Dice

  def ensure(trictrac) do
    trictrac = trictrac || %{}

    trictrac
    |> Map.put(:score, normalize_score(trictrac[:score]))
    |> Map.put_new(:options, %{"margotEnabled" => false})
    |> Map.put(:opening, normalize_opening(trictrac[:opening]))
    |> Map.put(:turn, normalize_turn(trictrac[:turn]))
    |> Map.put_new(:turn_event_queue, [])
    |> Map.put(:score_history, normalize_events(trictrac[:score_history] || []))
    |> Map.put_new(:sortie, %{last_event: nil})
    |> Map.put_new(:pending_impuissance_by_type, %{white: 0, black: 0})
    |> Map.put_new(:coin_rest_start_count_by_type, %{white: 0, black: 0})
    |> Map.put_new(:pile_misere_pending_by_type, %{white: false, black: false})
  end

  def apply_options(trictrac, options) do
    options = options || %{}
    margot = Map.get(options, "margotEnabled") || Map.get(options, :margotEnabled) || false
    put_in(ensure(trictrac), [:options, "margotEnabled"], margot)
  end

  def set_turn_event_queue(trictrac, events), do: %{ensure(trictrac) | turn_event_queue: events}

  def shift_turn_event_queue(trictrac) do
    trictrac = ensure(trictrac)
    %{trictrac | turn_event_queue: tl_or_empty(trictrac.turn_event_queue)}
  end

  def current_pending_event(trictrac), do: ensure(trictrac).turn_event_queue |> List.first()
  def clear_scores(trictrac), do: %{ensure(trictrac) | score: [score_entry(), score_entry()]}

  def reset_opening_for_releve(trictrac) do
    trictrac = ensure(trictrac)
    releve_count = get_in(trictrac, [:opening, :releve_count]) || 0
    %{trictrac | opening: %OpeningState{opening_state() | releve_count: releve_count + 1}}
  end

  def sortie_awarded?(trictrac) do
    trictrac
    |> ensure()
    |> get_in([:turn, :events])
    |> Kernel.||([])
    |> Enum.any?(&(event_label(&1) == "sortie"))
  end

  def mark_sortie_releve(trictrac, color, turn_number) do
    put_in(ensure(trictrac), [:sortie, :last_event], %{
      piece_type: Atom.to_string(color),
      points: 0,
      turn_number: turn_number,
      releve: true
    })
  end

  def trous_for(trictrac, :white),
    do: get_in(ensure(trictrac), [:score, Access.at(0), :trous]) || 0

  def trous_for(trictrac, :black),
    do: get_in(ensure(trictrac), [:score, Access.at(1), :trous]) || 0

  def points_for(trictrac, :white),
    do: get_in(ensure(trictrac), [:score, Access.at(0), :points]) || 0

  def points_for(trictrac, :black),
    do: get_in(ensure(trictrac), [:score, Access.at(1), :points]) || 0

  def own_coin(:white), do: 12
  def own_coin(:black), do: 11
  def opp_coin(:white), do: 11
  def opp_coin(:black), do: 12
  def own_coin(variant, color), do: denorm_pos(variant, Constants.coin_norm_pos(), color)
  def opp_coin(variant, color), do: denorm_pos(variant, Constants.coin_norm_pos() - 1, color)

  def score_index(:white), do: 0
  def score_index(:black), do: 1
  def opposite(:white), do: :black
  def opposite(:black), do: :white

  def norm_pos(position, :white), do: position
  def norm_pos(position, :black), do: 23 - position
  def denorm_pos(position, :white), do: position
  def denorm_pos(position, :black), do: 23 - position

  def norm_pos(variant, position, color) do
    case movement_direction(variant, color) do
      :toward_24 -> position
      :toward_1 -> 23 - position
    end
  end

  def denorm_pos(variant, position, color) do
    case movement_direction(variant, color) do
      :toward_24 -> position
      :toward_1 -> 23 - position
    end
  end

  def movement_direction(%{orientation: :ascending}, :white), do: :toward_1
  def movement_direction(%{orientation: :ascending}, :black), do: :toward_24
  def movement_direction(%{orientation: :parallel_toward_1}, _color), do: :toward_1
  def movement_direction(%{orientation: :parallel_toward_24}, _color), do: :toward_24
  def movement_direction(_variant, :white), do: :toward_24
  def movement_direction(_variant, :black), do: :toward_1

  def dice_values(dice), do: Dice.values(dice)
  def normalized_throw(dice), do: Dice.normalized_throw(dice)
  def dice_pair(dice), do: Dice.faces(dice)
  def double?(dice), do: Dice.double?(dice)

  def outside_count(nil, _color), do: 0

  def outside_count(board, color) do
    outside = Map.get(board, :outside, %{}) || %{}
    Map.get(outside, color, Map.get(outside, Atom.to_string(color), 0))
  end

  def impuissance_base(%{values: values}) when is_list(values) and length(values) > 2, do: 4
  def impuissance_base(_dice), do: 2

  def tl_or_empty([_ | rest]), do: rest
  def tl_or_empty([]), do: []

  def remove_first([value | rest], value), do: rest
  def remove_first([head | rest], value), do: [head | remove_first(rest, value)]
  def remove_first([], _value), do: []

  def remove_all_used(values, used),
    do: Enum.reduce(used, values, fn die, acc -> remove_first(acc, die) end)

  def score_entry, do: %ScoreEntry{}
  def opening_state, do: %OpeningState{}
  def turn_state, do: %TurnState{}

  def normalize_score_entry(%ScoreEntry{} = entry), do: entry

  def normalize_score_entry(entry) do
    %ScoreEntry{
      points: fetch(entry, :points, 0),
      trous: fetch(entry, :trous, 0),
      bredouille: fetch(entry, :bredouille, false),
      doubling_active: fetch(entry, :doubling_active, fetch(entry, :doublingActive, true)),
      grande_bredouille: fetch(entry, :grande_bredouille, fetch(entry, :grandeBredouille, false)),
      etendard: fetch(entry, :etendard, false)
    }
  end

  def normalize_opening(%OpeningState{} = opening) do
    default = opening_state()

    %OpeningState{
      first_type: opening.first_type,
      first_values: opening.first_values,
      jan_rencontre_checked: opening.jan_rencontre_checked,
      coups_by_type: normalize_color_map(opening.coups_by_type, 0),
      releve_count: opening.releve_count || default.releve_count,
      depart_done_by_type:
        normalize_depart_done_by_type(opening.depart_done_by_type, default.depart_done_by_type)
    }
  end

  def normalize_opening(opening) do
    default = opening_state()

    %OpeningState{
      first_type: fetch(opening, :first_type, default.first_type),
      first_values: fetch(opening, :first_values, default.first_values),
      jan_rencontre_checked:
        fetch(opening, :jan_rencontre_checked, default.jan_rencontre_checked),
      coups_by_type:
        normalize_color_map(fetch(opening, :coups_by_type, default.coups_by_type), 0),
      releve_count: fetch(opening, :releve_count, default.releve_count),
      depart_done_by_type:
        normalize_depart_done_by_type(
          fetch(opening, :depart_done_by_type, default.depart_done_by_type),
          default.depart_done_by_type
        )
    }
  end

  def normalize_turn(%TurnState{} = turn) do
    %TurnState{
      piece_type: turn.piece_type,
      events: normalize_events(turn.events),
      score_by_type: normalize_color_map(turn.score_by_type, 0),
      obligations: normalize_obligation(turn.obligations),
      conservation_candidates: normalize_conservation_candidates(turn.conservation_candidates),
      pile_misere_candidate: turn.pile_misere_candidate,
      pile_misere_pending: turn.pile_misere_pending,
      trous_before: normalize_color_map(turn.trous_before, 0),
      trous_after: normalize_color_map(turn.trous_after, 0),
      can_reprise: turn.can_reprise,
      reprise_color: turn.reprise_color,
      start_board: turn.start_board,
      dice: turn.dice
    }
  end

  def normalize_turn(turn) do
    default = turn_state()

    %TurnState{
      piece_type: fetch(turn, :piece_type, default.piece_type),
      events: normalize_events(fetch(turn, :events, default.events)),
      score_by_type: normalize_color_map(fetch(turn, :score_by_type, default.score_by_type), 0),
      obligations: normalize_obligation(fetch(turn, :obligations, default.obligations)),
      conservation_candidates:
        normalize_conservation_candidates(
          fetch(turn, :conservation_candidates, default.conservation_candidates)
        ),
      pile_misere_candidate: fetch(turn, :pile_misere_candidate, default.pile_misere_candidate),
      pile_misere_pending: fetch(turn, :pile_misere_pending, default.pile_misere_pending),
      trous_before: normalize_color_map(fetch(turn, :trous_before, default.trous_before), 0),
      trous_after: normalize_color_map(fetch(turn, :trous_after, default.trous_after), 0),
      can_reprise: fetch(turn, :can_reprise, default.can_reprise),
      reprise_color: fetch(turn, :reprise_color, default.reprise_color),
      start_board: fetch(turn, :start_board, default.start_board),
      dice: fetch(turn, :dice, default.dice)
    }
  end

  def normalize_events(events) when is_list(events), do: Enum.map(events, &normalize_event/1)
  def normalize_events(_events), do: []

  def normalize_event(%ScoreEvent{} = event), do: normalize_event(Map.from_struct(event))

  def normalize_event(event) do
    label = fetch(event, :label, nil)
    source = normalize_source(fetch(event, :source, nil))
    rule = normalize_rule(fetch(event, :rule, nil), label, source)

    %ScoreEvent{
      rule: rule,
      label: normalize_label(label, rule),
      piece_type: fetch(event, :piece_type, nil),
      beneficiary: fetch(event, :beneficiary, nil),
      points: fetch(event, :points, 0),
      trous_delta: fetch(event, :trous_delta, 0),
      turn_number: fetch(event, :turn_number, nil),
      source: source || Constants.score_source(rule),
      metadata: fetch(event, :metadata, %{})
    }
  end

  def normalize_obligation(%Obligation{} = obligation), do: obligation

  def normalize_obligation(obligation) do
    %Obligation{
      piece_type: fetch(obligation, :piece_type, nil),
      must_fill: normalize_table_keys(fetch(obligation, :must_fill, [])),
      must_conserve:
        normalize_conservation_candidates(fetch(obligation, :must_conserve, []),
          requirement?: true
        )
    }
  end

  def normalize_conservation_candidate(%ConservationCandidate{} = candidate), do: candidate

  def normalize_conservation_candidate(candidate) do
    %ConservationCandidate{
      key: normalize_table_key(fetch(candidate, :key, nil)),
      points: fetch(candidate, :points, 0),
      allow_sortie: fetch(candidate, :allow_sortie, fetch(candidate, :allowSortie, false)),
      outside_before: fetch(candidate, :outside_before, fetch(candidate, :outsideBefore, 0))
    }
  end

  def normalize_source(nil), do: nil
  def normalize_source(source) when is_atom(source), do: source

  def normalize_source(source) when is_binary(source) do
    Constants.score_source(source) ||
      Enum.find_value(Constants.score_sources(), source, fn {_label, value} ->
        value_as_string =
          value
          |> Atom.to_string()
          |> String.trim_leading("Elixir.")

        if value_as_string == source, do: value, else: nil
      end) ||
      source
  end

  def normalize_rule(rule, label \\ nil, source \\ nil)

  def normalize_rule(rule, _label, _source) when is_atom(rule) do
    Constants.score_rule(rule) || rule
  end

  def normalize_rule(rule, label, source) when is_binary(rule) do
    Constants.score_rule(rule) || Constants.score_rule(label) || Constants.score_rule(source)
  end

  def normalize_rule(_rule, label, source) do
    Constants.score_rule(label) || Constants.score_rule(source)
  end

  def normalize_label(label, rule) do
    Constants.score_label(rule) || label
  end

  def normalize_table_key(nil), do: nil
  def normalize_table_key(key) when is_atom(key), do: key
  def normalize_table_key("petit"), do: :petit
  def normalize_table_key("grand"), do: :grand
  def normalize_table_key("retour"), do: :retour
  def normalize_table_key(key), do: key

  def normalize_table_keys(keys) when is_list(keys), do: Enum.map(keys, &normalize_table_key/1)
  def normalize_table_keys(_keys), do: []

  def event_label(%ScoreEvent{label: label, rule: rule}), do: normalize_label(label, rule)

  def event_label(event),
    do: normalize_label(fetch(event, :label, nil), fetch(event, :rule, nil))

  def event_rule(%ScoreEvent{rule: rule, label: label, source: source}),
    do: normalize_rule(rule, label, source)

  def event_rule(event),
    do:
      normalize_rule(
        fetch(event, :rule, nil),
        fetch(event, :label, nil),
        fetch(event, :source, nil)
      )

  def normalize_for_snapshot(trictrac), do: ensure(trictrac)

  defp normalize_score(entries) do
    entries
    |> List.wrap()
    |> Enum.map(&normalize_score_entry/1)
    |> case do
      [white, black] -> [white, black]
      [white] -> [white, score_entry()]
      _ -> [score_entry(), score_entry()]
    end
  end

  defp normalize_conservation_candidates(candidates, opts \\ [])
  defp normalize_conservation_candidates(candidates, _opts) when not is_list(candidates), do: []

  defp normalize_conservation_candidates(candidates, opts) do
    requirement? = Keyword.get(opts, :requirement?, false)

    Enum.map(candidates, fn candidate ->
      candidate = normalize_conservation_candidate(candidate)

      if requirement? do
        %ConservationCandidate{
          candidate
          | points: 0
        }
      else
        candidate
      end
    end)
  end

  defp normalize_color_map(nil, default), do: %{white: default, black: default}

  defp normalize_color_map(map, default) do
    %{
      white: fetch(map, :white, default),
      black: fetch(map, :black, default)
    }
  end

  defp normalize_depart_done_by_type(map, default) do
    %{
      white: normalize_depart_done(fetch(map, :white, default.white), default.white),
      black: normalize_depart_done(fetch(map, :black, default.black), default.black)
    }
  end

  defp normalize_depart_done(map, default) do
    %{
      two_tables: fetch(map, :two_tables, default.two_tables),
      meseas: fetch(map, :meseas, default.meseas),
      six_tables: fetch(map, :six_tables, default.six_tables)
    }
  end

  defp fetch(nil, _key, default), do: default
  defp fetch(%_{} = struct, key, default), do: Map.get(struct, key, default)

  defp fetch(map, key, default) when is_map(map),
    do: Map.get(map, key, Map.get(map, stringify_key(key), default))

  defp fetch(_value, _key, default), do: default

  defp stringify_key(key) when is_atom(key), do: Atom.to_string(key)
  defp stringify_key(key), do: key
end
