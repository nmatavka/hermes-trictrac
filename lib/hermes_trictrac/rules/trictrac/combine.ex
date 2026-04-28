defmodule HermesTrictrac.Rules.Trictrac.Combine.CurrentPartie do
  use HermesTrictrac.Rules.Trictrac.AccessStruct,
    fields: [
      trous: %{white: 0, black: 0},
      uninterrupted_by: %{white: false, black: false}
    ]
end

defmodule HermesTrictrac.Rules.Trictrac.Combine.Track do
  alias HermesTrictrac.Rules.Trictrac.Combine.CurrentPartie

  use HermesTrictrac.Rules.Trictrac.AccessStruct,
    fields: [
      honneurs: %{white: 0, black: 0},
      classes: %{
        white: %{simple: 0, double: 0, triple: 0, quadruple: 0},
        black: %{simple: 0, double: 0, triple: 0, quadruple: 0}
      },
      current_partie: %CurrentPartie{},
      last_partie_result: nil
    ]
end

defmodule HermesTrictrac.Rules.Trictrac.Combine.SuspensionState do
  use HermesTrictrac.Rules.Trictrac.AccessStruct,
    fields: [
      suspended_track: nil,
      frozen_by: nil,
      resume_pending: false
    ]
end

defmodule HermesTrictrac.Rules.Trictrac.Combine do
  alias HermesTrictrac.Rules.Trictrac.Combine.{CurrentPartie, SuspensionState, Track}

  def ensure(trictrac) do
    current_partie = current_partie_from_score(trictrac)
    default_track = default_track(current_partie)
    default_suspension = %SuspensionState{}

    trictrac
    |> Map.put_new(:track_classique_honneurs, default_track)
    |> update_in([:track_classique_honneurs], fn track ->
      track = normalize_track(track, current_partie, default_track)

      normalized =
        track
        |> Map.put_new(:current_partie, current_partie)
        |> then(fn updated ->
          normalize_current_partie(updated.current_partie || current_partie)
        end)
        |> maybe_seed_partie_trous_from_score(current_partie, trictrac)

      put_in(track, [:current_partie], normalized)
    end)
    |> Map.put_new(:suspension_state, default_suspension)
    |> update_in([:suspension_state], &normalize_suspension_state(&1, default_suspension))
  end

  def record_turn(trictrac, color, deltas, _points_gained, opts \\ []) do
    trictrac = ensure(trictrac)
    active? = Keyword.get(opts, :active?, true)
    opp = opposite(color)
    previous_partie = trictrac.track_classique_honneurs.current_partie

    trictrac =
      if active? do
        Enum.reduce([:white, :black], trictrac, fn piece_type, acc ->
          delta = Map.get(deltas, piece_type, 0)

          update_in(
            acc,
            [:track_classique_honneurs, :current_partie, :trous, piece_type],
            fn trous ->
              max(0, (trous || 0) + delta)
            end
          )
        end)
      else
        trictrac
      end

    own_delta = Map.get(deltas, color, 0)
    opp_delta = Map.get(deltas, opp, 0)

    trictrac =
      cond do
        own_delta > 0 ->
          trictrac
          |> put_in(
            [:track_classique_honneurs, :current_partie, :uninterrupted_by, color],
            eligible_triple_run?(previous_partie, color)
          )
          |> put_in([:track_classique_honneurs, :current_partie, :uninterrupted_by, opp], false)

        opp_delta > 0 ->
          trictrac
          |> put_in(
            [:track_classique_honneurs, :current_partie, :uninterrupted_by, opp],
            eligible_triple_run?(previous_partie, opp)
          )
          |> put_in([:track_classique_honneurs, :current_partie, :uninterrupted_by, color], false)

        true ->
          trictrac
      end

    current_partie = trictrac.track_classique_honneurs.current_partie

    candidate =
      cond do
        active? and own_delta > 0 and current_partie.trous[color] >= 12 -> color
        active? and opp_delta > 0 and current_partie.trous[opp] >= 12 -> opp
        true -> nil
      end

    if candidate do
      trictrac
      |> settle_completed_parties(candidate)
      |> sync_score_with_current_partie()
    else
      trictrac
    end
  end

  def classique_reprise_due?(trictrac, color) do
    trictrac = ensure(trictrac)
    suspended = get_in(trictrac, [:suspension_state, :suspended_track]) == "classique"
    turn = Map.get(trictrac, :turn) || %{}

    not suspended and turn[:can_reprise] and turn[:reprise_color] == color
  end

  def suspension_choices(trictrac, color, a_ecrire_due?) do
    trictrac = ensure(trictrac)

    if trictrac.suspension_state.resume_pending do
      []
    else
      classique_due? = classique_reprise_due?(trictrac, color)

      []
      |> maybe_add_choice(classique_due?, "suspend_classique")
      |> maybe_add_choice(a_ecrire_due?, "suspend_a_ecrire")
      |> case do
        [] -> []
        choices -> choices ++ ["none"]
      end
    end
  end

  def apply_suspension(trictrac, color, decision) do
    trictrac = ensure(trictrac)

    suspension =
      case decision do
        "suspend_classique" ->
          %SuspensionState{suspended_track: "classique", frozen_by: color, resume_pending: true}

        "suspend_a_ecrire" ->
          %SuspensionState{suspended_track: "a_ecrire", frozen_by: color, resume_pending: true}

        _ ->
          %SuspensionState{}
      end

    %{trictrac | suspension_state: suspension}
  end

  def maybe_resume(trictrac, outside_before, outside_after, moved? \\ true) do
    trictrac = ensure(trictrac)

    if moved? and trictrac.suspension_state.resume_pending and outside_after <= outside_before do
      clear_suspension(trictrac)
    else
      trictrac
    end
  end

  def resume_on_true_releve(trictrac) do
    trictrac = ensure(trictrac)

    if trictrac.suspension_state.resume_pending do
      clear_suspension(trictrac)
    else
      trictrac
    end
  end

  defp settle_completed_parties(trictrac, winner) do
    current_partie = trictrac.track_classique_honneurs.current_partie

    if current_partie.trous[winner] >= 12 do
      class = classify_result(current_partie, winner)
      value = honneur_value(class)
      carry = max(current_partie.trous[winner] - 12, 0)

      trictrac
      |> update_in([:track_classique_honneurs, :honneurs, winner], &((&1 || 0) + value))
      |> update_in([:track_classique_honneurs, :classes, winner, class], &((&1 || 0) + 1))
      |> put_in(
        [:track_classique_honneurs, :last_partie_result],
        %{
          winner: Atom.to_string(winner),
          class: Atom.to_string(class),
          value: value,
          carried_trous: carry
        }
      )
      |> put_in(
        [:track_classique_honneurs, :current_partie],
        %CurrentPartie{
          trous: %{
            white: if(winner == :white, do: carry, else: 0),
            black: if(winner == :black, do: carry, else: 0)
          },
          uninterrupted_by: %{white: false, black: false}
        }
      )
      |> settle_completed_parties(winner)
    else
      trictrac
    end
  end

  defp sync_score_with_current_partie(trictrac) do
    current_partie = trictrac.track_classique_honneurs.current_partie

    put_in(trictrac, [:score], [
      normalize_score_entry(Enum.at(trictrac.score || [], 0), current_partie.trous.white),
      normalize_score_entry(Enum.at(trictrac.score || [], 1), current_partie.trous.black)
    ])
  end

  defp normalize_score_entry(entry, trous) do
    (entry || %{points: 0, trous: 0, bredouille: false, doubling_active: true})
    |> Map.put(:points, 0)
    |> Map.put(:trous, trous)
  end

  defp classify_result(current_partie, winner) do
    opp = opposite(winner)

    cond do
      current_partie.trous[opp] == 0 -> :quadruple
      current_partie.uninterrupted_by[winner] -> :triple
      current_partie.trous[opp] <= 6 -> :double
      true -> :simple
    end
  end

  defp honneur_value(:simple), do: 1
  defp honneur_value(:double), do: 2
  defp honneur_value(:triple), do: 3
  defp honneur_value(:quadruple), do: 4

  defp current_partie_from_score(trictrac) do
    %CurrentPartie{
      trous: %{
        white: get_in(trictrac, [:score, Access.at(0), :trous]) || 0,
        black: get_in(trictrac, [:score, Access.at(1), :trous]) || 0
      },
      uninterrupted_by: %{white: false, black: false}
    }
  end

  defp normalize_current_partie(%CurrentPartie{} = current_partie), do: current_partie

  defp normalize_current_partie(current_partie) do
    blank = current_partie_from_score(%{})

    %CurrentPartie{
      trous: %{
        white: get_in(current_partie, [:trous, :white]) || blank.trous.white,
        black: get_in(current_partie, [:trous, :black]) || blank.trous.black
      },
      uninterrupted_by: %{
        white: get_in(current_partie, [:uninterrupted_by, :white]) || false,
        black: get_in(current_partie, [:uninterrupted_by, :black]) || false
      }
    }
  end

  defp default_track(current_partie) do
    %Track{current_partie: current_partie}
  end

  defp maybe_seed_partie_trous_from_score(current_partie, score_partie, trictrac) do
    if blank_partie_trous?(current_partie) and not blank_partie_trous?(score_partie) and
         safe_to_seed_from_score?(trictrac) do
      %{current_partie | trous: score_partie.trous}
    else
      current_partie
    end
  end

  defp blank_partie_trous?(%{trous: %{white: 0, black: 0}}), do: true
  defp blank_partie_trous?(_value), do: false

  defp safe_to_seed_from_score?(trictrac) do
    turn = Map.get(trictrac, :turn) || %{}
    is_nil(turn[:start_board]) and is_nil(turn[:dice]) and Enum.empty?(turn[:events] || [])
  end

  defp eligible_triple_run?(current_partie, color) do
    opp = opposite(color)
    own_trous = get_in(current_partie, [:trous, color]) || 0
    opp_trous = get_in(current_partie, [:trous, opp]) || 0

    ((own_trous == 0 and opp_trous > 0) or get_in(current_partie, [:uninterrupted_by, color])) ||
      false
  end

  defp clear_suspension(trictrac) do
    %{trictrac | suspension_state: %SuspensionState{}}
  end

  defp maybe_add_choice(choices, false, _choice), do: choices
  defp maybe_add_choice(choices, true, choice), do: choices ++ [choice]

  defp normalize_track(%Track{} = track, current_partie, _default_track) do
    %Track{
      honneurs: normalize_color_map(track.honneurs, 0),
      classes: normalize_classes(track.classes),
      current_partie: normalize_current_partie(track.current_partie || current_partie),
      last_partie_result: track.last_partie_result
    }
  end

  defp normalize_track(track, current_partie, _default_track) do
    %Track{
      honneurs: normalize_color_map(Map.get(track || %{}, :honneurs), 0),
      classes: normalize_classes(Map.get(track || %{}, :classes)),
      last_partie_result:
        Map.get(
          track || %{},
          :last_partie_result,
          Map.get(track || %{}, "last_partie_result", nil)
        ),
      current_partie:
        normalize_current_partie(
          Map.get(
            track || %{},
            :current_partie,
            Map.get(track || %{}, "current_partie", current_partie)
          )
        )
    }
  end

  defp normalize_suspension_state(%SuspensionState{} = state, _default_state), do: state

  defp normalize_suspension_state(state, _default_state) do
    %SuspensionState{
      suspended_track:
        Map.get(state || %{}, :suspended_track, Map.get(state || %{}, "suspended_track")),
      frozen_by: Map.get(state || %{}, :frozen_by, Map.get(state || %{}, "frozen_by")),
      resume_pending:
        Map.get(state || %{}, :resume_pending, Map.get(state || %{}, "resume_pending", false))
    }
  end

  defp normalize_classes(nil) do
    %{
      white: %{simple: 0, double: 0, triple: 0, quadruple: 0},
      black: %{simple: 0, double: 0, triple: 0, quadruple: 0}
    }
  end

  defp normalize_classes(classes) do
    %{
      white:
        normalize_class_counts(Map.get(classes || %{}, :white, Map.get(classes || %{}, "white"))),
      black:
        normalize_class_counts(Map.get(classes || %{}, :black, Map.get(classes || %{}, "black")))
    }
  end

  defp normalize_class_counts(nil), do: %{simple: 0, double: 0, triple: 0, quadruple: 0}

  defp normalize_class_counts(counts) do
    %{
      simple: Map.get(counts || %{}, :simple, Map.get(counts || %{}, "simple", 0)),
      double: Map.get(counts || %{}, :double, Map.get(counts || %{}, "double", 0)),
      triple: Map.get(counts || %{}, :triple, Map.get(counts || %{}, "triple", 0)),
      quadruple: Map.get(counts || %{}, :quadruple, Map.get(counts || %{}, "quadruple", 0))
    }
  end

  defp normalize_color_map(nil, default), do: %{white: default, black: default}

  defp normalize_color_map(map, default) do
    %{
      white: Map.get(map || %{}, :white, Map.get(map || %{}, "white", default)),
      black: Map.get(map || %{}, :black, Map.get(map || %{}, "black", default))
    }
  end

  defp opposite(:white), do: :black
  defp opposite(:black), do: :white
end
