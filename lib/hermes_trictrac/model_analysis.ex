defmodule HermesTrictrac.ModelAnalysis do
  alias HermesTrictrac.{
    BackgammonAiBot,
    TrictracModelBot,
    Xgid
  }

  alias HermesTrictrac.Rules.{RaceCore, Registry, TrictracCore}
  alias HermesTrictrac.Rules.Trictrac.Classique
  alias HermesTrictrac.Training.TrictracBridge

  @run_counts [10, 25, 50]
  @max_turn_steps 16

  def models do
    [
      %{
        id: "backgammon_ai",
        label: BackgammonAiBot.model_name(),
        kind: "backgammon_ai",
        variant_id: "backgammon",
        movement_mode: movement_mode_for_variant_id("backgammon"),
        black_direction: black_direction_for_variant_id("backgammon"),
        uses_bar: uses_bar_for_variant_id("backgammon"),
        trictrac: false
      }
      | TrictracModelBot.presets()
        |> Enum.filter(& &1.available)
        |> Enum.map(fn preset ->
          %{
            id: "trictrac_zero:" <> preset.id,
            label: preset.model_name,
            kind: "trictrac_zero",
            preset: preset.id,
            variant_id: preset.variant_id,
            movement_mode: movement_mode_for_variant_id(preset.variant_id),
            black_direction: black_direction_for_variant_id(preset.variant_id),
            uses_bar: uses_bar_for_variant_id(preset.variant_id),
            margot_enabled: preset.margot_enabled,
            trictrac: true
          }
        end)
    ]
  end

  def parse(params) when is_map(params) do
    with {:ok, model} <- model_config(Map.get(params, "model")),
         {:ok, parsed} <- Xgid.parse(Map.get(params, "xgid", "")),
         :ok <- validate_bar_support(parsed.board, model),
         {:ok, turn_color} <- requested_turn_color(params, parsed),
         {:ok, black_direction} <- requested_black_direction(params, model) do
      parsed = %{parsed | turn_color: turn_color}

      {:ok,
       parsed_response(
         parsed,
         movement_mode_for_model(model),
         black_direction,
         uses_bar_for_model(model)
       )}
    end
  end

  def run(params) when is_map(params) do
    with {:ok, model} <- model_config(Map.get(params, "model")),
         {:ok, parsed} <- Xgid.parse(Map.get(params, "xgid", "")),
         :ok <- validate_bar_support(parsed.board, model),
         {:ok, turn_color} <- requested_turn_color(params, parsed),
         model_movement <- movement_mode_for_model(model),
         {:ok, black_direction} <- requested_black_direction(params, model),
         {:ok, dice} <- requested_dice(params, parsed),
         {:ok, runs} <- requested_runs(Map.get(params, "runs")),
         parsed <- %{parsed | turn_color: turn_color},
         {:ok, runtime, variant, match_options} <-
           build_runtime(parsed, dice, model, black_direction) do
      case ensure_model_ready(model) do
        :ok ->
          outcomes =
            Enum.map(1..runs, fn run_number ->
              run_once(runtime, variant, match_options, model, run_number)
            end)

          {:ok,
           %{
             model: model,
             runs: runs,
             position:
               parsed_response(
                 %{parsed | dice: dice},
                 model_movement,
                 black_direction,
                 uses_bar_for_model(model)
               ),
             results: summarize_outcomes(outcomes),
             errors: outcome_errors(outcomes)
           }}

        {:error, msg} ->
          {:error, msg}
      end
    end
  end

  defp model_config(nil), do: model_config(default_model_id())
  defp model_config(""), do: model_config(default_model_id())

  defp model_config(id) do
    case Enum.find(models(), &(&1.id == id)) do
      nil -> {:error, "Unknown model: #{id}."}
      model -> {:ok, model}
    end
  end

  defp default_model_id do
    models()
    |> Enum.find(&(&1.id == "trictrac_zero:classique"))
    |> case do
      nil -> "backgammon_ai"
      model -> model.id
    end
  end

  defp requested_runs(value) when is_integer(value) and value in @run_counts, do: {:ok, value}

  defp requested_runs(value) when is_binary(value) do
    case Integer.parse(value) do
      {runs, ""} when runs in @run_counts -> {:ok, runs}
      _ -> {:error, "Run count must be 10, 25, or 50."}
    end
  end

  defp requested_runs(_value), do: {:error, "Run count must be 10, 25, or 50."}

  defp requested_turn_color(params, parsed) do
    case Map.get(params, "turn_color", Map.get(params, "turnColor")) do
      value when value in [nil, "", "xgid", "from_xgid"] ->
        {:ok, parsed.turn_color}

      value when value in ["white", :white] ->
        {:ok, :white}

      value when value in ["black", :black] ->
        {:ok, :black}

      other ->
        {:error, "Side to play must be white, black, or from the XGID. Got #{inspect(other)}."}
    end
  end

  defp requested_black_direction(params, model) do
    default = Map.get(model, :black_direction, "toward_1")

    case Map.get(params, "black_direction", Map.get(params, "blackDirection", default)) do
      value when value in [nil, ""] -> {:ok, default}
      value when value in ["toward_1", :toward_1] -> {:ok, "toward_1"}
      value when value in ["toward_24", :toward_24] -> {:ok, "toward_24"}
      other -> {:error, "Black direction must be toward_1 or toward_24. Got #{inspect(other)}."}
    end
  end

  defp validate_bar_support(board, model) do
    if uses_bar_for_model(model) or bar_empty?(board) do
      :ok
    else
      {:error, "#{model.label} does not use a bar; remove bar checkers from the XGID."}
    end
  end

  defp bar_empty?(board) do
    (get_in(board || %{}, [:bar, :white]) || 0) == 0 and
      (get_in(board || %{}, [:bar, :black]) || 0) == 0
  end

  defp requested_dice(params, parsed) do
    dice =
      case {Map.get(params, "die1"), Map.get(params, "die2"), Map.get(params, "dice")} do
        {die1, die2, _dice} when not is_nil(die1) and not is_nil(die2) ->
          [die1, die2]

        {_die1, _die2, dice} when not is_nil(dice) and dice != "" ->
          dice

        _ ->
          parsed.dice
      end

    Xgid.parse_dice(dice)
  end

  defp build_runtime(parsed, dice, %{variant_id: variant_id} = model, black_direction) do
    variant = Registry.fetch!(variant_id)
    variant = apply_black_direction(variant, black_direction)
    match_options = match_options(model, black_direction)
    turn_color = parsed.turn_color
    expanded_dice = dice_for_variant(variant, dice)

    dice_state = %{
      values: expanded_dice,
      moves: expanded_dice,
      moves_left: expanded_dice,
      moves_played: []
    }

    match = match_state(variant, parsed, match_options)

    runtime =
      case variant.family do
        :trictrac ->
          variant
          |> TrictracCore.new()
          |> TrictracCore.submit_options(variant, match_options)
          |> Map.put(:board, parsed.board)
          |> Map.put(:match, match)
          |> Map.put(:turn_color, turn_color)
          |> Map.put(:turn_number, 1)
          |> Map.put(:dice, dice_state)
          |> Map.put(:history, [])
          |> Map.put(:pending_turn_decision, nil)
          |> begin_trictrac_turn(variant, turn_color, dice_state, match_options)
          |> then(&Map.put(&1, :legal_moves, RaceCore.legal_moves(&1, variant, turn_color)))

        :race ->
          variant
          |> RaceCore.new()
          |> Map.put(:board, parsed.board)
          |> Map.put(:match, match)
          |> Map.put(:turn_color, turn_color)
          |> Map.put(:turn_number, 1)
          |> Map.put(:dice, dice_state)
          |> Map.put(:history, [])
          |> Map.put(:pending_turn_decision, nil)
          |> then(&Map.put(&1, :legal_moves, RaceCore.legal_moves(&1, variant, turn_color)))
      end

    {:ok, runtime, variant, match_options}
  end

  defp begin_trictrac_turn(runtime, variant, color, dice_state, match_options) do
    trictrac =
      runtime.trictrac
      |> Classique.apply_options(match_options)
      |> Classique.begin_turn(runtime.board, variant, color, dice_state)

    %{runtime | trictrac: trictrac}
  end

  defp match_options(%{kind: "trictrac_zero", margot_enabled: margot_enabled}, black_direction) do
    %{"margotEnabled" => margot_enabled == true, "black_direction" => black_direction}
  end

  defp match_options(_model, _black_direction), do: %{}

  defp match_state(variant, parsed, options) do
    length = max(parsed.match_length || 0, 1)

    %{
      is_over: false,
      score: parsed.score,
      length: length,
      winner: nil,
      winner_kind: nil,
      results: [],
      options: options,
      variant_id: variant.id
    }
  end

  defp dice_for_variant(%{doubles_mode: :repeat_four}, [a, a]), do: [a, a, a, a]
  defp dice_for_variant(_variant, [a, b]), do: [a, b]

  defp ensure_model_ready(%{kind: "backgammon_ai"}), do: BackgammonAiBot.ready()

  defp ensure_model_ready(%{kind: "trictrac_zero", preset: preset}),
    do: TrictracModelBot.ready(preset)

  defp run_once(runtime, variant, match_options, %{kind: "trictrac_zero"} = model, run_number) do
    initial_events = score_events(runtime)

    case run_trictrac_turn(runtime, variant, match_options, model, [], @max_turn_steps) do
      {:ok, final_runtime, actions} ->
        line_events = line_events_for_actions(runtime, variant, actions)

        outcome(
          run_number,
          actions,
          score_events_since(initial_events, final_runtime),
          final_runtime,
          line_events
        )

      {:error, msg, actions} ->
        error_outcome(run_number, actions, msg)
    end
  end

  defp run_once(runtime, variant, _match_options, %{kind: "backgammon_ai"}, run_number) do
    case run_backgammon_turn(runtime, variant, [], @max_turn_steps) do
      {:ok, final_runtime, actions} -> outcome(run_number, actions, [], final_runtime, [])
      {:error, msg, actions} -> error_outcome(run_number, actions, msg)
    end
  end

  defp run_trictrac_turn(_runtime, _variant, _match_options, _model, actions, 0) do
    {:error, "Model turn exceeded #{@max_turn_steps} actions.", actions}
  end

  defp run_trictrac_turn(runtime, variant, match_options, model, actions, steps_left) do
    serialized = TrictracBridge.serialize_state(runtime)

    with {:ok, action} <- TrictracModelBot.choose_action(model.preset, serialized),
         {:ok, response} <-
           TrictracBridge.step(
             serialized,
             action,
             %{
               "variant_id" => variant.id,
               "black_direction" => black_direction_for_variant(variant),
               "match_options" => match_options
             }
           ) do
      next_runtime = TrictracBridge.decode_runtime_term(response["state"]["runtime_term"])
      actions = actions ++ [action]

      if confirm_action?(action) or terminal_after_turn?(runtime, next_runtime) do
        {:ok, next_runtime, actions}
      else
        run_trictrac_turn(next_runtime, variant, match_options, model, actions, steps_left - 1)
      end
    else
      {:error, msg} -> {:error, msg, actions}
    end
  end

  defp run_backgammon_turn(_runtime, _variant, actions, 0) do
    {:error, "Model turn exceeded #{@max_turn_steps} actions.", actions}
  end

  defp run_backgammon_turn(runtime, variant, actions, steps_left) do
    serialized = BackgammonAiBot.serialize_state(runtime, variant)

    with {:ok, action} <- BackgammonAiBot.choose_action(serialized),
         {:ok, next_runtime} <- apply_backgammon_action(runtime, variant, action) do
      actions = actions ++ [action]

      if confirm_action?(action) or terminal_after_turn?(runtime, next_runtime) do
        {:ok, next_runtime, actions}
      else
        run_backgammon_turn(next_runtime, variant, actions, steps_left - 1)
      end
    else
      {:error, msg} -> {:error, msg, actions}
    end
  end

  defp apply_backgammon_action(runtime, variant, %{"type" => "move"} = action) do
    RaceCore.move(runtime, variant, runtime.turn_color, %{
      "from" => action["from"],
      "to" => action["to"],
      "die" => action["die"],
      "dice_used" => action["dice_used"],
      "sequence" => action["sequence"]
    })
  end

  defp apply_backgammon_action(runtime, variant, %{"type" => "special", "id" => "CONFIRM"}) do
    RaceCore.confirm(runtime, variant, runtime.turn_color)
  end

  defp apply_backgammon_action(_runtime, _variant, action) do
    {:error, "Unsupported BackgammonAI action: #{inspect(action)}"}
  end

  defp terminal_after_turn?(before_runtime, after_runtime) do
    before_runtime.turn_color != after_runtime.turn_color or is_nil(after_runtime.dice) or
      get_in(after_runtime, [:match, :is_over]) == true or
      not is_nil(Map.get(after_runtime, :pending_turn_decision))
  end

  defp confirm_action?(%{"type" => "special", "id" => "CONFIRM"}), do: true
  defp confirm_action?(_action), do: false

  @doc false
  def line_events_for_actions(runtime, variant, actions) when is_list(actions) do
    color = runtime.turn_color
    start_board = runtime.board

    {_runtime, _used_dice, events} =
      Enum.reduce(actions, {runtime, [], []}, fn action, {current_runtime, used_dice, acc} ->
        move = matching_legal_move(current_runtime, action)
        action_dice = action_dice_used(move, action)

        case apply_trictrac_action(current_runtime, variant, action) do
          {:ok, next_runtime} ->
            next_used_dice = used_dice ++ action_dice

            next_events =
              case Map.get(action, "type") do
                "move" when next_used_dice != [] ->
                  acc ++
                    HermesTrictrac.Rules.Trictrac.Classique.Events.detect_turn_events(
                      start_board,
                      next_runtime.board,
                      variant,
                      color,
                      prefix_dice(next_used_dice),
                      current_runtime.trictrac
                    ).events

                _ ->
                  acc
              end

            {next_runtime, next_used_dice, next_events}

          {:error, _msg} ->
            {current_runtime, used_dice, acc}
        end
      end)

    Enum.uniq_by(events, &event_signature/1)
  end

  defp outcome(run_number, actions, events, final_runtime, line_events) do
    %{
      ok: true,
      run_number: run_number,
      actions: Enum.map(actions, &serialize_action/1),
      move_text: move_text(actions),
      events: Enum.map(events, &serialize_event/1),
      line_events: Enum.map(line_events, &serialize_event/1),
      pending_turn_decision: serialize_nested(Map.get(final_runtime, :pending_turn_decision))
    }
  end

  defp error_outcome(run_number, actions, msg) do
    %{
      ok: false,
      run_number: run_number,
      actions: Enum.map(actions, &serialize_action/1),
      move_text: move_text(actions),
      events: [],
      line_events: [],
      error: msg
    }
  end

  defp summarize_outcomes(outcomes) do
    outcomes
    |> Enum.group_by(&outcome_signature/1)
    |> Enum.map(fn {_signature, group} ->
      representative = List.first(group)

      %{
        count: length(group),
        percentage: Float.round(length(group) * 100 / max(length(outcomes), 1), 1),
        move_text: representative.move_text,
        actions: representative.actions,
        events: representative.events,
        line_events: Map.get(representative, :line_events, []),
        pending_turn_decision: Map.get(representative, :pending_turn_decision),
        errors:
          Enum.flat_map(group, fn outcome -> if outcome.ok, do: [], else: [outcome.error] end)
      }
    end)
    |> Enum.sort_by(&{-&1.count, &1.move_text})
  end

  defp outcome_signature(%{actions: actions, events: events, error: error}) do
    :erlang.term_to_binary({actions, events, error})
  end

  defp outcome_signature(%{actions: actions, events: events, line_events: line_events}) do
    :erlang.term_to_binary({actions, events, line_events})
  end

  defp outcome_signature(%{actions: actions, events: events}) do
    :erlang.term_to_binary({actions, events})
  end

  defp outcome_errors(outcomes) do
    outcomes
    |> Enum.reject(& &1.ok)
    |> Enum.map(&%{run_number: &1.run_number, error: &1.error, actions: &1.actions})
  end

  defp move_text(actions) do
    move_actions =
      actions
      |> Enum.filter(&(Map.get(&1, "type") == "move"))
      |> Enum.map(&move_action_text/1)

    cond do
      move_actions != [] -> Enum.join(move_actions, ", ")
      Enum.any?(actions, &confirm_action?/1) -> "Confirm"
      true -> "No move"
    end
  end

  defp move_action_text(action) do
    "#{space_label(action["from"])}/#{space_label(action["to"])}" <>
      sequence_suffix(action["sequence"])
  end

  defp sequence_suffix(sequence) when is_list(sequence) and sequence != [] do
    " (" <> Enum.join(sequence, "+") <> ")"
  end

  defp sequence_suffix(_sequence), do: ""

  defp space_label("bar"), do: "bar"
  defp space_label("home"), do: "off"
  defp space_label(point) when is_integer(point), do: Integer.to_string(24 - point)
  defp space_label(point), do: to_string(point)

  defp parsed_response(parsed, movement_mode, black_direction, uses_bar) do
    %{
      id: parsed.id,
      board: serialize_board(parsed.board),
      turn_color: Atom.to_string(parsed.turn_color),
      dice: parsed.dice,
      movement_mode: movement_mode,
      black_direction: black_direction,
      white_direction: white_direction(movement_mode, black_direction),
      uses_bar: uses_bar,
      score: stringify_keys(parsed.score),
      match_length: parsed.match_length
    }
  end

  defp serialize_board(board) do
    %{
      points:
        board.points
        |> Enum.with_index()
        |> Enum.map(fn {point, index} ->
          %{
            index: index,
            display: 24 - index,
            white: point.white || 0,
            black: point.black || 0
          }
        end),
      bar: stringify_keys(board.bar),
      outside: stringify_keys(board.outside)
    }
  end

  defp score_events(nil), do: []

  defp score_events(runtime) do
    get_in(runtime, [:trictrac, :score_history]) || []
  end

  defp score_events_since(initial_events, final_runtime) do
    final_runtime
    |> score_events()
    |> Enum.drop(length(initial_events))
  end

  defp serialize_action(action), do: serialize_nested(action)

  defp serialize_event(event) do
    event
    |> serialize_nested()
    |> Map.take([
      "rule",
      "label",
      "piece_type",
      "beneficiary",
      "points",
      "trous_delta",
      "turn_number",
      "source",
      "metadata"
    ])
  end

  defp serialize_nested(value) when is_struct(value),
    do: value |> Map.from_struct() |> serialize_nested()

  defp serialize_nested(value) when is_map(value) do
    Enum.into(value, %{}, fn {key, inner} -> {to_string(key), serialize_nested(inner)} end)
  end

  defp serialize_nested(value) when is_atom(value) and value not in [true, false, nil],
    do: Atom.to_string(value)

  defp serialize_nested(value) when is_list(value), do: Enum.map(value, &serialize_nested/1)
  defp serialize_nested(value), do: value

  defp apply_trictrac_action(runtime, variant, %{"type" => "move"} = action) do
    TrictracCore.move(runtime, variant, runtime.turn_color, move_payload(action))
  end

  defp apply_trictrac_action(runtime, variant, %{"type" => "special", "id" => "CONFIRM"}) do
    TrictracCore.confirm(runtime, variant, runtime.turn_color)
  end

  defp apply_trictrac_action(
         runtime,
         variant,
         %{"type" => "special", "id" => "DECISION_TENIR"}
       ) do
    TrictracCore.submit_turn_decision(runtime, variant, runtime.turn_color, "tenir")
  end

  defp apply_trictrac_action(
         runtime,
         variant,
         %{"type" => "special", "id" => "DECISION_SEN_ALLER"}
       ) do
    TrictracCore.submit_turn_decision(runtime, variant, runtime.turn_color, "s'en aller")
  end

  defp apply_trictrac_action(
         runtime,
         variant,
         %{"type" => "special", "id" => "DECISION_SUSPEND_CLASSIQUE"}
       ) do
    TrictracCore.submit_turn_decision(runtime, variant, runtime.turn_color, "suspend_classique")
  end

  defp apply_trictrac_action(
         runtime,
         variant,
         %{"type" => "special", "id" => "DECISION_SUSPEND_A_ECRIRE"}
       ) do
    TrictracCore.submit_turn_decision(runtime, variant, runtime.turn_color, "suspend_a_ecrire")
  end

  defp apply_trictrac_action(runtime, variant, %{"type" => "special", "id" => "DECISION_NONE"}) do
    TrictracCore.submit_turn_decision(runtime, variant, runtime.turn_color, "none")
  end

  defp apply_trictrac_action(_runtime, _variant, _action), do: {:error, "Unsupported action."}

  defp move_payload(action) do
    payload = %{"from" => Map.get(action, "from"), "to" => Map.get(action, "to")}

    case Map.get(action, "sequence") do
      sequence when is_list(sequence) -> Map.put(payload, "sequence", sequence)
      _ -> payload
    end
  end

  defp matching_legal_move(runtime, %{"type" => "move"} = action) do
    Enum.find(runtime.legal_moves || [], fn move ->
      move.from == Map.get(action, "from") and
        move.to == Map.get(action, "to") and
        normalize_sequence(Map.get(move, :sequence)) ==
          normalize_sequence(Map.get(action, "sequence"))
    end)
  end

  defp matching_legal_move(_runtime, _action), do: nil

  defp action_dice_used(%{dice_used: dice_used}, _action) when is_list(dice_used), do: dice_used
  defp action_dice_used(%{die: die}, _action) when is_integer(die), do: [die]

  defp action_dice_used(_move, action) do
    case Map.get(action, "sequence") do
      sequence when is_list(sequence) -> sequence
      _ -> []
    end
  end

  defp prefix_dice(used_dice) do
    %{
      values: used_dice,
      moves: used_dice,
      moves_left: [],
      moves_played: used_dice
    }
  end

  defp event_signature(event) do
    :erlang.term_to_binary({
      Map.get(event, :rule),
      Map.get(event, :label),
      Map.get(event, :piece_type),
      Map.get(event, :beneficiary),
      Map.get(event, :points),
      Map.get(event, :source),
      Map.get(event, :metadata)
    })
  end

  defp normalize_sequence(sequence) when is_list(sequence), do: sequence
  defp normalize_sequence(_sequence), do: []

  defp stringify_keys(map),
    do: Enum.into(map || %{}, %{}, fn {key, value} -> {to_string(key), value} end)

  defp movement_mode_for_model(%{movement_mode: movement_mode}), do: movement_mode

  defp movement_mode_for_model(%{variant_id: variant_id}),
    do: movement_mode_for_variant_id(variant_id)

  defp movement_mode_for_variant_id(variant_id) do
    variant_id
    |> Registry.fetch!()
    |> movement_mode_for_variant()
  end

  defp movement_mode_for_variant(%{movement_mode: :parallel}), do: "parallel"
  defp movement_mode_for_variant(%{movement_mode: :contrary}), do: "contrary"
  defp movement_mode_for_variant(%{orientation: :parallel}), do: "parallel"
  defp movement_mode_for_variant(%{orientation: :jacquet_parallel}), do: "parallel"
  defp movement_mode_for_variant(_variant), do: "contrary"

  defp uses_bar_for_model(%{uses_bar: uses_bar}), do: uses_bar
  defp uses_bar_for_model(%{variant_id: variant_id}), do: uses_bar_for_variant_id(variant_id)

  defp uses_bar_for_variant_id(variant_id) do
    variant_id
    |> Registry.fetch!()
    |> uses_bar_for_variant()
  end

  defp uses_bar_for_variant(%{uses_bar: uses_bar}), do: uses_bar
  defp uses_bar_for_variant(_variant), do: false

  defp black_direction_for_variant_id(variant_id) do
    variant_id
    |> Registry.fetch!()
    |> black_direction_for_variant()
  end

  defp black_direction_for_variant(%{orientation: orientation})
       when orientation in [:ascending, :parallel_toward_24],
       do: "toward_24"

  defp black_direction_for_variant(_variant), do: "toward_1"

  defp white_direction("parallel", black_direction), do: black_direction
  defp white_direction("contrary", "toward_1"), do: "toward_24"
  defp white_direction("contrary", "toward_24"), do: "toward_1"

  defp apply_black_direction(variant, black_direction) do
    case {movement_mode_for_variant(variant), black_direction} do
      {"parallel", "toward_1"} -> Map.put(variant, :orientation, :parallel_toward_1)
      {"parallel", "toward_24"} -> Map.put(variant, :orientation, :parallel_toward_24)
      {"contrary", "toward_1"} -> Map.put(variant, :orientation, :split_home)
      {"contrary", "toward_24"} -> Map.put(variant, :orientation, :ascending)
    end
  end
end
