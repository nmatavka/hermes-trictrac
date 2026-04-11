defmodule HermesTrictrac.Rules.Engine do
  alias HermesTrictrac.Rules.{Dice, RaceCore, Rabattues, Registry, Snapshot, TourneCase, TrictracCore}
  alias HermesTrictrac.Rules.Trictrac.Classique

  @trictrac_margot_variants [
    "trictrac_classique",
    "trictrac_aecrire",
    "trictrac_combine",
    "toccategli"
  ]

  def new(lobby, variant_id) do
    variant = Registry.get(variant_id)

    runtime =
      case variant.family do
        :race -> RaceCore.new(variant)
        :trictrac -> TrictracCore.new(variant)
        :tourne_case -> TourneCase.new()
        :rabattues -> Rabattues.new()
      end

    %{
      lobby: lobby,
      variant: variant,
      players: %{host: nil, guest: nil},
      status: :waiting_for_opponent,
      turn_color: nil,
      turn_number: 0,
      dice: nil,
      legal_moves: [],
      pending_match_options: nil,
      pending_turn_decision: nil,
      history: [],
      match: %{
        is_over: false,
        score: %{white: 0, black: 0},
        length: 1,
        winner: nil,
        winner_kind: nil,
        results: [],
        options: %{},
        variant_id: variant_id
      },
      board: runtime.board,
      trictrac: Map.get(runtime, :trictrac),
      runtime: runtime
    }
  end

  def snapshot(engine), do: Snapshot.build(engine)

  def join(engine, user, client_id) do
    cond do
      engine.players.host && same_client?(engine.players.host, client_id) ->
        {:ok, engine, player_map(engine.players.host)}

      engine.players.guest && same_client?(engine.players.guest, client_id) ->
        {:ok, engine, player_map(engine.players.guest)}

      is_nil(engine.players.host) ->
        host = player(user, :white, client_id)
        updated = %{engine | players: %{engine.players | host: host}}
        {:ok, updated, player_map(host)}

      is_nil(engine.players.guest) ->
        guest = player(user, :black, client_id)
        updated = %{engine | players: %{engine.players | guest: guest}} |> maybe_start_match()
        {:ok, updated, player_map(guest)}

      true ->
        {:error, "Lobby is full."}
    end
  end

  def roll(engine, user, client_id), do: with_actor(engine, user, client_id, :roll, &do_roll/2)

  def move(engine, move, user, client_id),
    do: with_actor(engine, user, client_id, :turn, &do_move(&1, &2, move))

  def undo(engine, user, client_id), do: with_actor(engine, user, client_id, :turn, &do_undo/2)

  def confirm(engine, user, client_id),
    do: with_actor(engine, user, client_id, :turn, &do_confirm/2)

  def submit_match_options(engine, options, user, client_id),
    do: with_actor(engine, user, client_id, :host_option, &do_submit_options(&1, &2, options))

  def submit_turn_decision(engine, decision, user, client_id),
    do: with_actor(engine, user, client_id, :decision, &do_submit_turn_decision(&1, &2, decision))

  def resign(engine, user, client_id),
    do: with_actor(engine, user, client_id, :resign, &do_resign/2)

  def reset(engine) do
    fresh = new(engine.lobby, engine.variant.id)

    players = engine.players
    maybe_start_match(%{fresh | players: players})
  end

  defp with_actor(engine, user, client_id, requirement, fun) do
    actor = actor(engine, user, client_id)

    cond do
      is_nil(actor) ->
        {:error, "Player not found in lobby."}

      engine.match.is_over and requirement != :host_option ->
        {:error, "Match is already over."}

      requirement == :roll and not roll_allowed?(engine, actor) ->
        {:error, roll_error(engine, actor)}

      requirement == :turn and actor.color != engine.turn_color ->
        {:error, "Not your turn."}

      requirement == :decision and actor.color != decision_actor_color(engine) ->
        {:error, "Not your turn."}

      true ->
        fun.(engine, actor)
    end
  end

  defp do_roll(engine, actor) do
    cond do
      opening_roll_pending?(engine) ->
        {:ok, opening_roll(engine, actor)}

      true ->
        case engine.variant.family do
          :race ->
            with {:ok, runtime} <-
                   RaceCore.roll(runtime_view(engine), engine.variant, actor.color) do
              {:ok, apply_runtime(engine, runtime)}
            end

          :trictrac ->
            with {:ok, runtime} <-
                   TrictracCore.roll(runtime_view(engine), engine.variant, actor.color) do
              {:ok, apply_runtime(engine, runtime)}
            end

          :tourne_case ->
            runtime = TourneCase.roll(runtime_view(engine))

            {:ok,
             apply_runtime(engine, %{
               runtime
               | legal_moves: TourneCase.legal_moves(runtime, actor.color)
             })}

          :rabattues ->
            runtime = Rabattues.roll(runtime_view(engine)) |> Map.put(:roller_color, actor.color)

            {:ok,
             apply_runtime(engine, %{
               runtime
               | legal_moves: Rabattues.legal_moves(runtime, actor.color)
             })}
        end
    end
  end

  defp do_move(engine, actor, move) do
    case engine.variant.family do
      :race ->
        with {:ok, runtime} <-
               RaceCore.move(runtime_view(engine), engine.variant, actor.color, move) do
          {:ok, apply_runtime(engine, runtime)}
        end

      :trictrac ->
        with {:ok, runtime} <-
               TrictracCore.move(runtime_view(engine), engine.variant, actor.color, move) do
          {:ok, apply_runtime(engine, runtime)}
        end

      :tourne_case ->
        with {:ok, runtime} <- TourneCase.move(runtime_view(engine), actor.color, move) do
          runtime = %{runtime | legal_moves: TourneCase.legal_moves(runtime, actor.color)}
          {:ok, apply_runtime(engine, runtime)}
        end

      :rabattues ->
        with {:ok, runtime} <- Rabattues.move(runtime_view(engine), actor.color, move) do
          runtime = %{runtime | legal_moves: Rabattues.legal_moves(runtime, actor.color)}
          {:ok, apply_runtime(engine, runtime)}
        end
    end
  end

  defp do_undo(engine, actor) do
    case engine.variant.family do
      :race ->
        with {:ok, runtime} <- RaceCore.undo(runtime_view(engine), engine.variant, actor.color) do
          {:ok, apply_runtime(engine, runtime)}
        end

      :trictrac ->
        with {:ok, runtime} <-
               TrictracCore.undo(runtime_view(engine), engine.variant, actor.color) do
          {:ok, apply_runtime(engine, runtime)}
        end

      _ ->
        {:error, "Undo is not available for this variant."}
    end
  end

  defp do_confirm(engine, actor) do
    case engine.variant.family do
      :race ->
        with {:ok, runtime} <- RaceCore.confirm(runtime_view(engine), engine.variant, actor.color) do
          {:ok, apply_runtime(engine, runtime)}
        end

      :trictrac ->
        with {:ok, runtime} <-
               TrictracCore.confirm(runtime_view(engine), engine.variant, actor.color) do
          {:ok, apply_runtime(engine, runtime)}
        end

      :tourne_case ->
        winner_kind = TourneCase.winner(runtime_view(engine), actor.color)

        updated =
          if winner_kind do
            engine
            |> Map.put(:match, %{
              engine.match
              | is_over: true,
                winner: Atom.to_string(actor.color),
                winner_kind: winner_kind
            })
            |> Map.put(:status, :match_over)
            |> Map.put(:dice, nil)
            |> Map.put(:legal_moves, [])
          else
            advance_turn(engine)
          end

        {:ok, updated}

      :rabattues ->
        {:ok, rabattues_confirm(engine, actor)}
    end
  end

  defp do_submit_options(engine, actor, options) do
    case engine.pending_match_options do
      %{"kind" => "tavli_target_consent"} = pending ->
        handle_tavli_target_consent(engine, actor, options, pending)

      %{"kind" => "trictrac_margot_consent"} = pending ->
        handle_trictrac_margot_consent(engine, actor, options, pending)

      %{"kind" => "trictrac_partie_length_consent"} = pending ->
        handle_trictrac_partie_length_consent(engine, actor, options, pending)

      _ ->
        if actor != engine.players.host do
          {:error, "Only the host can submit match options."}
        else
          updated =
            case engine.variant.family do
              :race ->
                runtime = RaceCore.submit_options(runtime_view(engine), engine.variant, options)
                apply_runtime(engine, runtime)

              :trictrac ->
                runtime =
                  TrictracCore.submit_options(runtime_view(engine), engine.variant, options)

                apply_runtime(engine, runtime)

              :tourne_case ->
                runtime = TourneCase.submit_options(runtime_view(engine), options)
                apply_runtime(engine, runtime)

              :rabattues ->
                engine
            end

          updated =
            updated
            |> update_in(
              [:match, :options],
              &Map.merge(&1 || %{}, stringify_option_keys(options))
            )
            |> put_in([:match, :length], runtime_length(updated, options))
            |> Map.put(:pending_match_options, nil)
            |> start_after_options()

          {:ok, updated}
        end
    end
  end

  defp do_resign(engine, actor) do
    cond do
      is_nil(engine.players.host) or is_nil(engine.players.guest) ->
        {:error, "Cannot resign before both players have joined."}

      engine.status not in [:playing, :awaiting_match_options] ->
        {:error, "No active match to resign."}

      true ->
        winner = opposite(actor.color)

        runtime =
          runtime_view(engine)
          |> Map.put(:dice, nil)
          |> Map.put(:legal_moves, [])
          |> Map.put(:history, [])
          |> Map.put(:turn_color, nil)
          |> Map.put(:pending_turn_decision, nil)
          |> Map.put(:match, %{
            engine.match
            | is_over: true,
              winner: Atom.to_string(winner),
              winner_kind: "resign"
          })

        updated =
          apply_runtime(engine, runtime)
          |> Map.put(:pending_match_options, nil)
          |> Map.put(:status, :match_over)

        {:ok, updated}
    end
  end

  defp do_submit_turn_decision(engine, actor, decision) do
    case engine.variant.family do
      :race ->
        with {:ok, runtime} <-
               RaceCore.submit_turn_decision(
                 runtime_view(engine),
                 engine.variant,
                 actor.color,
                 decision
               ) do
          {:ok, apply_runtime(engine, runtime)}
        end

      :trictrac ->
        with {:ok, runtime} <-
               TrictracCore.submit_turn_decision(
                 runtime_view(engine),
                 engine.variant,
                 actor.color,
                 decision
               ) do
          {:ok, apply_runtime(engine, runtime)}
        end

      _ ->
        {:error, "No pending turn decision."}
    end
  end

  defp maybe_start_match(engine) do
    if engine.players.guest do
      pending = pending_match_options(engine)

      if pending do
        %{engine | status: :awaiting_match_options, pending_match_options: pending}
      else
        start_play_state(engine)
      end
    else
      engine
    end
  end

  def runtime_view(engine) do
    engine.runtime
    |> Map.put(:dice, engine.dice)
    |> Map.put(:legal_moves, engine.legal_moves)
    |> Map.put(:history, engine.history)
    |> Map.put(:pending_turn_decision, engine.pending_turn_decision)
    |> Map.put(:match, Map.put(engine.match, :variant_id, engine.variant.id))
    |> Map.put(:turn_color, engine.turn_color)
    |> Map.put(:turn_number, engine.turn_number)
  end

  defp apply_runtime(engine, runtime) do
    status = if runtime.match.is_over, do: :match_over, else: engine.status

    %{
      engine
      | runtime: runtime,
        board: runtime.board,
        trictrac: Map.get(runtime, :trictrac),
        dice: runtime.dice,
        legal_moves: Map.get(runtime, :legal_moves, []),
        history: Map.get(runtime, :history, []),
        match: runtime.match,
        turn_color: Map.get(runtime, :turn_color, engine.turn_color),
        turn_number: Map.get(runtime, :turn_number, engine.turn_number),
        pending_turn_decision: Map.get(runtime, :pending_turn_decision),
        status: status
    }
  end

  defp advance_turn(engine) do
    %{
      engine
      | dice: nil,
        legal_moves: [],
        history: [],
        turn_color: opposite(engine.turn_color),
        turn_number: engine.turn_number + 1
    }
  end

  defp start_after_options(engine) do
    start_play_state(engine)
  end

  defp start_play_state(engine) do
    if opening_roll_supported?(engine.variant) do
      start_with_opening_roll(engine)
    else
      %{engine | status: :playing, turn_color: :white, turn_number: 1}
    end
  end

  defp start_with_opening_roll(%{variant: variant} = engine) do
    runtime =
      engine.runtime
      |> Map.put(:turn_color, nil)
      |> Map.put(:turn_number, 0)
      |> Map.put(:dice, nil)
      |> Map.put(:legal_moves, [])
      |> initialize_opening_roll_state(variant)

    %{
      engine
      | runtime: runtime,
        board: runtime.board,
        trictrac: Map.get(runtime, :trictrac),
        status: :playing,
        turn_color: nil,
        turn_number: 0,
        dice: nil,
        legal_moves: []
    }
  end

  defp actor(engine, user, client_id) do
    Enum.find([engine.players.host, engine.players.guest], fn player ->
      player && (player.client_id == client_id || player.name == user)
    end)
  end

  defp player(name, color, client_id) do
    %{
      id: System.unique_integer([:positive]),
      name: name,
      color: color,
      client_id: client_id
    }
  end

  defp player_map(player),
    do: %{"id" => player.id, "name" => player.name, "color" => Atom.to_string(player.color)}

  defp same_client?(player, client_id),
    do: player.client_id == client_id and not is_nil(client_id)

  defp decision_actor_color(engine) do
    case current_pending_turn_decision(engine) || %{} do
      %{"actorColor" => color} when is_binary(color) -> String.to_existing_atom(color)
      %{:actorColor => color} when is_atom(color) -> color
      _ -> engine.turn_color
    end
  rescue
    ArgumentError -> engine.turn_color
  end

  defp current_pending_turn_decision(%{pending_turn_decision: pending})
       when not is_nil(pending),
       do: pending

  defp current_pending_turn_decision(%{variant: %{family: :trictrac}, trictrac: trictrac}) do
    Classique.current_pending_event(trictrac)
  end

  defp current_pending_turn_decision(_engine), do: nil

  defp opposite(:white), do: :black
  defp opposite(:black), do: :white

  defp opening_roll_pending?(engine) do
    opening_roll_supported?(engine.variant) and
      engine.status == :playing and
      is_nil(engine.turn_color) and
      is_nil(engine.dice) and
      engine.turn_number == 0 and
      (engine.variant.id != "brade" or engine.match.results == [])
  end

  defp roll_allowed?(engine, actor) do
    cond do
      not is_nil(engine.pending_match_options) ->
        false

      opening_roll_pending?(engine) ->
        is_nil(get_in(opening_rolls(engine.runtime, engine.variant), [actor.color]))

      true ->
        actor.color == engine.turn_color
    end
  end

  defp roll_error(engine, actor) do
    cond do
      not is_nil(engine.pending_match_options) ->
        "Match options must be resolved before rolling."

      opening_roll_pending?(engine) and
          not is_nil(get_in(opening_rolls(engine.runtime, engine.variant), [actor.color])) ->
        "You already rolled to decide who starts."

      true ->
        "Not your turn."
    end
  end

  defp opening_roll(engine, actor) do
    [value] = Dice.roll_one()
    runtime = runtime_view(engine)
    runtime = put_opening_roll_value(runtime, engine.variant, actor.color, value)
    starter_rolls = opening_rolls(runtime, engine.variant)

    runtime =
      case starter_rolls do
        %{white: white, black: black}
        when is_integer(white) and is_integer(black) and white == black ->
          runtime
          |> clear_active_turn()
          |> initialize_opening_roll_state(engine.variant)

        %{white: white, black: black} when is_integer(white) and is_integer(black) ->
          runtime
          |> resolve_opening_roll_turn(engine.variant, white, black)
          |> clear_opening_rolls(engine.variant)

        _ ->
          clear_active_turn(runtime)
      end

    apply_runtime(engine, runtime)
  end

  defp rabattues_confirm(engine, actor) do
    runtime = runtime_view(engine)
    winner_kind = Rabattues.winner(runtime, actor.color)

    cond do
      winner_kind ->
        engine
        |> Map.put(:match, %{
          engine.match
          | is_over: true,
            winner: Atom.to_string(actor.color),
            winner_kind: winner_kind
        })
        |> Map.put(:status, :match_over)
        |> Map.put(:dice, nil)
        |> Map.put(:legal_moves, [])

      assist_runtime = rabattues_assist_runtime(runtime, actor.color) ->
        apply_runtime(engine, assist_runtime)

      true ->
        roller_color = Map.get(runtime, :roller_color, engine.turn_color)
        next_color = if runtime.carry_turn, do: roller_color, else: opposite(roller_color)

        %{
          engine
          | runtime: Map.merge(engine.runtime, %{roller_color: nil, carry_turn: false}),
            dice: nil,
            legal_moves: [],
            history: [],
            turn_color: next_color,
            turn_number: engine.turn_number + 1
        }
    end
  end

  defp rabattues_assist_runtime(runtime, actor_color) do
    moves_left = get_in(runtime, [:dice, :moves_left]) || []
    roller_color = Map.get(runtime, :roller_color, actor_color)
    assistant_color = opposite(actor_color)
    roller_phase = Rabattues.play_phase(runtime, roller_color)

    cond do
      actor_color != roller_color ->
        nil

      roller_phase != :rabattre ->
        nil

      moves_left == [] ->
        nil

      true ->
        assistant_moves = Rabattues.legal_moves(runtime, assistant_color)

        if assistant_moves == [] do
          nil
        else
          runtime
          |> Map.put(:roller_color, roller_color)
          |> Map.put(:turn_color, assistant_color)
          |> Map.put(:legal_moves, assistant_moves)
        end
    end
  end

  defp runtime_length(engine, options) do
    cond do
      engine.variant.id == "toc" ->
        String.to_integer(
          to_string(Map.get(options, "holeTarget", Map.get(options, :holeTarget, 1)))
        )

      engine.variant.id == "brade" ->
        String.to_integer(
          to_string(Map.get(options, "matchLength", Map.get(options, :matchLength, 5)))
        )

      engine.variant.id == "tavli" ->
        String.to_integer(
          to_string(Map.get(options, "tavliTarget", Map.get(options, :tavliTarget, 7)))
        )

      true ->
        engine.match.length
    end
  end

  defp pending_match_options(%{variant: %{id: "tavli"}, match: match}) do
    if is_nil(get_in(match, [:options, "tavliTarget"])), do: tavli_target_consent(), else: nil
  end

  defp pending_match_options(%{variant: %{family: :trictrac} = variant, match: match}) do
    trictrac_pending_match_options(variant, match.options || %{})
  end

  defp pending_match_options(%{variant: %{family: :race} = variant}),
    do: RaceCore.pending_options(variant)

  defp pending_match_options(%{variant: %{family: :tourne_case}}),
    do: TourneCase.pending_options()

  defp pending_match_options(_engine), do: nil

  defp handle_trictrac_margot_consent(engine, actor, options, pending) do
    case normalize_margot_consent(options) do
      nil ->
        {:error, "Choose yes or no for Margot la fendue."}

      response ->
        color_key = Atom.to_string(actor.color)
        responses = Map.put(pending["responses"] || %{}, color_key, response)
        updated_pending = Map.put(pending, "responses", responses)

        cond do
          Enum.any?(Map.values(responses), &(&1 == "no")) ->
            {:ok, finalize_trictrac_margot(engine, false)}

          Enum.all?(["white", "black"], fn color -> Map.get(responses, color) == "yes" end) ->
            {:ok, finalize_trictrac_margot(engine, true)}

          true ->
            {:ok, %{engine | pending_match_options: updated_pending}}
        end
    end
  end

  defp handle_tavli_target_consent(engine, actor, options, pending) do
    case normalize_tavli_target_consent(options) do
      nil ->
        {:error, "Choose 3, 5, 7, or 9 points for Tavli."}

      response ->
        color_key = Atom.to_string(actor.color)
        responses = Map.put(pending["responses"] || %{}, color_key, response)
        updated_pending = Map.put(pending, "responses", responses)
        white = Map.get(responses, "white")
        black = Map.get(responses, "black")

        cond do
          is_nil(white) or is_nil(black) ->
            {:ok, %{engine | pending_match_options: updated_pending}}

          white == black ->
            {:ok, finalize_tavli_option(engine, %{"tavliTarget" => white})}

          true ->
            {:ok, finalize_tavli_option(engine, %{"tavliTarget" => "7"})}
        end
    end
  end

  defp handle_trictrac_partie_length_consent(engine, actor, options, pending) do
    case normalize_partie_length_consent(options) do
      nil ->
        {:error, "Choose a marque target."}

      response ->
        color_key = Atom.to_string(actor.color)
        responses = Map.put(pending["responses"] || %{}, color_key, response)
        updated_pending = Map.put(pending, "responses", responses)
        white = Map.get(responses, "white")
        black = Map.get(responses, "black")

        cond do
          is_nil(white) or is_nil(black) ->
            {:ok, %{engine | pending_match_options: updated_pending}}

          white == black ->
            {:ok, finalize_trictrac_option(engine, %{"aEcrirePartieLength" => white})}

          true ->
            {:ok, finalize_trictrac_option(engine, %{"aEcrirePartieLength" => "16"})}
        end
    end
  end

  defp finalize_trictrac_margot(engine, enabled) do
    finalize_trictrac_option(engine, %{"margotEnabled" => enabled})
  end

  defp finalize_tavli_option(engine, options) do
    runtime = RaceCore.submit_options(runtime_view(engine), engine.variant, options)

    updated =
      engine
      |> apply_runtime(runtime)
      |> update_in([:match, :options], &Map.merge(&1 || %{}, options))

    case pending_match_options(updated) do
      nil ->
        updated
        |> Map.put(:pending_match_options, nil)
        |> start_after_options()

      next_pending ->
        %{updated | status: :awaiting_match_options, pending_match_options: next_pending}
    end
  end

  defp finalize_trictrac_option(engine, options) do
    runtime =
      TrictracCore.submit_options(runtime_view(engine), engine.variant, options)

    updated =
      engine
      |> apply_runtime(runtime)
      |> update_in([:match, :options], &Map.merge(&1 || %{}, options))

    case pending_match_options(updated) do
      nil ->
        updated
        |> Map.put(:pending_match_options, nil)
        |> start_after_options()

      next_pending ->
        %{updated | status: :awaiting_match_options, pending_match_options: next_pending}
    end
  end

  defp normalize_margot_consent(options) do
    case Map.get(options, "margotConsent", Map.get(options, :margotConsent)) do
      true -> "yes"
      false -> "no"
      "yes" -> "yes"
      "no" -> "no"
      _ -> nil
    end
  end

  defp normalize_partie_length_consent(options) do
    case Map.get(
           options,
           "aEcrirePartieLengthConsent",
           Map.get(options, :aEcrirePartieLengthConsent)
         ) do
      value when value in ["6", "8", "12", "16", "18", "20", "24"] -> value
      value when value in [6, 8, 12, 16, 18, 20, 24] -> Integer.to_string(value)
      _ -> nil
    end
  end

  defp normalize_tavli_target_consent(options) do
    case Map.get(options, "tavliTargetConsent", Map.get(options, :tavliTargetConsent)) do
      value when value in ["3", "5", "7", "9"] -> value
      value when value in [3, 5, 7, 9] -> Integer.to_string(value)
      _ -> nil
    end
  end

  defp tavli_target_consent do
    %{
      "kind" => "tavli_target_consent",
      "rule" => "Tavli",
      "prompt" => "Choose the Tavli target. If you disagree, the match defaults to 7.",
      "choices" => ["3", "5", "7", "9"],
      "choiceLabels" => %{
        "3" => "3 points",
        "5" => "5 points",
        "7" => "7 points",
        "9" => "9 points"
      },
      "responses" => %{"white" => nil, "black" => nil}
    }
  end

  defp trictrac_margot_consent do
    %{
      "kind" => "trictrac_margot_consent",
      "rule" => "TrictracMargotConsent",
      "prompt" => "Play with Margot la fendue?",
      "choices" => ["yes", "no"],
      "responses" => %{"white" => nil, "black" => nil}
    }
  end

  defp trictrac_partie_length_consent(rule) do
    %{
      "kind" => "trictrac_partie_length_consent",
      "rule" => rule,
      "prompt" => "Choose the marque target. If you disagree, the match defaults to 16.",
      "choices" => ["6", "8", "12", "16", "18", "20", "24"],
      "choiceLabels" => %{
        "6" => "6 marques",
        "8" => "8 marques",
        "12" => "12 marques",
        "16" => "16 marques",
        "18" => "18 marques",
        "20" => "20 marques",
        "24" => "24 marques"
      },
      "responses" => %{"white" => nil, "black" => nil}
    }
  end

  defp trictrac_pending_match_options(%{id: id}, options)
       when id in ["trictrac_aecrire", "trictrac_combine"] do
    rule =
      if id == "trictrac_aecrire" do
        "RuleFrTrictracAEcrire"
      else
        "RuleFrTrictracCombine"
      end

    cond do
      is_nil(options["aEcrirePartieLength"]) ->
        trictrac_partie_length_consent(rule)

      is_nil(options["margotEnabled"]) ->
        trictrac_margot_consent()

      true ->
        nil
    end
  end

  defp trictrac_pending_match_options(%{id: id}, options) when id in @trictrac_margot_variants do
    if is_nil(options["margotEnabled"]), do: trictrac_margot_consent(), else: nil
  end

  defp trictrac_pending_match_options(variant, _options),
    do: TrictracCore.pending_options(variant)

  defp stringify_option_keys(options) do
    Enum.into(options, %{}, fn {key, value} -> {to_string(key), value} end)
  end

  defp opening_roll_supported?(%{id: id})
       when id in [
              "tapa",
              "jacquet",
              "garanguet",
              "tavli",
              "backgammon",
              "brade",
              "sbaraglio",
              "sbaraglino",
              "tourne_case",
              "dames_rabattues",
              "trictrac_classique",
              "trictrac_aecrire",
              "trictrac_combine",
              "toc",
              "toccategli"
            ],
       do: true

  defp opening_roll_supported?(_variant), do: false

  defp opening_rolls(runtime, %{id: "brade"}) do
    get_in(runtime, [:variant_state, :brade_teker_rolls]) || %{white: nil, black: nil}
  end

  defp opening_rolls(runtime, _variant) do
    get_in(runtime, [:variant_state, :opening_rolls]) || %{white: nil, black: nil}
  end

  defp initialize_opening_roll_state(runtime, %{id: "brade"}) do
    runtime
    |> put_variant_state(:starter, nil)
    |> put_variant_state(:brade_teker_rolls, %{white: nil, black: nil})
  end

  defp initialize_opening_roll_state(runtime, _variant) do
    put_variant_state(runtime, :opening_rolls, %{white: nil, black: nil})
  end

  defp put_opening_roll_value(runtime, %{id: "brade"}, color, value) do
    put_variant_state(
      runtime,
      :brade_teker_rolls,
      Map.put(opening_rolls(runtime, %{id: "brade"}), color, value)
    )
  end

  defp put_opening_roll_value(runtime, variant, color, value) do
    put_variant_state(
      runtime,
      :opening_rolls,
      Map.put(opening_rolls(runtime, variant), color, value)
    )
  end

  defp clear_opening_rolls(runtime, %{id: "brade"}) do
    put_variant_state(runtime, :brade_teker_rolls, %{white: nil, black: nil})
  end

  defp clear_opening_rolls(runtime, _variant) do
    put_variant_state(runtime, :opening_rolls, %{white: nil, black: nil})
  end

  defp opening_roll_starter(%{id: "brade"}, white, black) do
    if white < black, do: :white, else: :black
  end

  defp opening_roll_starter(_variant, white, black) do
    if white > black, do: :white, else: :black
  end

  defp resolve_opening_roll_turn(runtime, variant, white, black) do
    starter = opening_roll_starter(variant, white, black)

    runtime
    |> Map.put(:turn_color, starter)
    |> Map.put(:turn_number, 1)
    |> Map.put(:dice, nil)
    |> Map.put(:legal_moves, [])
    |> apply_opening_setup(variant, starter)
  end

  defp apply_opening_setup(runtime, %{family: :race} = variant, starter) do
    RaceCore.apply_opening_setup(runtime, variant, starter)
  end

  defp apply_opening_setup(runtime, variant, starter) do
    maybe_put_starter(runtime, variant, starter)
  end

  defp maybe_put_starter(runtime, %{id: "brade"}, starter),
    do: put_variant_state(runtime, :starter, starter)

  defp maybe_put_starter(runtime, _variant, _starter), do: runtime

  defp put_variant_state(runtime, key, value) do
    variant_state = Map.get(runtime, :variant_state) || %{}
    Map.put(runtime, :variant_state, Map.put(variant_state, key, value))
  end

  defp clear_active_turn(runtime) do
    runtime
    |> Map.put(:turn_color, nil)
    |> Map.put(:turn_number, 0)
    |> Map.put(:dice, nil)
    |> Map.put(:legal_moves, [])
  end
end
