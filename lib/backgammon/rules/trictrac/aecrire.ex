defmodule Backgammon.Rules.Trictrac.AEcrire.CurrentCoup do
  use Backgammon.Rules.Trictrac.AccessStruct,
    fields: [
      trous: %{white: 0, black: 0},
      legal_exit_by: %{white: false, black: false},
      obligation_reached_by: %{white: false, black: false},
      sans_lever_by: %{white: false, black: false}
    ]
end

defmodule Backgammon.Rules.Trictrac.AEcrire.Track do
  alias Backgammon.Rules.Trictrac.AEcrire.CurrentCoup

  use Backgammon.Rules.Trictrac.AccessStruct,
    fields: [
      partie_length: 24,
      style: "avec_releve",
      coup_count: 0,
      marques: %{white: 0, black: 0},
      marque_streak: %{white: 0, black: 0},
      petite_bredouille: %{white: false, black: false},
      grande_bredouille: %{white: false, black: false},
      partie_over: false,
      winner: nil,
      last_marques_by_type: %{white: 0, black: 0},
      last_marque_result: nil,
      current_coup: %CurrentCoup{}
    ]
end

defmodule Backgammon.Rules.Trictrac.AEcrire do
  alias Backgammon.Rules.Trictrac.AEcrire.{CurrentCoup, Track}

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
    style =
      case Map.get(options, "aEcrireStyle") || Map.get(options, :aEcrireStyle) do
        @style_sans_lever -> @style_sans_lever
        _ -> @style_avec_releve
      end

    update_in(ensure(trictrac), [:track_aecrire], fn track ->
      %{track | style: style}
    end)
    |> sync_settlement()
  end

  def mark_coup(trictrac) do
    update_in(ensure(trictrac), [:track_aecrire, :coup_count], &(&1 + 1))
  end

  def record_turn(trictrac, color, deltas, opts \\ []) do
    trictrac = ensure(trictrac)
    active? = Keyword.get(opts, :active?, true)
    opp = opposite(color)

    trictrac =
      if active? do
        Enum.reduce([:white, :black], trictrac, fn piece_type, acc ->
          delta = Map.get(deltas, piece_type, 0)

          update_in(acc, [:track_aecrire, :current_coup, :trous, piece_type], fn trous ->
            max(0, (trous || 0) + delta)
          end)
        end)
      else
        trictrac
      end

    current_coup = trictrac.track_aecrire.current_coup
    own_delta = Map.get(deltas, color, 0)

    trictrac
    |> put_in([:track_aecrire, :current_coup, :obligation_reached_by, :white], current_coup.trous.white >= 6)
    |> put_in([:track_aecrire, :current_coup, :obligation_reached_by, :black], current_coup.trous.black >= 6)
    |> put_in([:track_aecrire, :current_coup, :legal_exit_by, color], own_delta > 0)
    |> put_in([:track_aecrire, :current_coup, :legal_exit_by, opp], false)
  end

  def reprise_due?(trictrac, color) do
    get_in(ensure(trictrac), [:track_aecrire, :current_coup, :legal_exit_by, color]) || false
  end

  def settlement_ready?(trictrac, color) do
    reprise_due?(trictrac, color) and current_coup_trous(trictrac, color) >= 6
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
  end

  def clear_current_coup(trictrac) do
    put_in(ensure(trictrac), [:track_aecrire, :current_coup], blank_current_coup())
  end

  def current_coup_trous(trictrac, color) do
    get_in(ensure(trictrac), [:track_aecrire, :current_coup, :trous, color]) || 0
  end

  def resolve_reprise(trictrac) do
    trictrac = ensure(trictrac)
    white_trous = current_coup_trous(trictrac, :white)
    black_trous = current_coup_trous(trictrac, :black)
    max_trous = max(white_trous, black_trous)

    result =
      cond do
        max_trous < 6 ->
          %{ended_marque: false, refait: false, winner: nil, marque_value: 0}

        white_trous == black_trous ->
          %{ended_marque: true, refait: true, winner: nil, marque_value: 0}

        true ->
          winner = if white_trous > black_trous, do: :white, else: :black
          loser = opposite(winner)
          winner_trous = current_coup_trous(trictrac, winner)
          loser_trous = current_coup_trous(trictrac, loser)

          marque_value =
            cond do
              loser_trous == 0 and winner_trous >= 12 -> 4
              loser_trous == 0 and winner_trous >= 6 -> 2
              true -> 1
            end

          %{ended_marque: true, refait: false, winner: winner, marque_value: marque_value}
      end

    trictrac =
      case result do
        %{winner: nil, refait: true} ->
          put_in(trictrac, [:track_aecrire, :last_marques_by_type], %{white: 0, black: 0})
          |> put_in([:track_aecrire, :last_marque_result], %{
            winner: nil,
            marque_value: 0,
            refait: true
          })

        %{winner: winner, marque_value: marque_value} when winner in [:white, :black] ->
          loser = opposite(winner)

          trictrac
          |> update_in([:track_aecrire, :marques, winner], &(&1 + marque_value))
          |> update_in([:track_aecrire, :marque_streak, winner], &(&1 + marque_value))
          |> put_in([:track_aecrire, :marque_streak, loser], 0)
          |> put_in([:track_aecrire, :last_marques_by_type], %{
            white: if(winner == :white, do: marque_value, else: 0),
            black: if(winner == :black, do: marque_value, else: 0)
          })
          |> put_in([:track_aecrire, :last_marque_result], %{
            winner: Atom.to_string(winner),
            marque_value: marque_value,
            refait: false
          })
          |> update_bredouille_flags()
          |> pick_winner()

        _ ->
          trictrac
      end

    {sync_settlement(trictrac), result}
  end

  def sync_settlement(trictrac) do
    trictrac = ensure(trictrac)

    ledger =
      Enum.reduce([:white, :black], %{}, fn color, acc ->
        track = trictrac.track_aecrire
        opp = opposite(color)
        marques = track.marques[color]
        excess_marques = max(0, marques - track.partie_length)
        paris = excess_marques * 4
        queue_jetons = marques
        queue_paris = if excess_marques > 0, do: 20, else: 0
        bredouille_multiplier = bredouille_multiplier(trictrac, color)
        marque_jetons = marques * bredouille_multiplier
        consolation = if track.partie_over and track.winner != color, do: 2, else: 0

        jetons =
          20 + marque_jetons + paris + queue_jetons + queue_paris + consolation +
            if(track.partie_over and track.winner == color and track.marques[opp] == 0, do: 10, else: 0)

        Map.put(acc, color, %{
          trous: current_coup_trous(trictrac, color),
          points: points_for(trictrac, color),
          coup_count: track.coup_count,
          marques: marques,
          paris: paris,
          queue_jetons: queue_jetons,
          queue_paris: queue_paris,
          jetons: jetons,
          fiches: div(jetons, 10),
          consolation: consolation
        })
      end)

    %{trictrac | settlement_ledger: ledger}
  end

  def clear_classique_scores(trictrac) do
    %{trictrac | score: [score_entry(), score_entry()]}
  end

  defp update_bredouille_flags(trictrac) do
    track = trictrac.track_aecrire
    petite_threshold = ceil(track.partie_length / 2)

    track =
      track
      |> put_in([:petite_bredouille, :white], track.marque_streak.white >= petite_threshold and track.marques.black == 0)
      |> put_in([:petite_bredouille, :black], track.marque_streak.black >= petite_threshold and track.marques.white == 0)
      |> put_in([:grande_bredouille, :white], track.marques.white >= track.partie_length and track.marques.black == 0)
      |> put_in([:grande_bredouille, :black], track.marques.black >= track.partie_length and track.marques.white == 0)

    %{trictrac | track_aecrire: track}
  end

  defp pick_winner(trictrac) do
    track = trictrac.track_aecrire

    cond do
      track.partie_over ->
        trictrac

      track.marques.white >= track.partie_length and track.marques.black < track.partie_length ->
        put_in(trictrac, [:track_aecrire, :partie_over], true)
        |> put_in([:track_aecrire, :winner], :white)

      track.marques.black >= track.partie_length and track.marques.white < track.partie_length ->
        put_in(trictrac, [:track_aecrire, :partie_over], true)
        |> put_in([:track_aecrire, :winner], :black)

      track.marques.white >= track.partie_length and track.marques.black >= track.partie_length ->
        winner =
          cond do
            track.marques.white > track.marques.black -> :white
            track.marques.black > track.marques.white -> :black
            current_coup_trous(trictrac, :white) >= current_coup_trous(trictrac, :black) -> :white
            true -> :black
          end

        trictrac
        |> put_in([:track_aecrire, :partie_over], true)
        |> put_in([:track_aecrire, :winner], winner)

      true ->
        trictrac
    end
  end

  defp bredouille_multiplier(trictrac, color) do
    track = trictrac.track_aecrire

    cond do
      track.grande_bredouille[color] -> if(track.style == @style_avec_releve, do: 4, else: 8)
      track.petite_bredouille[color] -> if(track.style == @style_avec_releve, do: 2, else: 4)
      true -> 1
    end
  end

  defp score_entry do
    %{points: 0, trous: 0, bredouille: false, doubling_active: true, grande_bredouille: false, etendard: false}
  end

  defp ledger_entry do
    %{
      trous: 0,
      points: 0,
      coup_count: 0,
      marques: 0,
      paris: 0,
      queue_jetons: 0,
      queue_paris: 0,
      jetons: 20,
      fiches: 2,
      consolation: 0
    }
  end

  defp default_track(current_coup) do
    %Track{current_coup: current_coup}
  end

  defp points_for(trictrac, :white), do: get_in(trictrac, [:score, Access.at(0), :points]) || 0
  defp points_for(trictrac, :black), do: get_in(trictrac, [:score, Access.at(1), :points]) || 0

  defp current_coup_from_score(trictrac) do
    %CurrentCoup{
      trous: %{
        white: get_in(trictrac, [:score, Access.at(0), :trous]) || 0,
        black: get_in(trictrac, [:score, Access.at(1), :trous]) || 0
      },
      legal_exit_by: %{white: false, black: false},
      obligation_reached_by: %{white: false, black: false},
      sans_lever_by: %{white: false, black: false}
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
      style: track.style,
      coup_count: track.coup_count,
      marques: normalize_color_map(track.marques, 0),
      marque_streak: normalize_color_map(track.marque_streak, 0),
      petite_bredouille: normalize_color_map(track.petite_bredouille, false),
      grande_bredouille: normalize_color_map(track.grande_bredouille, false),
      partie_over: track.partie_over,
      winner: track.winner,
      last_marques_by_type: normalize_color_map(track.last_marques_by_type, 0),
      last_marque_result: track.last_marque_result,
      current_coup: normalize_current_coup(track.current_coup || current_coup)
    }
  end

  defp normalize_track(track, current_coup, default_track) do
    %Track{
      partie_length: Map.get(track || %{}, :partie_length, default_track.partie_length),
      style: Map.get(track || %{}, :style, default_track.style),
      coup_count: Map.get(track || %{}, :coup_count, default_track.coup_count),
      marques: normalize_color_map(Map.get(track || %{}, :marques), 0),
      marque_streak: normalize_color_map(Map.get(track || %{}, :marque_streak), 0),
      petite_bredouille: normalize_color_map(Map.get(track || %{}, :petite_bredouille), false),
      grande_bredouille: normalize_color_map(Map.get(track || %{}, :grande_bredouille), false),
      partie_over: Map.get(track || %{}, :partie_over, false),
      winner: Map.get(track || %{}, :winner, nil),
      last_marques_by_type: normalize_color_map(Map.get(track || %{}, :last_marques_by_type), 0),
      last_marque_result: Map.get(track || %{}, :last_marque_result, nil),
      current_coup:
        normalize_current_coup(
          Map.get(track || %{}, :current_coup, Map.get(track || %{}, "current_coup", current_coup))
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

  defp opposite(:white), do: :black
  defp opposite(:black), do: :white
end
