defmodule HermesTrictrac.Rules.TrictracCore do
  alias HermesTrictrac.Rules.RaceCore
  alias HermesTrictrac.Rules.Trictrac.{AEcrire, Classique, Combine, Plein, Toc, VariantRules}

  @reprise_variants ["trictrac_classique", "trictrac_aecrire", "trictrac_combine", "toccategli"]
  @aecrire_variants ["trictrac_aecrire", "trictrac_combine"]
  @combine_variant "trictrac_combine"
  @toc_variant "toc"

  def new(variant) do
    variant
    |> RaceCore.new()
    |> ensure_state(variant)
  end

  def pending_options(%{id: "trictrac_aecrire"}),
    do: aecrire_match_options("RuleFrTrictracAEcrire")

  def pending_options(%{id: "trictrac_combine"}),
    do: aecrire_match_options("RuleFrTrictracCombine")

  def pending_options(%{id: "toc"}), do: RaceCore.pending_options(%{id: "toc"})
  def pending_options(_variant), do: nil

  def submit_options(runtime, variant, options) do
    runtime =
      runtime
      |> ensure_state(variant)
      |> RaceCore.submit_options(variant, options)
      |> update_trictrac(fn trictrac ->
        trictrac
        |> Classique.apply_options(options)
        |> maybe_apply_aecrire_options(variant, options)
      end)

    runtime
  end

  def roll(runtime, variant, color) do
    runtime = ensure_state(runtime, variant)

    with {:ok, runtime} <- RaceCore.roll(runtime, variant, color) do
      trictrac =
        runtime.trictrac
        |> Classique.begin_turn(runtime.board, variant, color, runtime.dice)
        |> maybe_seed_aecrire_coup_starter(variant, color)

      {:ok, %{runtime | trictrac: trictrac}}
    end
  end

  def move(runtime, variant, color, move) do
    runtime = ensure_state(runtime, variant)

    with {:ok, runtime} <- RaceCore.move(runtime, variant, color, move) do
      {:ok, refresh_pending_impuissance(runtime, variant, color)}
    end
  end

  def undo(runtime, variant, color) do
    runtime = ensure_state(runtime, variant)

    with {:ok, runtime} <- RaceCore.undo(runtime, variant, color) do
      {:ok, runtime}
    end
  end

  def confirm(runtime, variant, color) do
    runtime = ensure_state(runtime, variant)
    previous = runtime

    cond do
      is_nil(runtime.dice) ->
        {:error, "No rolled dice to confirm."}

      remaining_checker_moves?(runtime, variant, color) ->
        {:error, "Turn obligations not fulfilled."}

      true ->
        with runtime <- ensure_turn_seed(runtime, previous, variant, color),
             runtime <- refresh_pending_impuissance(runtime, variant, color),
             {:ok, _analysis} <- validate_turn_before_confirm(runtime, variant, color) do
          runtime =
            runtime
            |> ensure_state(variant)
            |> after_confirm(previous, variant, color)
            |> maybe_settle_variant(previous, variant, color)
            |> maybe_apply_sortie_releve(variant, color)
            |> remember_completed_turn_moves()
            |> maybe_advance_turn_after_queue(variant)

          {:ok, runtime}
        end
    end
  end

  defp after_confirm(runtime, previous, variant, color) do
    runtime =
      runtime
      |> finalize_classique_turn(previous, variant, color)
      |> sync_pending_impuissance(color)
      |> maybe_queue_turn_events(previous, variant, color)

    runtime
  end

  defp maybe_settle_variant(runtime, previous, %{id: "trictrac_combine"}, color) do
    runtime
    |> update_trictrac(
      &Combine.maybe_resume(
        &1,
        previous.board.outside[color] || 0,
        runtime.board.outside[color] || 0,
        previous.board != runtime.board
      )
    )
    |> maybe_finish_combine_match()
  end

  defp maybe_settle_variant(runtime, previous, %{id: "toc"}, color) do
    _previous = previous

    case Toc.result(runtime.trictrac, color, get_in(runtime, [:variant_state, :options]) || %{}) do
      nil ->
        runtime

      %{beneficiary: beneficiary, holes: hole_delta, own_die: own_die?} ->
        target =
          String.to_integer(get_in(runtime, [:variant_state, :options, "holeTarget"]) || "1")

        score = Map.update!(runtime.match.score, beneficiary, &(&1 + hole_delta))
        over? = score[beneficiary] >= target

        runtime =
          runtime
          |> put_in([:match, :score], score)
          |> put_in([:match, :winner], if(over?, do: Atom.to_string(beneficiary), else: nil))
          |> put_in([:match, :winner_kind], if(over?, do: "toc_holes", else: nil))
          |> put_in([:match, :is_over], over?)

        if own_die? and not over? and not turn_decision_answered?(runtime, beneficiary, "reprise") do
          pending = %{
            "key" => "reprise",
            "prompt" => Toc.reprise_prompt(),
            "choices" => ["tenir", "s'en aller"]
          }

          runtime
          |> update_trictrac(&Classique.set_turn_event_queue(&1, [pending]))
          |> Map.put(:pending_turn_decision, pending)
        else
          runtime
          |> update_trictrac(&Classique.set_turn_event_queue(&1, []))
          |> Map.put(:pending_turn_decision, nil)
        end
    end
  end

  defp maybe_settle_variant(runtime, _previous, %{id: "plein"}, color) do
    Plein.settle_match(runtime, color)
  end

  defp maybe_settle_variant(runtime, previous, variant, color) do
    runtime
    |> maybe_finish_classique_match(previous, variant, color)
    |> maybe_finish_aecrire_match(variant)
  end

  defp maybe_finish_classique_match(
         %{match: %{is_over: true}} = runtime,
         _previous,
         _variant,
         _color
       ),
       do: runtime

  defp maybe_finish_classique_match(runtime, previous, %{id: id} = variant, _color)
       when id in ["trictrac_classique", "toccategli"] do
    if plucked_poule?(runtime.match) do
      runtime
    else
      case first_classique_match_winner(
             previous.trictrac,
             runtime.trictrac,
             variant,
             runtime.match
           ) do
        nil ->
          runtime

        %{winner: winner, kind: kind} ->
          score = Map.update!(runtime.match.score, winner, &(&1 + classique_match_award(kind)))

          %{
            runtime
            | match: %{
                runtime.match
                | is_over: true,
                  winner: Atom.to_string(winner),
                  winner_kind: kind,
                  score: score
              }
          }
      end
    end
  end

  defp maybe_finish_classique_match(runtime, _previous, _variant, _color), do: runtime

  defp maybe_finish_combine_match(runtime) do
    cond do
      runtime.match.is_over ->
        runtime

      winner = get_in(runtime, [:trictrac, :track_aecrire, :winner]) ->
        %{
          runtime
          | match: %{
              runtime.match
              | is_over: true,
                winner: Atom.to_string(winner),
                winner_kind: "jetons"
            }
        }

      true ->
        runtime
    end
  end

  defp maybe_apply_sortie_releve(%{match: %{is_over: true}} = runtime, _variant, _color),
    do: clear_keep_turn(runtime)

  defp maybe_apply_sortie_releve(runtime, %{id: id} = variant, color)
       when id in ["trictrac_classique", "trictrac_aecrire", "trictrac_combine", "toccategli"] do
    if Classique.sortie_awarded?(runtime.trictrac) do
      fresh = ensure_state(RaceCore.new(variant), variant)

      runtime
      |> Map.put(:board, fresh.board)
      |> put_in([:variant_state, :keep_turn], true)
      |> update_trictrac(fn trictrac ->
        trictrac
        |> Classique.reset_opening_for_releve()
        |> Classique.mark_sortie_releve(color, runtime.turn_number)
      end)
    else
      clear_keep_turn(runtime)
    end
  end

  defp maybe_apply_sortie_releve(runtime, _variant, _color), do: clear_keep_turn(runtime)

  defp maybe_advance_turn_after_queue(runtime, variant) do
    keep_turn = get_in(runtime, [:variant_state, :keep_turn]) || false

    cond do
      runtime.match.is_over ->
        runtime
        |> Map.put(:pending_turn_decision, nil)
        |> update_trictrac(&Classique.set_turn_event_queue(&1, []))
        |> Map.put(:dice, nil)
        |> Map.put(:legal_moves, [])
        |> Map.put(:history, [])
        |> clear_keep_turn()

      variant.id == "toc" and is_nil(current_pending(runtime)) and is_nil(runtime.dice) ->
        clear_keep_turn(runtime)

      is_nil(current_pending(runtime)) ->
        runtime
        |> Map.put(:dice, nil)
        |> Map.put(:legal_moves, [])
        |> Map.put(:history, [])
        |> Map.put(
          :turn_color,
          if(keep_turn, do: runtime.turn_color, else: opposite(runtime.turn_color))
        )
        |> Map.put(:turn_number, runtime.turn_number + 1)
        |> clear_keep_turn()

      true ->
        runtime
        |> Map.put(:dice, nil)
        |> Map.put(:legal_moves, [])
        |> Map.put(:history, [])
    end
  end

  def submit_turn_decision(runtime, variant, color, decision) do
    runtime = ensure_state(runtime, variant)
    pending = runtime.pending_turn_decision || current_pending(runtime)

    cond do
      is_nil(pending) ->
        {:error, "No pending turn decision."}

      decision not in (pending["choices"] || []) ->
        {:error, "Invalid turn decision."}

      turn_decision_answered?(runtime, color, pending["key"]) ->
        {:error, "Turn decision already resolved."}

      decision == "s'en aller" and pending["key"] == "reprise" and plucked_poule?(runtime.match) and
          not plucked_reprise_allowed?(runtime.trictrac, color) ->
        {:error, "Need at least 6 trous and the lead to take the plucked-pool payout."}

      true ->
        runtime =
          mark_turn_decision_answered(runtime, color, pending["key"])

        {:ok, apply_turn_decision(runtime, variant, color, pending["key"], decision)}
    end
  end

  defp ensure_turn_seed(runtime, previous, variant, color) do
    update_trictrac(runtime, fn trictrac ->
      if is_nil(get_in(trictrac, [:turn, :start_board])) or
           is_nil(get_in(trictrac, [:turn, :dice])) do
        Classique.begin_turn(
          trictrac,
          previous.board,
          variant,
          color,
          previous.dice || runtime.dice ||
            %{values: [], moves: [], moves_left: [], moves_played: []}
        )
      else
        trictrac
      end
    end)
  end

  defp validate_turn_before_confirm(runtime, variant, color) do
    case Classique.validate_turn(runtime.trictrac, runtime.board, variant, color) do
      {:ok, analysis} ->
        {:ok, analysis}

      {:error, :coin_rest} ->
        {:error, "Coin de repos must end the turn with 0 or at least 2 checkers."}

      {:error, _obligations} ->
        {:error, "Turn obligations not fulfilled."}
    end
  end

  defp remaining_checker_moves?(runtime, variant, color) do
    runtime
    |> Classique.legal_moves(variant, color)
    |> Enum.any?()
  end

  defp finalize_classique_turn(runtime, previous, variant, color) do
    runtime = ensure_turn_seed(runtime, previous, variant, color)

    runtime =
      update_trictrac(runtime, fn trictrac ->
        trictrac
        |> Classique.finalize_turn(runtime.board, variant, color, runtime.turn_number)
      end)

    points_gained =
      runtime.trictrac
      |> get_in([:turn, :events])
      |> Kernel.||([])
      |> Enum.filter(&(&1.beneficiary == Atom.to_string(color)))
      |> Enum.reduce(0, fn event, acc -> acc + (event.points || 0) end)

    deltas = score_deltas(previous.trictrac, runtime.trictrac)
    score_events = score_events_since(previous.trictrac, runtime.trictrac)

    runtime =
      update_trictrac(runtime, fn trictrac ->
        trictrac
        |> maybe_record_aecrire_turn(variant, color, deltas, score_events)
        |> maybe_record_honneur(variant, color, deltas, points_gained)
        |> maybe_mark_coup(variant)
      end)

    runtime
    |> maybe_finish_classique_match(previous, variant, color)
    |> maybe_finish_aecrire_match(variant)
  end

  defp sync_pending_impuissance(runtime, color) do
    update_trictrac(runtime, fn trictrac ->
      put_in(trictrac, [:pending_impuissance_by_type, color], 0)
    end)
  end

  defp refresh_pending_impuissance(runtime, variant, color) do
    moves_left = get_in(runtime, [:dice, :moves_left]) || []

    cond do
      is_nil(runtime.dice) ->
        runtime

      moves_left == [] ->
        runtime

      remaining_checker_moves?(runtime, variant, color) ->
        runtime

      true ->
        points = VariantRules.impuissance_points(variant, runtime.dice, length(moves_left))

        update_trictrac(runtime, fn trictrac ->
          pending = get_in(trictrac, [:pending_impuissance_by_type, color]) || 0
          put_in(trictrac, [:pending_impuissance_by_type, color], max(pending, points))
        end)
    end
  end

  defp maybe_queue_turn_events(runtime, previous, variant, color) do
    queue = build_turn_event_queue(previous, runtime, variant, color)
    pending = List.first(queue)

    update_trictrac(runtime, fn trictrac ->
      Classique.set_turn_event_queue(trictrac, queue)
    end)
    |> Map.put(:pending_turn_decision, pending)
  end

  defp build_turn_event_queue(_previous, runtime, %{id: id}, color)
       when id in @reprise_variants do
    reprise_actor = reprise_actor_color(runtime.trictrac, id, color)

    reprise =
      if not is_nil(reprise_actor) and not runtime.match.is_over and
           not turn_decision_answered?(runtime, reprise_actor, "reprise") and
           reprise_allowed?(runtime, reprise_actor) do
        [
          %{
            "key" => "reprise",
            "prompt" => reprise_prompt(id),
            "choices" => ["tenir", "s'en aller"],
            "actorColor" => Atom.to_string(reprise_actor)
          }
        ]
      else
        []
      end

    suspension_choices =
      if id == @combine_variant do
        Combine.suspension_choices(
          runtime.trictrac,
          color,
          AEcrire.reprise_due?(runtime.trictrac, color)
        )
      else
        []
      end

    suspension =
      if id == @combine_variant and suspension_choices != [] do
        [
          %{
            "key" => "suspension",
            "prompt" => "Suspend one track?",
            "choices" => suspension_choices
          }
        ]
      else
        []
      end

    if id == @combine_variant do
      reprise ++ suspension
    else
      reprise
    end
  end

  defp build_turn_event_queue(_previous, _runtime, _variant, _color), do: []

  defp reprise_prompt("trictrac_classique"),
    do: "Choose whether to continue the game or take a reprise."

  defp reprise_prompt("toccategli"),
    do: "Choose whether to continue the game or take a reprise."

  defp reprise_prompt(@toc_variant),
    do: "Choose whether to continue the game or take a reprise."

  defp reprise_prompt("trictrac_aecrire"),
    do: "Choose whether to continue the coup or take a reprise."

  defp reprise_prompt(@combine_variant),
    do: "Choose whether to continue the coup or take a reprise."

  defp apply_turn_decision(runtime, %{id: id} = variant, color, "reprise", "tenir")
       when id in @aecrire_variants do
    runtime
    |> update_trictrac(&AEcrire.hold_current_coup(&1, color))
    |> shift_pending_event()
    |> maybe_advance_turn_after_queue(variant)
  end

  defp apply_turn_decision(runtime, variant, _color, "reprise", "tenir") do
    runtime
    |> shift_pending_event()
    |> maybe_advance_turn_after_queue(variant)
  end

  defp apply_turn_decision(runtime, variant, color, "reprise", "s'en aller")
       when variant.id in @aecrire_variants do
    case AEcrire.exit_resolution(runtime.trictrac, color) do
      {:releve, trictrac} ->
        fresh = RaceCore.new(variant)

        runtime
        |> Map.put(:board, fresh.board)
        |> Map.put(:dice, nil)
        |> Map.put(:legal_moves, [])
        |> Map.put(:history, [])
        |> Map.put(:turn_color, color)
        |> Map.put(:turn_number, runtime.turn_number + 1)
        |> Map.put(:pending_turn_decision, nil)
        |> put_in([:variant_state, :keep_turn], false)
        |> update_trictrac(fn _ ->
          trictrac
          |> put_in(
            [:opening, :releve_count],
            get_in(runtime.trictrac, [:opening, :releve_count]) + 1
          )
          |> put_in([:turn], %{
            events: [],
            score_by_type: %{white: 0, black: 0},
            obligations: %{must_fill: [], must_conserve: []}
          })
          |> Classique.set_turn_event_queue([])
          |> maybe_promote_combine_tracks(variant, color)
          |> maybe_resume_combine_on_releve(variant)
        end)

      {:ended, trictrac, result, next_starter} ->
        fresh = RaceCore.new(variant)

        runtime =
          runtime
          |> Map.put(:board, fresh.board)
          |> Map.put(:dice, nil)
          |> Map.put(:legal_moves, [])
          |> Map.put(:history, [])
          |> Map.put(:turn_color, next_starter)
          |> Map.put(:turn_number, runtime.turn_number + 1)
          |> Map.put(:pending_turn_decision, nil)
          |> put_in([:variant_state, :keep_turn], false)
          |> update_trictrac(fn _ ->
            updated_trictrac =
              cond do
                variant.id == @combine_variant and result.ended_marque ->
                  trictrac
                  |> AEcrire.clear_current_coup()
                  |> put_in([:track_aecrire, :coup_starter], next_starter)

                result.ended_marque ->
                  trictrac
                  |> AEcrire.clear_current_coup()
                  |> AEcrire.clear_classique_scores()
                  |> put_in([:track_aecrire, :coup_starter], next_starter)

                true ->
                  trictrac
              end

            updated_trictrac
            |> put_in(
              [:opening, :releve_count],
              get_in(runtime.trictrac, [:opening, :releve_count]) + 1
            )
            |> put_in([:turn], %{
              events: [],
              score_by_type: %{white: 0, black: 0},
              obligations: %{must_fill: [], must_conserve: []}
            })
            |> Classique.set_turn_event_queue([])
            |> maybe_promote_combine_tracks(variant, color)
            |> maybe_resume_combine_on_releve(variant)
          end)

        maybe_finish_aecrire_match(runtime, variant)
    end
  end

  defp apply_turn_decision(runtime, variant, color, "reprise", "s'en aller")
       when variant.id == @toc_variant do
    Toc.apply_reprise(runtime, variant, color)
  end

  defp apply_turn_decision(runtime, variant, color, "reprise", "s'en aller")
       when variant.id in ["trictrac_classique", "toccategli"] do
    if plucked_poule?(runtime.match) do
      finish_plucked_poule_round(runtime, variant)
    else
      fresh = new(variant)
      current_trictrac = Classique.ensure(runtime.trictrac)
      releve_count = get_in(current_trictrac, [:opening, :releve_count]) || 0

      reset_trictrac =
        fresh.trictrac
        |> Map.put(:score, current_trictrac.score)
        |> Map.put(:score_history, current_trictrac.score_history || [])
        |> Map.put(:options, current_trictrac.options || %{"margotEnabled" => false})
        |> put_in([:opening, :releve_count], releve_count + 1)

      runtime
      |> Map.put(:board, fresh.board)
      |> Map.put(:dice, nil)
      |> Map.put(:legal_moves, [])
      |> Map.put(:history, [])
      |> Map.put(:turn_color, color)
      |> Map.put(:turn_number, runtime.turn_number + 1)
      |> Map.put(:pending_turn_decision, nil)
      |> put_in([:variant_state, :keep_turn], false)
      |> update_trictrac(fn _ -> reset_trictrac end)
    end
  end

  defp apply_turn_decision(runtime, variant, color, "suspension", decision)
       when variant.id == @combine_variant do
    runtime
    |> update_trictrac(fn trictrac ->
      trictrac =
        case decision do
          "suspend_a_ecrire" ->
            if AEcrire.settlement_ready?(trictrac, color) do
              {resolved, _result} = AEcrire.resolve_reprise(trictrac)
              AEcrire.clear_current_coup(resolved)
            else
              AEcrire.releve_current_coup(trictrac, color)
            end

          _ ->
            trictrac
        end

      Combine.apply_suspension(trictrac, color, decision)
    end)
    |> maybe_finish_aecrire_match(variant)
    |> shift_pending_event()
    |> maybe_advance_turn_after_queue(variant)
  end

  defp apply_turn_decision(runtime, _variant, _color, _key, _decision) do
    runtime
    |> shift_pending_event()
    |> maybe_advance_turn_after_queue(%{id: "trictrac_classique"})
  end

  defp shift_pending_event(runtime) do
    runtime =
      update_trictrac(runtime, &Classique.shift_turn_event_queue/1)

    Map.put(runtime, :pending_turn_decision, current_pending(runtime))
  end

  defp maybe_finish_aecrire_match(runtime, %{id: id}) when id in @aecrire_variants do
    partie_over? = get_in(runtime, [:trictrac, :track_aecrire, :partie_over])
    winner = get_in(runtime, [:trictrac, :track_aecrire, :winner])

    if partie_over? do
      %{
        runtime
        | match: %{
            runtime.match
            | is_over: true,
              winner: if(winner, do: Atom.to_string(winner), else: nil),
              winner_kind: if(winner, do: "jetons", else: "draw")
          }
      }
    else
      runtime
    end
  end

  defp maybe_finish_aecrire_match(runtime, _variant), do: runtime

  defp maybe_record_honneur(trictrac, %{id: id}, color, deltas, points_gained)
       when id == @combine_variant do
    active? = get_in(trictrac, [:suspension_state, :suspended_track]) != "classique"
    Combine.record_turn(trictrac, color, deltas, points_gained, active?: active?)
  end

  defp maybe_record_honneur(trictrac, _variant, _color, _trous_delta, _points_gained),
    do: trictrac

  defp maybe_record_aecrire_turn(trictrac, %{id: id}, color, deltas, score_events)
       when id in @aecrire_variants do
    active? =
      id == "trictrac_aecrire" or
        get_in(trictrac, [:suspension_state, :suspended_track]) != "a_ecrire"

    AEcrire.record_turn(trictrac, color, deltas,
      active?: active?,
      events: score_events
    )
  end

  defp maybe_record_aecrire_turn(trictrac, _variant, _color, _deltas, _score_events), do: trictrac

  defp maybe_mark_coup(trictrac, %{id: id}) when id in @aecrire_variants,
    do: AEcrire.mark_coup(trictrac)

  defp maybe_mark_coup(trictrac, _variant), do: trictrac

  defp maybe_apply_aecrire_options(trictrac, %{id: id}, options) when id in @aecrire_variants do
    trictrac
    |> AEcrire.ensure()
    |> AEcrire.apply_options(options)
    |> maybe_promote_combine_tracks(%{id: id}, :white)
  end

  defp maybe_apply_aecrire_options(trictrac, _variant, _options), do: trictrac

  defp maybe_promote_combine_tracks(trictrac, %{id: id}, _color) when id == @combine_variant do
    trictrac
    |> AEcrire.ensure()
    |> Combine.ensure()
  end

  defp maybe_promote_combine_tracks(trictrac, _variant, _color), do: trictrac

  defp maybe_resume_combine_on_releve(trictrac, %{id: id}) when id == @combine_variant,
    do: Combine.resume_on_true_releve(trictrac)

  defp maybe_resume_combine_on_releve(trictrac, _variant), do: trictrac

  defp current_pending(runtime) do
    runtime
    |> Map.get(:trictrac)
    |> case do
      nil -> nil
      trictrac -> Classique.current_pending_event(trictrac)
    end
  end

  defp turn_decision_answered?(runtime, color, key) do
    signature = turn_decision_signature(runtime, color, key)

    runtime
    |> get_in([:variant_state, :answered_turn_decisions])
    |> Kernel.||([])
    |> Enum.member?(signature)
  end

  defp mark_turn_decision_answered(runtime, color, key) do
    signature = turn_decision_signature(runtime, color, key)
    existing = get_in(runtime, [:variant_state, :answered_turn_decisions]) || []

    put_in(
      runtime,
      [:variant_state, :answered_turn_decisions],
      Enum.take(Enum.uniq([signature | existing]), 64)
    )
  end

  defp turn_decision_signature(runtime, color, key) do
    "#{runtime.turn_number}:#{normalize_color(color)}:#{key}"
  end

  defp normalize_color(color) when is_atom(color), do: Atom.to_string(color)
  defp normalize_color(color), do: to_string(color)

  defp ensure_state(runtime, variant) do
    trictrac =
      runtime.trictrac
      |> Kernel.||(%{})
      |> Classique.ensure()
      |> maybe_apply_variant_state(variant)

    %{runtime | trictrac: trictrac}
  end

  defp maybe_apply_variant_state(trictrac, %{id: id}) when id in @aecrire_variants do
    trictrac
    |> AEcrire.ensure()
    |> maybe_add_combine_state(id)
  end

  defp maybe_apply_variant_state(trictrac, _variant), do: trictrac

  defp maybe_add_combine_state(trictrac, @combine_variant), do: Combine.ensure(trictrac)
  defp maybe_add_combine_state(trictrac, _id), do: trictrac

  defp update_trictrac(runtime, fun) do
    %{runtime | trictrac: fun.(runtime.trictrac)}
  end

  defp maybe_seed_aecrire_coup_starter(trictrac, %{id: id}, color)
       when id in @aecrire_variants do
    AEcrire.seed_coup_starter(trictrac, color)
  end

  defp maybe_seed_aecrire_coup_starter(trictrac, _variant, _color), do: trictrac

  defp reprise_actor_color(trictrac, id, color) when id in ["trictrac_classique", "toccategli"] do
    if get_in(trictrac, [:turn, :can_reprise]) do
      get_in(trictrac, [:turn, :reprise_color]) || color
    end
  end

  defp reprise_actor_color(trictrac, @combine_variant, color) do
    if AEcrire.reprise_due?(trictrac, color) or Combine.classique_reprise_due?(trictrac, color),
      do: color
  end

  defp reprise_actor_color(trictrac, id, color) when id in @aecrire_variants do
    if AEcrire.reprise_due?(trictrac, color), do: color
  end

  defp reprise_actor_color(_trictrac, _id, _color), do: nil

  defp score_deltas(previous_trictrac, trictrac) do
    %{
      white: trous_for(trictrac, :white) - trous_for(previous_trictrac, :white),
      black: trous_for(trictrac, :black) - trous_for(previous_trictrac, :black)
    }
  end

  defp score_events_since(previous_trictrac, trictrac) do
    previous_count = length(get_in(previous_trictrac, [:score_history]) || [])
    score_history = get_in(trictrac, [:score_history]) || []
    Enum.drop(score_history, previous_count)
  end

  defp first_classique_match_winner(previous_trictrac, trictrac, variant, match) do
    previous_trous = %{
      white: trous_for(previous_trictrac, :white),
      black: trous_for(previous_trictrac, :black)
    }

    target = classique_target(match)

    previous_trictrac
    |> score_events_since(trictrac)
    |> Enum.reduce_while({:cont, previous_trous}, fn event, {:cont, trous} ->
      beneficiary = score_event_beneficiary(event)
      delta = score_event_trous_delta(event)

      if beneficiary in [:white, :black] and delta > 0 do
        before_trous = Map.get(trous, beneficiary, 0)
        updated_trous = Map.update!(trous, beneficiary, &(&1 + delta))
        after_trous = Map.get(updated_trous, beneficiary, 0)

        if before_trous < target and after_trous >= target do
          {:halt,
           {:winner,
            %{
              winner: beneficiary,
              kind: classique_match_winner_kind(variant, beneficiary, updated_trous)
            }}}
        else
          {:cont, {:cont, updated_trous}}
        end
      else
        {:cont, {:cont, trous}}
      end
    end)
    |> case do
      {:winner, result} -> result
      {:cont, _trous} -> nil
    end
  end

  defp classique_match_winner_kind(variant, winner, trous) do
    if VariantRules.apply_etendard?(variant) and Map.get(trous, opposite(winner), 0) == 0,
      do: "grande_bredouille",
      else: "trous"
  end

  defp classique_match_award("grande_bredouille"), do: 2
  defp classique_match_award(_kind), do: 1

  defp classique_target(match) do
    case get_in(match || %{}, [:options, "classiqueHoleTarget"]) do
      value when is_integer(value) and value >= 1 ->
        value

      value when is_binary(value) ->
        case Integer.parse(value) do
          {parsed, ""} when parsed >= 1 -> parsed
          _ -> 12
        end

      _ ->
        12
    end
  end

  defp plucked_poule?(match) when is_map(match) do
    get_in(match, [:options, "pluckedPouleMode"]) in [true, "true", 1, "1", "yes", "on"]
  end

  defp plucked_poule?(_match), do: false

  defp reprise_allowed?(runtime, reprise_actor) do
    if plucked_poule?(runtime.match) do
      plucked_reprise_allowed?(runtime.trictrac, reprise_actor)
    else
      true
    end
  end

  defp plucked_reprise_allowed?(trictrac, color) when color in [:white, :black] do
    current = trous_for(trictrac, color)
    opponent = trous_for(trictrac, opposite(color))
    current >= 6 and current > opponent
  end

  defp plucked_reprise_allowed?(_trictrac, _color), do: false

  defp finish_plucked_poule_round(runtime, variant) do
    white_trous = trous_for(runtime.trictrac, :white)
    black_trous = trous_for(runtime.trictrac, :black)

    {winner, kind} =
      cond do
        white_trous > black_trous ->
          {:white,
           classique_match_winner_kind(variant, :white, %{white: white_trous, black: black_trous})}

        black_trous > white_trous ->
          {:black,
           classique_match_winner_kind(variant, :black, %{white: white_trous, black: black_trous})}

        true ->
          {nil, "draw"}
      end

    score =
      if winner in [:white, :black] do
        Map.update!(runtime.match.score, winner, &(&1 + classique_match_award(kind)))
      else
        runtime.match.score
      end

    runtime
    |> Map.put(:dice, nil)
    |> Map.put(:legal_moves, [])
    |> Map.put(:history, [])
    |> Map.put(:pending_turn_decision, nil)
    |> update_trictrac(&Classique.set_turn_event_queue(&1, []))
    |> put_in([:variant_state, :keep_turn], false)
    |> Map.put(:match, %{
      runtime.match
      | is_over: true,
        winner: if(winner, do: Atom.to_string(winner), else: nil),
        winner_kind: kind,
        score: score
    })
  end

  defp score_event_beneficiary(event) do
    case Map.get(event, :beneficiary) || Map.get(event, "beneficiary") ||
           Map.get(event, :piece_type) || Map.get(event, "piece_type") do
      :white -> :white
      "white" -> :white
      :black -> :black
      "black" -> :black
      _ -> nil
    end
  end

  defp score_event_trous_delta(event) do
    Map.get(event, :trous_delta, Map.get(event, "trous_delta", 0)) || 0
  end

  defp trous_for(nil, _color), do: 0
  defp trous_for(trictrac, :white), do: Classique.trous_for(trictrac, :white)
  defp trous_for(trictrac, :black), do: Classique.trous_for(trictrac, :black)
  defp clear_keep_turn(runtime), do: put_in(runtime, [:variant_state, :keep_turn], false)

  defp remember_completed_turn_moves(runtime) do
    case Map.get(runtime, :turn_moves) do
      moves when is_list(moves) and moves != [] -> Map.put(runtime, :last_turn_moves, moves)
      _ -> runtime
    end
  end

  defp opposite(:white), do: :black
  defp opposite(:black), do: :white

  defp aecrire_match_options(rule) do
    %{
      "rule" => rule,
      "options" => [
        %{
          "key" => "aEcrirePartieLength",
          "label" => "Marques to play",
          "defaultValue" => "24",
          "choices" => [
            %{"value" => "12", "label" => "12 marques"},
            %{"value" => "24", "label" => "24 marques"}
          ]
        }
      ]
    }
  end
end
