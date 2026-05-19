defmodule HermesTrictrac.Training.TrictracBridge do
  alias HermesTrictrac.Rules.{Registry, TrictracCore}
  alias HermesTrictrac.Rules.Trictrac.Classique

  @default_variant_id "trictrac_classique"
  @default_match_options %{"margotEnabled" => false}
  @toc_default_options %{"holeTarget" => "7", "doublesMode" => "off"}
  @roll_action %{"type" => "special", "id" => "ROLL"}
  @confirm_action %{"type" => "special", "id" => "CONFIRM"}
  @decision_tenir_action %{"type" => "special", "id" => "DECISION_TENIR"}
  @decision_sen_aller_action %{"type" => "special", "id" => "DECISION_SEN_ALLER"}
  @decision_suspend_classique_action %{
    "type" => "special",
    "id" => "DECISION_SUSPEND_CLASSIQUE"
  }
  @decision_suspend_a_ecrire_action %{
    "type" => "special",
    "id" => "DECISION_SUSPEND_A_ECRIRE"
  }
  @decision_none_action %{"type" => "special", "id" => "DECISION_NONE"}

  def ping do
    {:ok, %{"pong" => true}}
  end

  def new_game(config \\ %{}) do
    {variant, options} = variant_and_options(config)

    runtime =
      variant
      |> TrictracCore.new()
      |> seed_runtime()
      |> TrictracCore.submit_options(variant, options)
      |> put_in([:match, :options], options)
      |> put_in([:match, :variant_id], variant.id)
      |> clear_history()

    {:ok, response(runtime, 0.0)}
  end

  def step(state, action), do: step(state, action, %{})

  def step(%{"runtime_term" => runtime_term}, action, config) do
    {variant, _options} = variant_and_options(config)
    runtime = decode_runtime_term(runtime_term)
    current_color = runtime.turn_color

    with {:ok, next_runtime} <-
           apply_action(runtime, variant, current_color, normalize_action(action)) do
      next_runtime = clear_history(next_runtime)
      reward = trous_reward(runtime, next_runtime)
      {:ok, response(next_runtime, reward)}
    end
  rescue
    ArgumentError -> {:error, "Invalid state payload."}
  end

  def step(_state, _action, _config), do: {:error, "Invalid state payload."}

  def serialize_state(runtime) do
    runtime = clear_history(runtime)

    %{
      "runtime_term" => encode_runtime_term(runtime),
      "runtime" => public_runtime(runtime),
      "phase" => phase(runtime),
      "terminal" => terminal?(runtime),
      "white_to_play" => runtime.turn_color == :white,
      "legal_actions" => legal_actions(runtime)
    }
  end

  def public_runtime(runtime) do
    runtime
    |> clear_history()
    |> Map.take([
      :board,
      :trictrac,
      :variant_state,
      :pending_turn_decision,
      :match,
      :turn_color,
      :turn_number,
      :dice,
      :legal_moves
    ])
    |> Map.put(:pending_turn_decision, pending_turn_decision(runtime))
    |> update_in([:legal_moves], fn moves ->
      moves
      |> Kernel.||([])
      |> Enum.sort_by(&move_sort_key/1)
    end)
    |> serialize_nested()
  end

  def decode_runtime_term(runtime_term) when is_binary(runtime_term) do
    runtime_term
    |> Base.decode64!()
    |> :erlang.binary_to_term()
  end

  defp variant_and_options(config) do
    config = normalize_map(config)
    variant_id = Map.get(config, "variant_id", @default_variant_id)
    black_direction = Map.get(config, "black_direction", Map.get(config, :black_direction))

    variant =
      variant_id
      |> Registry.fetch!()
      |> apply_black_direction(black_direction)

    options =
      base_match_options(variant_id)
      |> Map.merge(normalize_map(Map.get(config, "match_options", %{})))
      |> maybe_put_black_direction(black_direction)
      |> normalize_option_values()

    {variant, options}
  end

  defp base_match_options("toc"), do: Map.merge(@toc_default_options, @default_match_options)
  defp base_match_options(_variant_id), do: @default_match_options

  defp apply_black_direction(variant, direction) when direction in ["toward_1", :toward_1] do
    case movement_mode(variant) do
      :parallel -> Map.put(variant, :orientation, :parallel_toward_1)
      :contrary -> Map.put(variant, :orientation, :split_home)
    end
  end

  defp apply_black_direction(variant, direction) when direction in ["toward_24", :toward_24] do
    case movement_mode(variant) do
      :parallel -> Map.put(variant, :orientation, :parallel_toward_24)
      :contrary -> Map.put(variant, :orientation, :ascending)
    end
  end

  defp apply_black_direction(variant, _direction), do: variant

  defp movement_mode(%{movement_mode: mode}) when mode in [:parallel, :contrary], do: mode
  defp movement_mode(%{orientation: :jacquet_parallel}), do: :parallel
  defp movement_mode(%{orientation: :parallel}), do: :parallel
  defp movement_mode(_variant), do: :contrary

  defp maybe_put_black_direction(options, direction) when direction in ["toward_1", :toward_1],
    do: Map.put(options, "black_direction", "toward_1")

  defp maybe_put_black_direction(options, direction) when direction in ["toward_24", :toward_24],
    do: Map.put(options, "black_direction", "toward_24")

  defp maybe_put_black_direction(options, _direction), do: options

  defp normalize_option_values(options) do
    Enum.into(options, %{}, fn
      {key, value} when is_boolean(value) -> {key, value}
      {key, value} when is_integer(value) -> {key, Integer.to_string(value)}
      {key, value} -> {key, value}
    end)
  end

  defp seed_runtime(runtime) do
    runtime
    |> Map.put(:match, %{
      is_over: false,
      score: %{white: 0, black: 0},
      length: 1,
      winner: nil,
      winner_kind: nil,
      results: [],
      options: %{}
    })
    |> Map.put(:turn_color, :white)
    |> Map.put(:turn_number, 1)
    |> Map.put(:dice, nil)
    |> Map.put(:legal_moves, [])
    |> Map.put(:history, [])
    |> Map.put(:pending_turn_decision, nil)
  end

  defp response(runtime, reward) do
    state = serialize_state(runtime)

    %{
      "state" => state,
      "reward" => reward,
      "terminal" => state["terminal"],
      "white_to_play" => state["white_to_play"],
      "legal_actions" => state["legal_actions"]
    }
  end

  defp apply_action(runtime, variant, color, %{"type" => "special", "id" => "ROLL"}) do
    ensure_phase(runtime, "roll")
    TrictracCore.roll(runtime, variant, color)
  end

  defp apply_action(runtime, variant, color, %{"type" => "special", "id" => "CONFIRM"}) do
    ensure_phase(runtime, "move")
    TrictracCore.confirm(runtime, variant, color)
  end

  defp apply_action(runtime, variant, color, %{"type" => "special", "id" => "DECISION_TENIR"}) do
    ensure_phase(runtime, "decision")
    TrictracCore.submit_turn_decision(runtime, variant, color, "tenir")
  end

  defp apply_action(runtime, variant, color, %{"type" => "special", "id" => "DECISION_SEN_ALLER"}) do
    ensure_phase(runtime, "decision")
    TrictracCore.submit_turn_decision(runtime, variant, color, "s'en aller")
  end

  defp apply_action(runtime, variant, color, %{
         "type" => "special",
         "id" => "DECISION_SUSPEND_CLASSIQUE"
       }) do
    ensure_phase(runtime, "decision")
    TrictracCore.submit_turn_decision(runtime, variant, color, "suspend_classique")
  end

  defp apply_action(runtime, variant, color, %{
         "type" => "special",
         "id" => "DECISION_SUSPEND_A_ECRIRE"
       }) do
    ensure_phase(runtime, "decision")
    TrictracCore.submit_turn_decision(runtime, variant, color, "suspend_a_ecrire")
  end

  defp apply_action(runtime, variant, color, %{"type" => "special", "id" => "DECISION_NONE"}) do
    ensure_phase(runtime, "decision")
    TrictracCore.submit_turn_decision(runtime, variant, color, "none")
  end

  defp apply_action(runtime, variant, color, %{"type" => "move"} = action) do
    ensure_phase(runtime, "move")
    TrictracCore.move(runtime, variant, color, move_payload(action))
  end

  defp apply_action(_runtime, _variant, _color, _action) do
    {:error, "Invalid action."}
  end

  defp ensure_phase(runtime, expected) do
    if phase(runtime) != expected do
      raise ArgumentError, "Invalid phase for action."
    end
  end

  defp phase(runtime) do
    cond do
      terminal?(runtime) -> "terminal"
      not is_nil(pending_turn_decision(runtime)) -> "decision"
      is_nil(runtime.dice) -> "roll"
      true -> "move"
    end
  end

  defp terminal?(runtime) do
    get_in(runtime, [:match, :is_over]) || false
  end

  defp legal_actions(runtime) do
    runtime
    |> phase()
    |> actions_for_phase(runtime)
    |> Enum.sort_by(&action_sort_key/1)
  end

  defp actions_for_phase("terminal", _runtime), do: []
  defp actions_for_phase("roll", _runtime), do: [@roll_action]

  defp actions_for_phase("move", runtime) do
    {variant, _options} =
      variant_and_options(%{
        "variant_id" => get_in(runtime, [:match, :variant_id]) || @default_variant_id,
        "black_direction" => runtime_black_direction(runtime)
      })

    move_actions =
      runtime.legal_moves
      |> Kernel.||([])
      |> Enum.map(&move_action/1)

    confirm_action =
      if confirm_available?(runtime, variant) do
        [@confirm_action]
      else
        []
      end

    move_actions ++ confirm_action
  end

  defp actions_for_phase("decision", runtime) do
    runtime
    |> pending_turn_decision()
    |> Map.get("choices", [])
    |> Enum.flat_map(fn
      "tenir" -> [@decision_tenir_action]
      "s'en aller" -> [@decision_sen_aller_action]
      "suspend_classique" -> [@decision_suspend_classique_action]
      "suspend_a_ecrire" -> [@decision_suspend_a_ecrire_action]
      "none" -> [@decision_none_action]
      _ -> []
    end)
  end

  defp move_action(move) do
    %{
      "type" => "move",
      "from" => Map.get(move, :from),
      "to" => Map.get(move, :to),
      "sequence" => Map.get(move, :sequence)
    }
  end

  defp move_payload(action) do
    payload =
      %{
        "from" => Map.get(action, "from"),
        "to" => Map.get(action, "to")
      }

    case Map.get(action, "sequence") do
      sequence when is_list(sequence) -> Map.put(payload, "sequence", sequence)
      _ -> payload
    end
  end

  defp runtime_black_direction(runtime) do
    options = get_in(runtime, [:match, :options]) || %{}
    Map.get(options, "black_direction", Map.get(options, :black_direction))
  end

  defp confirm_available?(runtime, variant) do
    case TrictracCore.confirm(runtime, variant, runtime.turn_color) do
      {:ok, _next_runtime} -> true
      {:error, _reason} -> false
    end
  end

  defp pending_turn_decision(runtime) do
    runtime.pending_turn_decision || current_pending(runtime)
  end

  defp current_pending(runtime) do
    runtime
    |> Map.get(:trictrac)
    |> case do
      nil -> nil
      trictrac -> Classique.current_pending_event(trictrac)
    end
  end

  defp normalize_action(action) when is_map(action) do
    Enum.into(action, %{}, fn {key, value} ->
      {to_string(key), normalize_action(value)}
    end)
  end

  defp normalize_action(action) when is_list(action), do: Enum.map(action, &normalize_action/1)
  defp normalize_action(action), do: action

  defp encode_runtime_term(runtime) do
    runtime
    |> :erlang.term_to_binary()
    |> Base.encode64()
  end

  defp clear_history(runtime) do
    Map.put(runtime, :history, [])
  end

  defp normalize_map(value) when is_map(value) do
    Enum.into(value, %{}, fn {key, inner} -> {to_string(key), normalize_map(inner)} end)
  end

  defp normalize_map(value) when is_list(value), do: Enum.map(value, &normalize_map/1)
  defp normalize_map(value), do: value

  # Use the signed trous delta so intermediate rewards stay white-centric.
  defp trous_reward(before_runtime, after_runtime) do
    white_before = Classique.trous_for(before_runtime.trictrac, :white)
    white_after = Classique.trous_for(after_runtime.trictrac, :white)
    black_before = Classique.trous_for(before_runtime.trictrac, :black)
    black_after = Classique.trous_for(after_runtime.trictrac, :black)
    (white_after - white_before - (black_after - black_before)) * 1.0
  end

  defp serialize_nested(value) when is_struct(value) do
    value
    |> Map.from_struct()
    |> serialize_nested()
  end

  defp serialize_nested(value) when is_map(value) do
    Enum.into(value, %{}, fn {key, inner} -> {to_string(key), serialize_nested(inner)} end)
  end

  defp serialize_nested(value) when is_atom(value) and value not in [true, false, nil],
    do: Atom.to_string(value)

  defp serialize_nested(value) when is_list(value), do: Enum.map(value, &serialize_nested/1)
  defp serialize_nested(value), do: value

  defp action_sort_key(%{"type" => "special", "id" => id}), do: {0, id}

  defp action_sort_key(%{"type" => "move"} = action) do
    {1, space_key(action["from"]), space_key(action["to"]), sequence_key(action["sequence"])}
  end

  defp action_sort_key(_action), do: {9, "unknown"}

  defp move_sort_key(move) do
    {space_key(Map.get(move, :from)), space_key(Map.get(move, :to)),
     sequence_key(Map.get(move, :sequence)), Map.get(move, :die, 0), Map.get(move, :count, 1)}
  end

  defp space_key("bar"), do: -1
  defp space_key("home"), do: 24
  defp space_key(value) when is_integer(value), do: value
  defp space_key(value), do: value

  defp sequence_key(sequence) when is_list(sequence), do: List.to_tuple(sequence)
  defp sequence_key(_sequence), do: {0, 0}
end
