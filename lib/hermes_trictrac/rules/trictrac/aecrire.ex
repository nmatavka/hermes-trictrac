defmodule HermesTrictrac.Rules.Trictrac.AEcrire.CurrentCoup do
  use HermesTrictrac.Rules.Trictrac.AccessStruct,
    fields: [
      trous: %{white: 0, black: 0},
      legal_exit_by: %{white: false, black: false},
      obligation_reached_by: %{white: false, black: false},
      sans_lever_by: %{white: false, black: false},
      first_scorer: nil,
      last_scorer: nil,
      run_trous: %{white: 0, black: 0},
      ever_lifted_by: %{white: false, black: false},
      run_started_at_opp_trous: %{white: 0, black: 0},
      interrupted_run_by: %{white: nil, black: nil}
    ]
end

defmodule HermesTrictrac.Rules.Trictrac.AEcrire.Track do
  alias HermesTrictrac.Rules.Trictrac.AEcrire.CurrentCoup

  use HermesTrictrac.Rules.Trictrac.AccessStruct,
    fields: [
      partie_length: 16,
      coup_count: 0,
      coups_played: 0,
      marques: %{white: 0, black: 0},
      points_total: %{white: 0, black: 0},
      marque_streak: %{white: 0, black: 0},
      petite_bredouille: %{white: false, black: false},
      grande_bredouille: %{white: false, black: false},
      refait_streak: 0,
      partie_over: false,
      winner: nil,
      gross_gain: 0,
      rounded_gain: 0,
      last_marques_by_type: %{white: 0, black: 0},
      last_points_by_type: %{white: 0, black: 0},
      last_marque_result: nil,
      coup_starter: nil,
      current_coup: %CurrentCoup{}
    ]
end

defmodule HermesTrictrac.Rules.Trictrac.AEcrire do
  alias HermesTrictrac.Rules.Trictrac.AEcrire.{CurrentCoup, Track}

  @style_avec_releve "avec_releve"
  @style_sans_lever "sans_lever"

  def ensure(trictrac) do
    current_coup = current_coup_from_score(trictrac)
    default_track = default_track(current_coup)

    trictrac
    |> Map.put_new(:track_aecrire, default_track)
    |> update_in([:track_aecrire], fn track ->
      track = normalize_track(track, current_coup, default_track)

      normalized =
        track
        |> Map.put_new(:current_coup, current_coup)
        |> then(fn updated ->
          normalize_current_coup(updated.current_coup || current_coup)
        end)
        |> maybe_seed_coup_trous_from_score(current_coup, trictrac)

      put_in(track, [:current_coup], normalized)
    end)
    |> Map.put_new(:settlement_ledger, %{
      white: ledger_entry(),
      black: ledger_entry()
    })
  end

  def apply_options(trictrac, options) do
    trictrac = ensure(trictrac)

    partie_length = normalize_partie_length(options, trictrac.track_aecrire.partie_length)

    update_in(trictrac, [:track_aecrire], fn track ->
      %{track | partie_length: partie_length}
    end)
    |> sync_settlement()
  end

  def mark_coup(trictrac) do
    update_in(ensure(trictrac), [:track_aecrire, :coup_count], &(&1 + 1))
  end

  def seed_coup_starter(trictrac, color) do
    trictrac = ensure(trictrac)

    if trictrac.track_aecrire.coup_starter in [:white, :black] do
      trictrac
    else
      put_in(trictrac, [:track_aecrire, :coup_starter], color)
    end
  end

  def record_turn(trictrac, color, deltas, opts \\ []) do
    trictrac = ensure(trictrac)
    active? = Keyword.get(opts, :active?, true)
    events = Keyword.get(opts, :events, [])
    opp = opposite(color)
    own_delta = Map.get(deltas, color, 0)

    trictrac =
      cond do
        not active? ->
          trictrac

        events != [] ->
          Enum.reduce(events, trictrac, fn event, acc ->
            beneficiary = beneficiary_color(event)
            trous_delta = event[:trous_delta] || event.trous_delta || 0

            if beneficiary in [:white, :black] and trous_delta > 0 do
              apply_scored_trous(acc, beneficiary, trous_delta)
            else
              acc
            end
          end)

        true ->
          Enum.reduce([:white, :black], trictrac, fn piece_type, acc ->
            delta = Map.get(deltas, piece_type, 0)

            if delta > 0 do
              apply_scored_trous(acc, piece_type, delta)
            else
              acc
            end
          end)
      end

    current_coup = trictrac.track_aecrire.current_coup

    trictrac
    |> put_in(
      [:track_aecrire, :current_coup, :obligation_reached_by, :white],
      current_coup.trous.white >= 6
    )
    |> put_in(
      [:track_aecrire, :current_coup, :obligation_reached_by, :black],
      current_coup.trous.black >= 6
    )
    |> put_in([:track_aecrire, :current_coup, :legal_exit_by, color], own_delta > 0)
    |> put_in([:track_aecrire, :current_coup, :legal_exit_by, opp], false)
  end

  def reprise_due?(trictrac, color) do
    get_in(ensure(trictrac), [:track_aecrire, :current_coup, :legal_exit_by, color]) || false
  end

  def settlement_ready?(trictrac, color) do
    reprise_due?(trictrac, color) and current_coup_trous(trictrac, color) >= 6
  end

  def obligation_reached?(trictrac) do
    trictrac = ensure(trictrac)
    current_coup_trous(trictrac, :white) >= 6 or current_coup_trous(trictrac, :black) >= 6
  end

  def exit_resolution(trictrac, color) do
    trictrac = ensure(trictrac)
    opp = opposite(color)

    cond do
      obligation_reached?(trictrac) and
          current_coup_trous(trictrac, color) < current_coup_trous(trictrac, opp) ->
        {resolved, result} = resolve_coup(trictrac, opp, voluntary_loser: color)
        {:ended, resolved, result, next_coup_starter(trictrac, result, color)}

      settlement_ready?(trictrac, color) ->
        {resolved, result} = resolve_reprise(trictrac)
        {:ended, resolved, result, next_coup_starter(trictrac, result, color)}

      true ->
        {:releve, releve_current_coup(trictrac, color)}
    end
  end

  def hold_current_coup(trictrac, color) do
    trictrac = ensure(trictrac)

    trictrac
    |> put_in([:track_aecrire, :current_coup, :legal_exit_by, color], false)
    |> put_in(
      [:track_aecrire, :current_coup, :sans_lever_by, color],
      current_coup_trous(trictrac, color) >= 6
    )
  end

  def releve_current_coup(trictrac, color) do
    trictrac
    |> ensure()
    |> put_in([:track_aecrire, :current_coup, :legal_exit_by, color], false)
    |> put_in([:track_aecrire, :current_coup, :sans_lever_by, color], false)
    |> put_in([:track_aecrire, :current_coup, :ever_lifted_by, color], true)
  end

  def clear_current_coup(trictrac) do
    put_in(ensure(trictrac), [:track_aecrire, :current_coup], blank_current_coup())
  end

  def current_coup_trous(trictrac, color) do
    get_in(ensure(trictrac), [:track_aecrire, :current_coup, :trous, color]) || 0
  end

  def resolve_reprise(trictrac) do
    resolve_coup(ensure(trictrac))
  end

  def sync_settlement(trictrac) do
    trictrac = ensure(trictrac)
    track = trictrac.track_aecrire
    wins = track.marques
    totals = track.points_total
    total_coups = track.coups_played
    queue_jetons = queue_des_jetons(totals, wins)
    marque_points = %{white: wins.white * 4, black: wins.black * 4}
    queue_marques = queue_des_marques(wins)

    final_totals = %{
      white: totals.white + queue_jetons.white + marque_points.white + queue_marques.white,
      black: totals.black + queue_jetons.black + marque_points.black + queue_marques.black
    }

    gross_gain = abs(final_totals.white - final_totals.black)
    rounded_gain = rounded_gain(gross_gain)

    ledger =
      Enum.reduce([:white, :black], %{}, fn color, acc ->
        opp = opposite(color)
        coups_won = wins[color]
        coups_lost = max(total_coups - coups_won, 0)
        paris = max(coups_won - wins[opp], 0) * 4
        jetons = final_totals[color]

        Map.put(acc, color, %{
          trous: current_coup_trous(trictrac, color),
          points: totals[color],
          coup_count: track.coup_count,
          coups_played: total_coups,
          coups_won: coups_won,
          coups_lost: coups_lost,
          marques: coups_won,
          paris: paris,
          marque_points: marque_points[color],
          queue_jetons: queue_jetons[color],
          queue_paris: queue_marques[color],
          final_total: final_totals[color],
          jetons: jetons,
          fiches: div(jetons, 10),
          gross_gain: if(winning_color(final_totals) == color, do: gross_gain, else: 0),
          rounded_gain: if(winning_color(final_totals) == color, do: rounded_gain, else: 0)
        })
      end)

    %{trictrac | settlement_ledger: ledger}
    |> update_in([:track_aecrire], fn track ->
      %{
        track
        | gross_gain: gross_gain,
          rounded_gain: rounded_gain
      }
    end)
  end

  def clear_classique_scores(trictrac) do
    %{trictrac | score: [score_entry(), score_entry()]}
  end

  defp update_bredouille_flags(trictrac, winner, nil) do
    trictrac
    |> put_in([:track_aecrire, :petite_bredouille], %{white: false, black: false})
    |> put_in([:track_aecrire, :grande_bredouille], %{white: false, black: false})
    |> put_in([:track_aecrire, :marque_streak, winner], 0)
  end

  defp update_bredouille_flags(trictrac, winner, :petite) do
    loser = opposite(winner)

    trictrac
    |> put_in([:track_aecrire, :petite_bredouille], %{
      white: winner == :white,
      black: winner == :black
    })
    |> put_in([:track_aecrire, :grande_bredouille], %{white: false, black: false})
    |> update_in([:track_aecrire, :marque_streak, winner], &((&1 || 0) + 1))
    |> put_in([:track_aecrire, :marque_streak, loser], 0)
  end

  defp update_bredouille_flags(trictrac, winner, :grande) do
    loser = opposite(winner)

    trictrac
    |> put_in([:track_aecrire, :petite_bredouille], %{white: false, black: false})
    |> put_in([:track_aecrire, :grande_bredouille], %{
      white: winner == :white,
      black: winner == :black
    })
    |> update_in([:track_aecrire, :marque_streak, winner], &((&1 || 0) + 1))
    |> put_in([:track_aecrire, :marque_streak, loser], 0)
  end

  defp pick_winner(trictrac) do
    track = trictrac.track_aecrire
    complete? = track.coups_played >= track.partie_length

    if complete? do
      winner =
        trictrac.settlement_ledger
        |> total_pair()
        |> winning_color()

      trictrac
      |> put_in([:track_aecrire, :partie_over], true)
      |> put_in([:track_aecrire, :winner], winner)
    else
      trictrac
    end
  end

  defp score_entry do
    %{
      points: 0,
      trous: 0,
      bredouille: false,
      doubling_active: true,
      grande_bredouille: false,
      etendard: false
    }
  end

  defp ledger_entry do
    %{
      trous: 0,
      points: 0,
      coup_count: 0,
      coups_played: 0,
      coups_won: 0,
      coups_lost: 0,
      marques: 0,
      paris: 0,
      marque_points: 0,
      queue_jetons: 0,
      queue_paris: 0,
      final_total: 0,
      jetons: 0,
      fiches: 0,
      gross_gain: 0,
      rounded_gain: 0
    }
  end

  defp default_track(current_coup) do
    %Track{current_coup: current_coup}
  end

  defp current_coup_from_score(trictrac) do
    %CurrentCoup{
      trous: %{
        white: get_in(trictrac, [:score, Access.at(0), :trous]) || 0,
        black: get_in(trictrac, [:score, Access.at(1), :trous]) || 0
      },
      legal_exit_by: %{white: false, black: false},
      obligation_reached_by: %{white: false, black: false},
      sans_lever_by: %{white: false, black: false},
      first_scorer: nil,
      last_scorer: nil,
      run_trous: %{white: 0, black: 0},
      ever_lifted_by: %{white: false, black: false},
      run_started_at_opp_trous: %{white: 0, black: 0},
      interrupted_run_by: %{white: nil, black: nil}
    }
  end

  defp blank_current_coup, do: %CurrentCoup{}

  defp normalize_current_coup(%CurrentCoup{} = current_coup), do: current_coup

  defp normalize_current_coup(current_coup) do
    blank = blank_current_coup()

    %CurrentCoup{
      trous: %{
        white: get_in(current_coup, [:trous, :white]) || blank.trous.white,
        black: get_in(current_coup, [:trous, :black]) || blank.trous.black
      },
      legal_exit_by: %{
        white: get_in(current_coup, [:legal_exit_by, :white]) || false,
        black: get_in(current_coup, [:legal_exit_by, :black]) || false
      },
      obligation_reached_by: %{
        white: get_in(current_coup, [:obligation_reached_by, :white]) || false,
        black: get_in(current_coup, [:obligation_reached_by, :black]) || false
      },
      sans_lever_by: %{
        white: get_in(current_coup, [:sans_lever_by, :white]) || false,
        black: get_in(current_coup, [:sans_lever_by, :black]) || false
      },
      first_scorer: current_coup[:first_scorer] || current_coup["first_scorer"],
      last_scorer: current_coup[:last_scorer] || current_coup["last_scorer"],
      run_trous: %{
        white: get_in(current_coup, [:run_trous, :white]) || 0,
        black: get_in(current_coup, [:run_trous, :black]) || 0
      },
      ever_lifted_by: %{
        white: get_in(current_coup, [:ever_lifted_by, :white]) || false,
        black: get_in(current_coup, [:ever_lifted_by, :black]) || false
      },
      run_started_at_opp_trous: %{
        white: get_in(current_coup, [:run_started_at_opp_trous, :white]) || 0,
        black: get_in(current_coup, [:run_started_at_opp_trous, :black]) || 0
      },
      interrupted_run_by: %{
        white: interrupted_run_entry(get_in(current_coup, [:interrupted_run_by, :white])),
        black: interrupted_run_entry(get_in(current_coup, [:interrupted_run_by, :black]))
      }
    }
  end

  defp maybe_seed_coup_trous_from_score(current_coup, score_coup, trictrac) do
    if blank_coup_trous?(current_coup) and not blank_coup_trous?(score_coup) and
         safe_to_seed_from_score?(trictrac) do
      %{current_coup | trous: score_coup.trous}
    else
      current_coup
    end
  end

  defp blank_coup_trous?(%{trous: %{white: 0, black: 0}}), do: true
  defp blank_coup_trous?(_value), do: false

  defp safe_to_seed_from_score?(trictrac) do
    turn = Map.get(trictrac, :turn) || %{}
    is_nil(turn[:start_board]) and is_nil(turn[:dice]) and Enum.empty?(turn[:events] || [])
  end

  defp normalize_track(%Track{} = track, current_coup, _default_track) do
    %Track{
      partie_length: track.partie_length,
      coup_count: track.coup_count,
      coups_played: track.coups_played,
      marques: normalize_color_map(track.marques, 0),
      points_total: normalize_color_map(track.points_total, 0),
      marque_streak: normalize_color_map(track.marque_streak, 0),
      petite_bredouille: normalize_color_map(track.petite_bredouille, false),
      grande_bredouille: normalize_color_map(track.grande_bredouille, false),
      refait_streak: track.refait_streak,
      partie_over: track.partie_over,
      winner: track.winner,
      gross_gain: track.gross_gain,
      rounded_gain: track.rounded_gain,
      last_marques_by_type: normalize_color_map(track.last_marques_by_type, 0),
      last_points_by_type: normalize_color_map(track.last_points_by_type, 0),
      last_marque_result: track.last_marque_result,
      coup_starter: track.coup_starter,
      current_coup: normalize_current_coup(track.current_coup || current_coup)
    }
  end

  defp normalize_track(track, current_coup, default_track) do
    %Track{
      partie_length: Map.get(track || %{}, :partie_length, default_track.partie_length),
      coup_count: Map.get(track || %{}, :coup_count, default_track.coup_count),
      coups_played: Map.get(track || %{}, :coups_played, default_track.coups_played),
      marques: normalize_color_map(Map.get(track || %{}, :marques), 0),
      points_total: normalize_color_map(Map.get(track || %{}, :points_total), 0),
      marque_streak: normalize_color_map(Map.get(track || %{}, :marque_streak), 0),
      petite_bredouille: normalize_color_map(Map.get(track || %{}, :petite_bredouille), false),
      grande_bredouille: normalize_color_map(Map.get(track || %{}, :grande_bredouille), false),
      refait_streak: Map.get(track || %{}, :refait_streak, 0),
      partie_over: Map.get(track || %{}, :partie_over, false),
      winner: Map.get(track || %{}, :winner, nil),
      gross_gain: Map.get(track || %{}, :gross_gain, 0),
      rounded_gain: Map.get(track || %{}, :rounded_gain, 0),
      last_marques_by_type: normalize_color_map(Map.get(track || %{}, :last_marques_by_type), 0),
      last_points_by_type: normalize_color_map(Map.get(track || %{}, :last_points_by_type), 0),
      last_marque_result: Map.get(track || %{}, :last_marque_result, nil),
      coup_starter: Map.get(track || %{}, :coup_starter, nil),
      current_coup:
        normalize_current_coup(
          Map.get(
            track || %{},
            :current_coup,
            Map.get(track || %{}, "current_coup", current_coup)
          )
        )
    }
  end

  defp normalize_color_map(nil, default), do: %{white: default, black: default}

  defp normalize_color_map(map, default) do
    %{
      white: Map.get(map || %{}, :white, Map.get(map || %{}, "white", default)),
      black: Map.get(map || %{}, :black, Map.get(map || %{}, "black", default))
    }
  end

  defp normalize_partie_length(options, default) do
    case Map.get(options, "aEcrirePartieLength") || Map.get(options, :aEcrirePartieLength) do
      value when value in [6, "6"] -> 6
      value when value in [8, "8"] -> 8
      value when value in [12, "12"] -> 12
      value when value in [16, "16"] -> 16
      value when value in [18, "18"] -> 18
      value when value in [20, "20"] -> 20
      value when value in [24, "24"] -> 24
      _ -> default
    end
  end

  defp beneficiary_color(%{beneficiary: beneficiary}), do: beneficiary_color(beneficiary)
  defp beneficiary_color(%{"beneficiary" => beneficiary}), do: beneficiary_color(beneficiary)
  defp beneficiary_color("white"), do: :white
  defp beneficiary_color("black"), do: :black
  defp beneficiary_color(:white), do: :white
  defp beneficiary_color(:black), do: :black
  defp beneficiary_color(_value), do: nil

  defp apply_scored_trous(trictrac, beneficiary, trous_delta) do
    trictrac = ensure(trictrac)
    opp = opposite(beneficiary)
    current_coup = trictrac.track_aecrire.current_coup
    previous_opp_run = current_coup.run_trous[opp] || 0

    interrupted_run =
      if previous_opp_run > 0 do
        %{
          trous: previous_opp_run,
          ever_lifted: current_coup.ever_lifted_by[opp] || false,
          started_at_opp_trous: current_coup.run_started_at_opp_trous[opp] || 0
        }
      end

    run_continues? =
      current_coup.last_scorer == beneficiary and (current_coup.run_trous[beneficiary] || 0) > 0

    run_start_opp_trous =
      if(run_continues?,
        do: current_coup.run_started_at_opp_trous[beneficiary] || 0,
        else: current_coup.trous[opp] || 0
      )

    trictrac
    |> update_in([:track_aecrire, :current_coup, :trous, beneficiary], &((&1 || 0) + trous_delta))
    |> put_in(
      [:track_aecrire, :current_coup, :first_scorer],
      current_coup.first_scorer || beneficiary
    )
    |> put_in([:track_aecrire, :current_coup, :last_scorer], beneficiary)
    |> put_in(
      [:track_aecrire, :current_coup, :run_trous, beneficiary],
      if(run_continues?,
        do: (current_coup.run_trous[beneficiary] || 0) + trous_delta,
        else: trous_delta
      )
    )
    |> put_in([:track_aecrire, :current_coup, :run_trous, opp], 0)
    |> put_in(
      [:track_aecrire, :current_coup, :run_started_at_opp_trous, beneficiary],
      run_start_opp_trous
    )
    |> maybe_put_interrupted_run(opp, interrupted_run)
  end

  defp maybe_put_interrupted_run(trictrac, _color, nil), do: trictrac

  defp maybe_put_interrupted_run(trictrac, color, interrupted_run) do
    put_in(trictrac, [:track_aecrire, :current_coup, :interrupted_run_by, color], interrupted_run)
  end

  defp resolve_coup(trictrac, forced_winner \\ nil, opts \\ []) do
    trictrac = ensure(trictrac)
    white_trous = current_coup_trous(trictrac, :white)
    black_trous = current_coup_trous(trictrac, :black)
    voluntary_loser = Keyword.get(opts, :voluntary_loser)

    cond do
      is_nil(forced_winner) and max(white_trous, black_trous) < 6 ->
        {trictrac,
         %{ended_marque: false, refait: false, winner: nil, marque_value: 0, points_awarded: 0}}

      is_nil(forced_winner) and white_trous == black_trous ->
        track =
          trictrac.track_aecrire
          |> Map.put(:refait_streak, (trictrac.track_aecrire.refait_streak || 0) + 1)
          |> Map.put(:petite_bredouille, %{white: false, black: false})
          |> Map.put(:grande_bredouille, %{white: false, black: false})
          |> Map.put(:last_marques_by_type, %{white: 0, black: 0})
          |> Map.put(:last_points_by_type, %{white: 0, black: 0})
          |> Map.put(:last_marque_result, %{
            winner: nil,
            marque_value: 0,
            points_awarded: 0,
            consolation: 2 * ((trictrac.track_aecrire.refait_streak || 0) + 2),
            refait: true
          })

        {%{trictrac | track_aecrire: track} |> sync_settlement(),
         %{ended_marque: true, refait: true, winner: nil, marque_value: 0, points_awarded: 0}}

      true ->
        winner = forced_winner || if(white_trous > black_trous, do: :white, else: :black)
        loser = opposite(winner)
        winner_trous = current_coup_trous(trictrac, winner)
        loser_trous = current_coup_trous(trictrac, loser)
        consolation = 2 * ((trictrac.track_aecrire.refait_streak || 0) + 1)
        bredouille = bredouille_for_result(trictrac, winner, loser, voluntary_loser)
        multiplier = if bredouille, do: bredouille.multiplier, else: 1

        points_awarded =
          if voluntary_loser || is_nil(bredouille) do
            winner_trous + consolation - loser_trous
          else
            (winner_trous + consolation) * multiplier - loser_trous
          end

        track =
          trictrac.track_aecrire
          |> put_in(
            [:points_total, winner],
            (trictrac.track_aecrire.points_total[winner] || 0) + points_awarded
          )
          |> update_in([:marques, winner], &((&1 || 0) + 1))
          |> update_in([:marque_streak, winner], &((&1 || 0) + 1))
          |> put_in([:marque_streak, loser], 0)
          |> Map.put(:coups_played, trictrac.track_aecrire.coups_played + 1)
          |> Map.put(:refait_streak, 0)
          |> Map.put(:last_marques_by_type, %{
            white: if(winner == :white, do: 1, else: 0),
            black: if(winner == :black, do: 1, else: 0)
          })
          |> Map.put(:last_points_by_type, %{
            white: if(winner == :white, do: points_awarded, else: 0),
            black: if(winner == :black, do: points_awarded, else: 0)
          })
          |> Map.put(:last_marque_result, %{
            winner: Atom.to_string(winner),
            marque_value: 1,
            points_awarded: points_awarded,
            consolation: consolation,
            winner_trous: winner_trous,
            loser_trous: loser_trous,
            voluntary_loss: not is_nil(voluntary_loser),
            bredouille: bredouille && bredouille.kind,
            multiplier: multiplier,
            refait: false
          })

        trictrac =
          %{trictrac | track_aecrire: track}
          |> update_bredouille_flags(winner, bredouille && bredouille.kind)
          |> sync_settlement()
          |> pick_winner()

        {trictrac,
         %{
           ended_marque: true,
           refait: false,
           winner: winner,
           marque_value: 1,
           points_awarded: points_awarded
         }}
    end
  end

  defp bredouille_for_result(_trictrac, _winner, _loser, voluntary_loser)
       when not is_nil(voluntary_loser),
       do: nil

  defp bredouille_for_result(trictrac, winner, loser, _voluntary_loser) do
    current_coup = trictrac.track_aecrire.current_coup
    winner_run = current_coup.run_trous[winner] || 0

    kind =
      cond do
        winner_run >= 12 -> :grande
        winner_run >= 6 -> :petite
        true -> nil
      end

    if is_nil(kind) do
      nil
    else
      interrupted_loser = current_coup.interrupted_run_by[loser]

      with_releve? =
        if (current_coup.run_started_at_opp_trous[winner] || 0) > 0 and
             qualifying_run?(interrupted_loser) do
          interrupted_loser.ever_lifted
        else
          current_coup.ever_lifted_by[winner] || false
        end

      %{
        kind: kind,
        style: if(with_releve?, do: @style_avec_releve, else: @style_sans_lever),
        multiplier:
          case {kind, with_releve?} do
            {:petite, true} -> 2
            {:petite, false} -> 3
            {:grande, true} -> 4
            {:grande, false} -> 5
          end
      }
    end
  end

  defp qualifying_run?(%{trous: trous}) when trous >= 6, do: true
  defp qualifying_run?(_value), do: false

  defp next_coup_starter(trictrac, %{refait: true}, fallback) do
    trictrac.track_aecrire.coup_starter || fallback
  end

  defp next_coup_starter(_trictrac, %{winner: winner}, _fallback), do: winner

  defp queue_des_jetons(totals, wins) do
    cond do
      totals.white > totals.black ->
        %{white: wins.white * 2, black: 0}

      totals.black > totals.white ->
        %{white: 0, black: wins.black * 2}

      wins.white > wins.black ->
        %{white: wins.white - wins.black, black: 0}

      wins.black > wins.white ->
        %{white: 0, black: wins.black - wins.white}

      true ->
        %{white: 0, black: 0}
    end
  end

  defp queue_des_marques(wins) do
    cond do
      wins.white > wins.black -> %{white: 20, black: 0}
      wins.black > wins.white -> %{white: 0, black: 20}
      true -> %{white: 0, black: 0}
    end
  end

  defp total_pair(ledger) do
    %{
      white: get_in(ledger, [:white, :final_total]) || 0,
      black: get_in(ledger, [:black, :final_total]) || 0
    }
  end

  defp winning_color(%{white: white, black: black}) when white > black, do: :white
  defp winning_color(%{white: white, black: black}) when black > white, do: :black
  defp winning_color(_totals), do: nil

  defp rounded_gain(0), do: 0
  defp rounded_gain(value), do: div(value + 5, 10) * 10

  defp interrupted_run_entry(nil), do: nil

  defp interrupted_run_entry(entry) do
    %{
      trous: entry[:trous] || entry["trous"] || 0,
      ever_lifted: entry[:ever_lifted] || entry["ever_lifted"] || false,
      started_at_opp_trous: entry[:started_at_opp_trous] || entry["started_at_opp_trous"] || 0
    }
  end

  defp opposite(:white), do: :black
  defp opposite(:black), do: :white
end
