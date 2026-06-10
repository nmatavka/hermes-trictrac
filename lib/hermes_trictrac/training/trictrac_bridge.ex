defmodule HermesTrictrac.Training.TrictracBridge do
  alias HermesTrictrac.Rules.{Registry, TrictracCore}
  alias HermesTrictrac.Rules.Trictrac.Classique
  alias HermesTrictrac.Rules.Trictrac.Classique.{Branches, Events, Moves}

  @default_variant_id "trictrac_classique"
  @default_match_options %{"margotEnabled" => false}
  @default_tactical_config %{
    "enabled" => true,
    "horizon_own_turns" => 3,
    "reward_weight" => 1.0,
    "heuristic_weight" => 1.0,
    "version" => "classique-tactical-v3"
  }
  @toc_default_options %{"holeTarget" => "7", "doublesMode" => "off"}
  @score_normalizer 144.0
  @dice_classes for(a <- 1..6, b <- a..6, do: {a, b, if(a == b, do: 1.0 / 36.0, else: 2.0 / 36.0)})
  @tactical_cache_table :trictrac_bridge_tactical_cache
  @step_cache_table :trictrac_bridge_step_cache
  @current_turn_leaf_cache_table :trictrac_bridge_current_turn_leaf_cache
  @stats_table :trictrac_bridge_stats
  @table_owner_process :trictrac_bridge_table_owner
  @stats_enabled_key {__MODULE__, :stats_enabled}
  @shared_max_tactical_parallelism 24
  @worker_max_tactical_parallelism 4
  @current_turn_branch_width 1
  @worker_turn_branch_width 1
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

  def stats do
    {:ok,
     %{
       "pid" => os_pid(),
       "tactical_cache_size" => ets_table_size(@tactical_cache_table),
       "step_cache_size" => ets_table_size(@step_cache_table),
       "current_turn_leaf_cache_size" => ets_table_size(@current_turn_leaf_cache_table),
       "metrics" => stats_snapshot(),
       "tactical_version" => @default_tactical_config["version"]
     }}
  end

  def shutdown do
    {:ok, %{"shutdown" => true}}
  end

  def start_daemon_table_owner do
    ensure_daemon_table_owner()
    :ok
  end

  def ensure_daemon_tables do
    start_daemon_table_owner()
    ensure_step_cache_table()
    ensure_tactical_cache_table()
    ensure_current_turn_leaf_cache_table()
    if bridge_stats_enabled?() do
      ensure_stats_table()
    end

    :ok
  end

  def rpc(request) when is_map(request) do
    request
    |> normalize_map()
    |> dispatch_rpc()
  rescue
    error in [ArgumentError, RuntimeError] ->
      %{"id" => Map.get(request, "id"), "ok" => false, "error" => Exception.message(error)}
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

    {:ok, response(runtime, 0.0, config)}
  end

  def state(state), do: state(state, %{})

  def state(%{"runtime_term" => runtime_term}, config) when is_binary(runtime_term) do
    case safe_decode_runtime_term(runtime_term) do
      {:ok, runtime} -> {:ok, response(runtime, 0.0, config)}
      :error -> {:error, "Invalid state payload."}
    end
  end

  def state(_state, _config), do: {:error, "Invalid state payload."}

  def step(state, action), do: step(state, action, %{})

  def step(state, action, config) do
    state = normalize_map(state)
    action = normalize_action(action)
    config = normalize_map(config)

    cond do
      !is_map(state) ->
        {:error, "Invalid state payload."}

      !is_map(action) ->
        {:error, "Invalid action."}

      true ->
        stats_add(:step_single_requests, 1)
        execute_step_payload(state, action, config)
    end
  end

  def step_batch(items) when is_list(items) do
    case items do
      [item] ->
        stats_add(:step_batch_singleton_requests, 1)

        case prepare_step_batch_item({item, 1}) do
          {:ok, prepared} ->
            case evaluate_step_batch_item(prepared) do
              {:ok, payload} ->
                {:ok, [%{"item_id" => prepared.item_id, "ok" => true, "result" => payload}]}

              {:error, message} ->
                {:ok, [%{"item_id" => prepared.item_id, "ok" => false, "error" => message}]}
            end

          {:error, item_id, message} ->
            {:ok, [%{"item_id" => item_id, "ok" => false, "error" => message}]}
        end

      _ ->
        {:ok, execute_step_batch(items)}
    end
  end

  def step_batch(_items), do: {:error, "Invalid step batch payload."}

  def serialize_state(runtime, config \\ %{}) do
    runtime = clear_history(runtime)
    runtime_term = encode_runtime_term(runtime)

    %{
      "runtime_term" => runtime_term,
      "runtime" => public_runtime(runtime, config, runtime_term),
      "phase" => phase(runtime),
      "terminal" => terminal?(runtime),
      "white_to_play" => runtime.turn_color == :white,
      "legal_actions" => legal_actions(runtime)
    }
  end

  def public_runtime(runtime, config \\ %{}) do
    runtime = clear_history(runtime)
    public_runtime(runtime, config, encode_runtime_term(runtime))
  end

  def public_runtime(runtime, config, runtime_term) do
    ensure_daemon_tables()

    tactical =
      if include_tactical_summary?(config) do
        tactical_tariff_summary(runtime, config, runtime_term)
      else
        nil
      end

    runtime =
      runtime
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

    runtime =
      if is_nil(tactical) do
        runtime
      else
        Map.put(runtime, :tactical_tariffs, tactical)
      end

    serialize_nested(runtime)
  end

  def decode_runtime_term(runtime_term) when is_binary(runtime_term) do
    runtime_term
    |> Base.decode64!()
    |> :erlang.binary_to_term()
  end

  defp safe_decode_runtime_term(runtime_term) when is_binary(runtime_term) do
    {:ok, decode_runtime_term(runtime_term)}
  rescue
    ArgumentError -> :error
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

  defp resolve_tactical_config(config, runtime) do
    configured = normalize_map(Map.get(normalize_map(config), "tactical_config", %{}))
    variant_id = get_in(runtime, [:match, :variant_id]) || @default_variant_id
    enabled_default = variant_id == "trictrac_classique"

    enabled =
      configured
      |> Map.get("enabled", enabled_default)
      |> truthy?()

    horizon =
      configured
      |> Map.get("horizon_own_turns", @default_tactical_config["horizon_own_turns"])
      |> to_int()
      |> clamp_int(0, 3)

    if variant_id != "trictrac_classique" do
      %{@default_tactical_config | "enabled" => false, "horizon_own_turns" => 0}
    else
      %{
        @default_tactical_config
        | "enabled" => enabled,
          "horizon_own_turns" => if(enabled, do: horizon, else: 0)
      }
    end
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

  defp response(runtime, reward, config) do
    state = serialize_state(runtime, config)

    %{
      "state" => state,
      "reward" => reward,
      "terminal" => state["terminal"],
      "white_to_play" => state["white_to_play"],
      "legal_actions" => state["legal_actions"]
    }
  end

  defp dispatch_rpc(%{"id" => id, "cmd" => "ping"}) do
    result(ping(), id)
  end

  defp dispatch_rpc(%{"id" => id, "cmd" => "new_game"} = request) do
    result(new_game(Map.get(request, "config", %{})), id)
  end

  defp dispatch_rpc(%{"id" => id, "cmd" => "state", "state" => state} = request) do
    result(state(state, Map.get(request, "config", %{})), id)
  end

  defp dispatch_rpc(%{"id" => id, "cmd" => "step", "state" => state, "action" => action} = request) do
    result(step(state, action, Map.get(request, "config", %{})), id)
  end

  defp dispatch_rpc(%{"id" => id, "cmd" => "step_batch", "items" => items}) do
    case step_batch(items) do
      {:ok, batch_items} -> result({:ok, %{"items" => batch_items}}, id)
      {:error, error} -> result({:error, error}, id)
    end
  end

  defp dispatch_rpc(%{"id" => id, "cmd" => "stats"}) do
    result(stats(), id)
  end

  defp dispatch_rpc(%{"id" => id, "cmd" => "shutdown"}) do
    result(shutdown(), id)
  end

  defp dispatch_rpc(%{"id" => id}) do
    %{"id" => id, "ok" => false, "error" => "Unknown command."}
  end

  defp dispatch_rpc(%{}) do
    %{"id" => nil, "ok" => false, "error" => "Unknown command."}
  end

  defp result({:ok, payload}, id), do: %{"id" => id, "ok" => true, "result" => payload}
  defp result({:error, message}, id), do: %{"id" => id, "ok" => false, "error" => message}

  defp execute_step_batch(items) do
    stats_add(:step_batch_requests, 1)
    stats_add(:step_batch_items, length(items))

    prepared =
      items
      |> Enum.with_index(1)
      |> Enum.map(&prepare_step_batch_item/1)

    step_cache = ensure_step_cache_table()

    {responses, miss_groups, miss_order} =
      Enum.reduce(prepared, {%{}, %{}, []}, fn
        {:error, item_id, message}, {responses, miss_groups, miss_order} ->
          response = %{"item_id" => item_id, "ok" => false, "error" => message}
          {Map.put(responses, item_id, response), miss_groups, miss_order}

        {:ok, item}, {responses, miss_groups, miss_order} ->
          key = item.cache_key

          case maybe_cached_step_response(step_cache, key) do
            {:hit, cached} ->
              response = %{"item_id" => item.item_id, "ok" => true, "result" => cached}
              {Map.put(responses, item.item_id, response), miss_groups, miss_order}

            :miss ->
              if Map.has_key?(miss_groups, key) do
                updated =
                  update_in(miss_groups, [key], fn group ->
                    %{group | item_ids: group.item_ids ++ [item.item_id]}
                  end)

                {responses, updated, miss_order}
              else
                group = %{item: item, item_ids: [item.item_id]}
                {responses, Map.put(miss_groups, key, group), miss_order ++ [key]}
              end
          end
      end)

    stats_add(:step_batch_unique_misses, length(miss_order))

    evaluated =
      miss_order
      |> Task.async_stream(
        fn key ->
          group = Map.fetch!(miss_groups, key)
          {key, evaluate_step_batch_item(group.item)}
        end,
        ordered: true,
        max_concurrency: tactical_parallelism(),
        timeout: :infinity
      )
      |> Enum.map(fn {:ok, value} -> value end)

    responses =
      Enum.reduce(evaluated, responses, fn {key, result}, acc ->
        %{item_ids: item_ids} = Map.fetch!(miss_groups, key)

        case result do
          {:ok, payload} ->
            maybe_store_step_response(step_cache, key, payload)

            Enum.reduce(item_ids, acc, fn item_id, inner ->
              Map.put(inner, item_id, %{"item_id" => item_id, "ok" => true, "result" => payload})
            end)

          {:error, message} ->
            Enum.reduce(item_ids, acc, fn item_id, inner ->
              Map.put(inner, item_id, %{"item_id" => item_id, "ok" => false, "error" => message})
            end)
        end
      end)

    Enum.map(prepared, fn
      {:error, item_id, _message} ->
        Map.fetch!(responses, item_id)

      {:ok, item} ->
        Map.fetch!(responses, item.item_id)
    end)
  end

  defp prepare_step_batch_item({item, index}) do
    item = normalize_map(item)
    item_id = item |> Map.get("item_id", index) |> to_string()
    state = Map.get(item, "state")
    action = normalize_action(Map.get(item, "action"))
    config = Map.get(item, "config", %{}) |> normalize_map()

    cond do
      !is_map(state) ->
        {:error, item_id, "Invalid state payload."}

      !is_map(action) ->
        {:error, item_id, "Invalid action."}

      true ->
        cache_key = step_cache_key(state, action, config) || {:uncacheable, item_id}

        {:ok,
         %{
           item_id: item_id,
           state: state,
           action: action,
           config: config,
           cache_key: cache_key
         }}
    end
  end

  defp evaluate_step_batch_item(item) do
    execute_step_payload(item.state, item.action, item.config)
  end

  defp execute_step_payload(%{"runtime_term" => runtime_term}, action, config) do
    {variant, _options} = variant_and_options(config)
    case safe_decode_runtime_term(runtime_term) do
      {:ok, runtime} ->
        current_color = runtime.turn_color

        with {:ok, next_runtime} <- apply_action(runtime, variant, current_color, action) do
          next_runtime = clear_history(next_runtime)
          reward = trous_reward(runtime, next_runtime)
          response_payload =
            timed_debug("step_response phase=#{phase(next_runtime)} action=#{Map.get(action, "id", "move")}", fn ->
              response(next_runtime, reward, config)
            end)

          {:ok, response_payload}
        end

      :error ->
        {:error, "Invalid state payload."}
    end
  end

  defp execute_step_payload(_state, _action, _config), do: {:error, "Invalid state payload."}

  defp ensure_step_cache_table do
    ensure_named_table(@step_cache_table, [
      :named_table,
      :public,
      read_concurrency: true,
      write_concurrency: true
    ])
  end

  defp maybe_cached_step_response(_table, {:uncacheable, _item_id}), do: :miss
  defp maybe_cached_step_response(_table, nil), do: :miss

  defp maybe_cached_step_response(table, key) do
    case named_table_operation(table, &ensure_step_cache_table/0, fn ->
           :ets.lookup(table, key)
         end) do
      [{^key, payload}] ->
        stats_add(:step_cache_hits, 1)
        {:hit, payload}

      [] ->
        stats_add(:step_cache_misses, 1)
        :miss
    end
  end

  defp maybe_store_step_response(_table, {:uncacheable, _item_id}, _payload), do: false
  defp maybe_store_step_response(_table, nil, _payload), do: false

  defp maybe_store_step_response(table, key, payload) do
    true =
      named_table_operation(table, &ensure_step_cache_table/0, fn ->
        :ets.insert(table, {key, payload})
      end)

    stats_add(:step_cache_stores, 1)
    true
  end

  defp step_cache_key(%{"runtime_term" => runtime_term}, action, config) when is_binary(runtime_term) do
    {runtime_term, deterministic_binary(action), step_cache_signature(config)}
  end

  defp step_cache_key(_state, _action, _config), do: nil

  defp step_cache_signature(config) do
    config
    |> normalize_map()
    |> Map.take(["variant_id", "match_options", "tactical_config", "include_tactical_summary"])
    |> deterministic_binary()
  end

  defp include_tactical_summary?(config) do
    config
    |> normalize_map()
    |> Map.get("include_tactical_summary", true)
    |> truthy?()
  end

  defp deterministic_binary(value) do
    :erlang.term_to_binary(value, [:deterministic])
  end

  defp ets_table_size(table_name) do
    case :ets.whereis(table_name) do
      :undefined -> 0
      table -> :ets.info(table, :size) || 0
    end
  end

  defp os_pid do
    :os.getpid() |> List.to_string()
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

  defp tactical_tariff_summary(runtime, config, runtime_term) do
    variant_id = get_in(runtime, [:match, :variant_id]) || @default_variant_id

    if variant_id != "trictrac_classique" do
      nil
    else
      tactical = resolve_tactical_config(config, runtime)

      if !tactical["enabled"] or tactical["horizon_own_turns"] <= 0 or terminal?(runtime) do
        tactical_summary_payload(tactical, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0)
      else
        fetch_or_store_tactical_summary(runtime_term, tactical, fn ->
          {variant, _options} =
            variant_and_options(%{
              "variant_id" => variant_id,
              "black_direction" => runtime_black_direction(runtime),
              "match_options" => get_in(runtime, [:match, :options]) || %{}
            })

          build_tactical_summary(runtime, variant, tactical)
        end)
      end
    end
  end

  defp fetch_or_store_tactical_summary(runtime_term, tactical, compute) do
    table = ensure_tactical_cache_table()
    key = {runtime_term, tactical_cache_signature(tactical)}

    case named_table_operation(table, &ensure_tactical_cache_table/0, fn ->
           :ets.lookup(table, key)
         end) do
      [{^key, summary}] ->
        stats_add(:tactical_cache_hits, 1)
        summary

      [] ->
        stats_add(:tactical_cache_misses, 1)
        summary = compute.()

        true =
          named_table_operation(table, &ensure_tactical_cache_table/0, fn ->
            :ets.insert(table, {key, summary})
          end)

        summary
    end
  end

  defp tactical_cache_signature(tactical) do
    {
      tactical["enabled"],
      tactical["horizon_own_turns"],
      tactical["version"]
    }
  end

  defp ensure_tactical_cache_table do
    ensure_named_table(@tactical_cache_table, [
      :named_table,
      :public,
      read_concurrency: true,
      write_concurrency: true
    ])
  end

  defp ensure_current_turn_leaf_cache_table do
    ensure_named_table(@current_turn_leaf_cache_table, [
      :named_table,
      :public,
      read_concurrency: true,
      write_concurrency: true
    ])
  end

  defp ensure_stats_table do
    ensure_named_table(@stats_table, [
      :named_table,
      :public,
      read_concurrency: true,
      write_concurrency: true
    ])
  end

  defp ensure_named_table(name, options) do
    owner = ensure_daemon_table_owner()

    case :ets.whereis(name) do
      :undefined ->
        ensure_named_table_via_owner(owner, name, options)
        name

      _table ->
        name
    end
  end

  defp ensure_daemon_table_owner do
    case Process.whereis(@table_owner_process) do
      nil ->
        start_daemon_table_owner_process()

      pid ->
        pid
    end
  end

  defp start_daemon_table_owner_process do
    pid = spawn(fn -> daemon_table_owner_loop() end)

    try do
      true = Process.register(pid, @table_owner_process)
      bootstrap_daemon_tables(pid)
      pid
    rescue
      ArgumentError ->
        Process.exit(pid, :kill)
        wait_for_daemon_table_owner(50)
    end
  end

  defp bootstrap_daemon_tables(pid) do
    ref = make_ref()
    send(pid, {:bootstrap_tables, self(), ref})

    receive do
      {:bridge_tables_ready, ^ref} -> :ok
    after
      5_000 -> raise ArgumentError, "Bridge table owner did not acknowledge bootstrap."
    end
  end

  defp wait_for_daemon_table_owner(0) do
    raise ArgumentError, "Bridge table owner did not become visible after concurrent start."
  end

  defp wait_for_daemon_table_owner(attempts_left) do
    case Process.whereis(@table_owner_process) do
      nil ->
        Process.sleep(1)
        wait_for_daemon_table_owner(attempts_left - 1)

      pid ->
        pid
    end
  end

  defp ensure_named_table_via_owner(owner, name, options) do
    ref = make_ref()
    send(owner, {:ensure_table, self(), ref, name, options})

    receive do
      {:table_ready, ^ref, ^name} -> :ok
    after
      5_000 -> raise ArgumentError, "Bridge table owner did not acknowledge table creation."
    end
  end

  defp daemon_table_owner_loop do
    receive do
      {:bootstrap_tables, caller, ref} ->
        Enum.each(named_table_specs(), &ensure_owned_named_table/1)
        send(caller, {:bridge_tables_ready, ref})
        daemon_table_owner_loop()

      {:ensure_table, caller, ref, name, options} ->
        ensure_owned_named_table({name, options})
        send(caller, {:table_ready, ref, name})
        daemon_table_owner_loop()
    end
  end

  defp named_table_specs do
    base_specs = [
      {@step_cache_table,
       [:named_table, :public, read_concurrency: true, write_concurrency: true]},
      {@tactical_cache_table,
       [:named_table, :public, read_concurrency: true, write_concurrency: true]},
      {@current_turn_leaf_cache_table,
       [:named_table, :public, read_concurrency: true, write_concurrency: true]}
    ]

    if bridge_stats_enabled?() do
      base_specs ++
        [
          {@stats_table,
           [:named_table, :public, read_concurrency: true, write_concurrency: true]}
        ]
    else
      base_specs
    end
  end

  defp ensure_owned_named_table({name, options}) do
    case :ets.whereis(name) do
      :undefined ->
        :ets.new(name, options)
        :ok

      _table ->
        :ok
    end
  end

  defp named_table_operation(_table_name, ensure_fun, fun) do
    ensure_fun.()
    fun.()
  rescue
    ArgumentError ->
      ensure_fun.()
      fun.()
  end

  defp stats_add(metric, delta) when is_atom(metric) and is_integer(delta) do
    if !bridge_stats_enabled?() do
      :ok
    else
      table = ensure_stats_table()

      named_table_operation(table, &ensure_stats_table/0, fn ->
        :ets.update_counter(table, metric, {2, delta}, {metric, 0})
      end)

      :ok
    end
  end

  defp bridge_stats_enabled? do
    case :persistent_term.get(@stats_enabled_key, :unset) do
      :unset ->
        enabled = resolve_bridge_stats_enabled()
        :persistent_term.put(@stats_enabled_key, enabled)
        enabled

      enabled ->
        enabled
    end
  end

  defp resolve_bridge_stats_enabled do
    case System.get_env("TRICTRAC_ZERO_BRIDGE_COLLECT_STATS") do
      nil ->
        System.get_env("MIX_ENV") == "test"

      value ->
        normalized =
          value
          |> String.trim()
          |> String.downcase()

        normalized not in ["0", "false", "off", "no"]
    end
  end

  defp stats_snapshot do
    if !bridge_stats_enabled?() do
      %{}
    else
      table = ensure_stats_table()

      for metric <- [
            :step_batch_requests,
            :step_batch_items,
            :step_batch_unique_misses,
            :step_batch_singleton_requests,
            :step_single_requests,
            :step_cache_hits,
            :step_cache_misses,
            :step_cache_stores,
            :tactical_cache_hits,
            :tactical_cache_misses,
            :current_turn_leaf_cache_hits,
            :current_turn_leaf_cache_misses,
            :tactical_horizons_white_count,
            :tactical_horizons_white_ms,
            :tactical_horizons_black_count,
            :tactical_horizons_black_ms,
            :projected_roll_runtime_count,
            :projected_roll_runtime_ms,
            :current_turn_best_leaf_count,
            :current_turn_best_leaf_ms,
            :best_decision_runtime_count,
            :best_decision_runtime_ms
          ],
          into: %{} do
        value =
          case named_table_operation(table, &ensure_stats_table/0, fn ->
                 :ets.lookup(table, metric)
               end) do
            [{^metric, count}] -> count
            [] -> 0
          end

        {Atom.to_string(metric), value}
      end
    end
  end

  defp build_tactical_summary(runtime, variant, tactical) do
    with_request_tactical_context(fn context ->
      {white_h1, white_h2, white_h3} =
        profile_metric(:tactical_horizons_white, fn ->
          timed_debug("tactical_horizons color=white phase=#{phase(runtime)} horizon=#{tactical["horizon_own_turns"]}", fn ->
            tactical_horizons(runtime, variant, :white, tactical, context)
          end)
        end)

      {black_h1, black_h2, black_h3} =
        profile_metric(:tactical_horizons_black, fn ->
          timed_debug("tactical_horizons color=black phase=#{phase(runtime)} horizon=#{tactical["horizon_own_turns"]}", fn ->
            tactical_horizons(runtime, variant, :black, tactical, context)
          end)
        end)

      tactical_summary_payload(
        tactical,
        white_h1,
        white_h2,
        white_h3,
        black_h1,
        black_h2,
        black_h3
      )
    end)
  end

  defp with_request_tactical_context(fun) do
    table =
      :ets.new(:trictrac_bridge_request_tactical_cache, [
        :set,
        :public,
        read_concurrency: true,
        write_concurrency: true
      ])
    context = %{memo: table, async_depth: 0}

    try do
      fun.(context)
    after
      :ets.delete(table)
    end
  end

  defp tactical_horizons(runtime, variant, color, tactical, context) do
    horizon = tactical["horizon_own_turns"]

    values =
      1..3
      |> Enum.map(fn depth ->
        if depth <= horizon do
          expected_own_turn_value(runtime, variant, color, depth, context)
        else
          0.0
        end
      end)

    List.to_tuple(values)
  end

  defp expected_own_turn_value(_runtime, _variant, _color, depth, _context) when depth <= 0,
    do: 0.0

  defp expected_own_turn_value(runtime, variant, color, depth, context) do
    if terminal?(runtime) do
      0.0
    else
      memoized(context, {:own_turn_value, runtime, color, depth}, fn ->
        actor = tactical_actor_color(runtime)
        current_phase = phase(runtime)

        cond do
          actor != color and depth == 1 ->
            0.0

          actor == color and current_phase == "move" and depth == 1 ->
            current_step_value(runtime, variant, color, context)

          current_phase == "roll" and depth == 1 ->
            0.0

          true ->
            next_depth =
              cond do
                actor != color -> depth
                current_phase == "decision" -> depth
                true -> depth - 1
              end

            projected_runtime = projected_post_turn_runtime(runtime, variant, actor, context)
            expected_own_turn_value(projected_runtime, variant, color, next_depth, context)
        end
      end)
    end
  end

  defp projected_post_turn_runtime(runtime, variant, actor, context) do
    if terminal?(runtime) do
      runtime
    else
      memoized(context, {:projected_post_turn_runtime, runtime, actor}, fn ->
        case phase(runtime) do
          "roll" ->
            projected_roll_runtime(runtime, variant, actor, context)

          "move" ->
            best_completed_turn_runtime(runtime, variant, actor, context)

          "decision" ->
            best_decision_runtime(runtime, variant, actor, context)

          _ ->
            runtime
        end
      end)
    end
  end

  defp current_step_value(runtime, variant, color, context) do
    memoized(context, {:current_step_value, runtime, color}, fn ->
      turn = runtime.trictrac.turn || %{}
      start_board = Map.get(turn, :start_board, runtime.board)
      full_dice = Map.get(turn, :dice, runtime.dice)
      score_context =
        turn_score_context(start_board, variant, color, full_dice, runtime.trictrac, context)
      moves_left = Map.get(runtime.dice || %{}, :moves_left, [])
      moves_played = Map.get(runtime.dice || %{}, :moves_played, [])

      baseline_value =
        turn_net_tariff_points(score_context, runtime.board)

      moves =
        runtime
        |> Moves.legal_moves(variant, color)
        |> Enum.uniq_by(fn move ->
          {move.from, move.to, move.die, Map.get(move, :dice_used), Map.get(move, :via),
           Map.get(move, :sequence)}
        end)

      cond do
        moves_played == [] ->
          0.0

        moves_left == [] ->
          baseline_value

        moves == [] ->
          baseline_value

        true ->
          {best_value, _used_count, _sort_key} =
            Enum.reduce(moves, {baseline_value, 0, nil}, fn move, best ->
              used = Map.get(move, :dice_used, [move.die])
              next_board = Moves.apply_step_move(runtime.board, color, move)

              value =
                turn_net_tariff_points(score_context, next_board)

              choose_better_step_value(best, {value, length(used), move_sort_key(move)})
            end)

          best_value
      end
    end)
  end

  defp projected_roll_runtime(runtime, variant, color, context) do
    profile_metric(:projected_roll_runtime, fn ->
      runtime
      |> dice_class_results(context, fn {a, b, weight}, child_context ->
        rolled_runtime = runtime_for_dice(runtime, variant, color, dice_class(a, b), child_context)
        value = current_turn_value(rolled_runtime, variant, color, child_context)
        projected_runtime = current_turn_completed_runtime(rolled_runtime, variant, color, child_context)
        {weight * value, {value, weight, runtime_sort_key(projected_runtime)}, projected_runtime}
      end)
      |> Enum.reduce(nil, fn {score, sort_key, projected_runtime}, best ->
        choose_better_projection(best, {score, sort_key, projected_runtime})
      end)
      |> case do
        {_score, _sort_key, projected_runtime} ->
          projected_runtime
        nil -> runtime
      end
    end)
  end

  defp current_turn_best_leaf(runtime, variant, color, context) do
    memoized(context, {:current_turn_best_leaf, runtime, color}, fn ->
      fetch_or_store_current_turn_best_leaf(runtime, variant, color, fn ->
        profile_metric(:current_turn_best_leaf, fn ->
          turn = runtime.trictrac.turn || %{}
          start_board = Map.get(turn, :start_board, runtime.board)
          full_dice = Map.get(turn, :dice, runtime.dice)
          score_context =
            turn_score_context(start_board, variant, color, full_dice, runtime.trictrac, context)
          search_runtime = %{board: runtime.board, dice: runtime.dice}

          Branches.best_end_state_by(
            search_runtime,
            variant,
            color,
            fn leaf_runtime, _played ->
              value =
                turn_net_tariff_points(score_context, leaf_runtime.board)

              next_runtime = Map.put(leaf_runtime, :legal_moves, [])

              {value, runtime_sort_key(next_runtime)}
            end,
            canonical_dice_for_memo: true,
            max_branch_moves: current_turn_branch_width(),
            parallel_root_move_ranking: current_turn_root_parallelism(),
            move_primary_ranker: fn move ->
              move
              |> Map.get(:dice_used, [move.die])
              |> length()
            end,
            move_ranker: fn current_runtime, move ->
              next_board = Moves.apply_step_move(current_runtime.board, color, move)
              turn_net_tariff_points(score_context, next_board)
            end
          )
        end)
      end)
    end)
  end

  defp current_turn_value(runtime, variant, color, context) do
    memoized(context, {:current_turn_value, runtime, color}, fn ->
      case current_turn_best_leaf(runtime, variant, color, context) do
        %{score: value} -> value
        nil -> 0.0
      end
    end)
  end

  defp current_turn_projected_runtime(runtime, variant, color, context) do
    memoized(context, {:current_turn_projected_runtime, runtime, color}, fn ->
      case current_turn_best_leaf(runtime, variant, color, context) do
        %{board: leaf_board, dice: leaf_dice} ->
          runtime
          |> Map.put(:board, leaf_board)
          |> Map.put(:dice, leaf_dice)
          |> Map.put(:legal_moves, [])

        nil ->
          runtime
      end
    end)
  end

  defp current_turn_completed_runtime(runtime, variant, color, context) do
    memoized(context, {:current_turn_completed_runtime, runtime, color}, fn ->
      projected_runtime = current_turn_projected_runtime(runtime, variant, color, context)

      case TrictracCore.confirm(projected_runtime, variant, color) do
        {:ok, confirmed_runtime} ->
          if phase(confirmed_runtime) == "decision" do
            best_decision_runtime(
              confirmed_runtime,
              variant,
              tactical_actor_color(confirmed_runtime),
              context
            )
          else
            confirmed_runtime
          end

        {:error, _reason} ->
          projected_runtime
      end
    end)
  end

  defp best_completed_turn_runtime(runtime, variant, color, context) do
    memoized(context, {:best_completed_turn_runtime, runtime, color}, fn ->
      current_turn_completed_runtime(runtime, variant, color, context)
    end)
  end

  defp best_decision_runtime(runtime, variant, color, context) do
    memoized(context, {:best_decision_runtime, runtime, color}, fn ->
      profile_metric(:best_decision_runtime, fn ->
        case actions_for_phase("decision", runtime) do
          [action] ->
            case apply_action(runtime, variant, color, action) do
              {:ok, next_runtime} -> next_runtime
              {:error, _reason} -> runtime
            end

          actions ->
            actions
            |> Enum.map(fn action ->
              case apply_action(runtime, variant, color, action) do
                {:ok, next_runtime} ->
                  value = expected_own_turn_value(next_runtime, variant, color, 1, context)
                  {value, {action_sort_key(action), runtime_sort_key(next_runtime)}, next_runtime}

                {:error, _reason} ->
                  nil
              end
            end)
            |> Enum.reject(&is_nil/1)
            |> Enum.reduce(nil, fn candidate, best -> choose_better_projection(best, candidate) end)
            |> case do
              {_value, _sort_key, next_runtime} -> next_runtime
              nil -> runtime
            end
        end
      end)
    end)
  end

  defp current_turn_branch_width do
    if worker_bridge_mode?() do
      @worker_turn_branch_width
    else
      @current_turn_branch_width
    end
  end

  defp current_turn_root_parallelism do
    if worker_bridge_mode?() do
      1
    else
      min(4, tactical_parallelism())
    end
  end

  defp worker_bridge_mode? do
    System.get_env("TRICTRAC_ZERO_BRIDGE_MODE") == "worker"
  end

  defp choose_better_projection(nil, candidate), do: candidate

  defp choose_better_projection({best_value, best_sort_key, _} = best, {value, sort_key, _} = candidate) do
    cond do
      value > best_value -> candidate
      value < best_value -> best
      sort_key < best_sort_key -> candidate
      true -> best
    end
  end

  defp choose_better_step_value({best_value, best_used, best_sort_key} = best, {value, used, sort_key} = candidate) do
    cond do
      value > best_value -> candidate
      value < best_value -> best
      used > best_used -> candidate
      used < best_used -> best
      is_nil(best_sort_key) -> candidate
      sort_key < best_sort_key -> candidate
      true -> best
    end
  end

  defp dice_class_results(_runtime, context, fun) do
    if context.async_depth == 0 do
      child_context = %{context | async_depth: 1}

      @dice_classes
      |> Task.async_stream(
        fn dice_class -> fun.(dice_class, child_context) end,
        ordered: true,
        max_concurrency: tactical_parallelism(),
        timeout: :infinity
      )
      |> Enum.map(fn {:ok, result} -> result end)
    else
      Enum.map(@dice_classes, fn dice_class -> fun.(dice_class, context) end)
    end
  end

  defp tactical_parallelism do
    schedulers = max(System.schedulers_online(), 1)

    cap =
      if worker_bridge_mode?() do
        @worker_max_tactical_parallelism
      else
        @shared_max_tactical_parallelism
      end

    min(cap, schedulers)
  end

  defp runtime_for_dice(runtime, variant, color, dice, context) do
    memoized(context, {:runtime_for_dice, runtime, color, dice}, fn ->
      trictrac =
        runtime.trictrac
        |> Classique.begin_turn(runtime.board, variant, color, dice)

      runtime =
        runtime
        |> Map.put(:turn_moves, [])
        |> put_in([:variant_state, :last_roll_double], Enum.uniq(dice.values) |> length() == 1)
        |> Map.put(:dice, dice)
        |> Map.put(:trictrac, trictrac)
        |> Map.put(:pending_turn_decision, nil)
        |> clear_history()

      Map.put(runtime, :legal_moves, Classique.legal_moves(runtime, variant, color))
    end)
  end

  defp tactical_actor_color(runtime) do
    case pending_turn_decision(runtime) do
      %{"actorColor" => actor_color} -> normalize_color_atom(actor_color)
      _ -> normalize_color_atom(runtime.turn_color)
    end
  end

  defp normalize_color_atom(color) when color in [:white, :black], do: color
  defp normalize_color_atom("white"), do: :white
  defp normalize_color_atom("black"), do: :black
  defp normalize_color_atom(_color), do: :white

  defp runtime_sort_key(runtime) do
    runtime
    |> canonicalize_runtime_term_payload()
    |> Map.put(:legal_moves, [])
    |> :erlang.term_to_binary([:deterministic])
  end


  defp canonicalize_runtime_dice(%{dice: dice} = runtime) when is_map(dice) do
    Map.put(runtime, :dice, canonicalize_dice(dice))
  end

  defp canonicalize_runtime_dice(runtime), do: runtime

  defp canonicalize_runtime_legal_moves(%{legal_moves: moves} = runtime) when is_list(moves) do
    Map.put(runtime, :legal_moves, Enum.sort_by(moves, &move_sort_key/1))
  end

  defp canonicalize_runtime_legal_moves(runtime), do: runtime

  defp canonicalize_runtime_term_payload(runtime) do
    runtime
    |> clear_history()
    |> canonicalize_runtime_dice()
    |> canonicalize_runtime_legal_moves()
  end

  defp canonicalize_dice(dice) do
    dice
    |> Map.update(:values, [], &canonicalize_dice_values/1)
    |> Map.update(:moves, [], &canonicalize_dice_values/1)
    |> Map.update(:moves_left, [], &canonicalize_dice_values/1)
    |> Map.update(:moves_played, [], &canonicalize_dice_values/1)
  end

  defp canonicalize_dice_values(values) when is_list(values), do: Enum.sort(values)
  defp canonicalize_dice_values(value), do: value

  defp memoized(%{memo: table}, key, fun) do
    case :ets.lookup(table, key) do
      [{^key, value}] ->
        value

      [] ->
        value = fun.()
        true = :ets.insert(table, {key, value})
        value
    end
  end

  defp fetch_or_store_current_turn_best_leaf(runtime, variant, color, compute) do
    key = current_turn_leaf_cache_key(runtime, variant, color)

    try do
      with_current_turn_leaf_cache_retry(fn table ->
        case :ets.lookup(table, key) do
          [{^key, leaf}] ->
            stats_add(:current_turn_leaf_cache_hits, 1)
            leaf

          [] ->
            stats_add(:current_turn_leaf_cache_misses, 1)
            leaf = compute.()
            true = :ets.insert(table, {key, leaf})
            leaf
        end
      end)
    rescue
      ArgumentError ->
        compute.()
    end
  end

  defp current_turn_leaf_cache_key(runtime, variant, color) do
    turn = get_in(runtime, [:trictrac, :turn]) || %{}
    trictrac = Map.get(runtime, :trictrac) || %{}

    {
      color,
      current_turn_leaf_variant_key(variant),
      Map.get(runtime, :board),
      canonicalize_dice(Map.get(runtime, :dice, %{})),
      Map.get(turn, :start_board),
      canonicalize_dice(Map.get(turn, :dice, %{})),
      scoring_leaf_trictrac_key(trictrac)
    }
  end

  defp current_turn_leaf_variant_key(variant) do
    {
      Map.get(variant, :id),
      Map.get(variant, :orientation),
      Map.get(variant, :movement_mode)
    }
  end

  defp scoring_leaf_trictrac_key(trictrac) do
    {
      Map.get(trictrac, :opening),
      get_in(trictrac, [:options, "margotEnabled"]) || false,
      Map.get(trictrac, :pending_impuissance_by_type, %{white: 0, black: 0}),
      Map.get(trictrac, :pile_misere_pending_by_type, %{white: false, black: false})
    }
  end


  defp with_current_turn_leaf_cache_retry(fun, attempts \\ 2)

  defp with_current_turn_leaf_cache_retry(fun, attempts) when attempts > 0 do
    table = ensure_current_turn_leaf_cache_table()
    fun.(table)
  rescue
    ArgumentError ->
      if attempts == 1 do
        reraise ArgumentError, __STACKTRACE__
      else
        with_current_turn_leaf_cache_retry(fun, attempts - 1)
      end
  end

  defp timed_debug(label, fun) do
    if System.get_env("TRICTRAC_ZERO_BRIDGE_DEBUG_TIMINGS") == "1" do
      started = System.monotonic_time()
      result = fun.()
      elapsed_ms = System.convert_time_unit(System.monotonic_time() - started, :native, :millisecond)
      IO.puts(:stderr, "[trictrac-bridge] #{label} elapsed_ms=#{elapsed_ms}")
      result
    else
      fun.()
    end
  end

  defp profile_metric(metric, fun) do
    started = System.monotonic_time()
    result = fun.()
    elapsed_ms = System.convert_time_unit(System.monotonic_time() - started, :native, :millisecond)
    stats_add(:"#{metric}_count", 1)
    stats_add(:"#{metric}_ms", elapsed_ms)
    result
  end

  defp tactical_summary_payload(
         tactical,
         white_h1,
         white_h2,
         white_h3,
         black_h1,
         black_h2,
         black_h3
       ) do
    %{
      "enabled" => tactical["enabled"],
      "horizon_own_turns" => tactical["horizon_own_turns"],
      "white" => %{
        "h1" => normalize_tariff_value(white_h1),
        "h2" => normalize_tariff_value(white_h2),
        "h3" => normalize_tariff_value(white_h3)
      },
      "black" => %{
        "h1" => normalize_tariff_value(black_h1),
        "h2" => normalize_tariff_value(black_h2),
        "h3" => normalize_tariff_value(black_h3)
      }
    }
  end

  defp normalize_tariff_value(value), do: value / @score_normalizer

  defp dice_class(a, b) do
    moves = if(a == b, do: [a, a, a, a], else: [a, b])
    %{values: [a, b], moves: moves, moves_left: moves, moves_played: []}
  end

  defp turn_score_context(start_board, variant, color, dice, trictrac, context) do
    memoized(context, {:turn_score_context, start_board, variant, color, dice, trictrac}, fn ->
      %{
        start_board: start_board,
        variant: variant,
        color: color,
        dice: dice,
        trictrac: trictrac,
        branches_info: Branches.best_end_branches(start_board, variant, color, dice)
      }
    end)
  end

  defp turn_net_tariff_points(
         %{start_board: start_board, variant: variant, color: color, dice: dice, trictrac: trictrac,
           branches_info: branches_info},
         end_board
       ) do
    start_board
    |> Events.detect_turn_events(end_board, variant, color, dice, trictrac,
      branches_info: branches_info
    )
    |> Map.get(:events, [])
    |> Enum.reduce(0.0, fn event, total ->
      points = Map.get(event, :points, 0)
      beneficiary = Map.get(event, :beneficiary)
      total + if(beneficiary == color, do: points, else: -points)
    end)
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
    |> canonicalize_runtime_term_payload()
    |> :erlang.term_to_binary([:deterministic])
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

  defp truthy?(value) when value in [true, "true", "TRUE", "on", "ON", "yes", "YES", 1, "1"],
    do: true

  defp truthy?(value) when value in [false, "false", "FALSE", "off", "OFF", "no", "NO", 0, "0"],
    do: false

  defp truthy?(value), do: !!value

  defp to_int(value) when is_integer(value), do: value
  defp to_int(value) when is_float(value), do: trunc(value)
  defp to_int(value) when is_binary(value), do: String.to_integer(value)
  defp to_int(_value), do: 0

  defp clamp_int(value, low, high), do: value |> max(low) |> min(high)
end
