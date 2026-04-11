defmodule HermesTrictrac.GameServer do
  use GenServer

  alias HermesTrictrac.GameSnapshot
  alias HermesTrictrac.Rules.Engine
  alias HermesTrictrac.Training.TrictracBridge

  require Logger

  @call_timeout 120_000
  @trictrac_bot "trictrac_zero"
  @backgammon_bot "backgammon_ai"
  @trictrac_bot_variants [
    "trictrac_classique",
    "trictrac_aecrire",
    "trictrac_combine",
    "toc",
    "toccategli"
  ]
  @max_bot_steps 64

  def reg(name) do
    {:via, Registry, {HermesTrictrac.GameReg, name}}
  end

  def start(name, variant \\ "backgammon") do
    spec = %{
      id: {__MODULE__, name},
      start: {__MODULE__, :start_link, [name, variant]},
      restart: :permanent,
      type: :worker
    }

    HermesTrictrac.GameSup.start_child(spec)
  end

  def start_link(name, variant) do
    GenServer.start_link(__MODULE__, {name, variant}, name: reg(name))
  end

  def join(name, user, client_id, variant \\ "backgammon", opts \\ %{}) do
    GenServer.call(reg(name), {:join, user, client_id, variant, opts}, @call_timeout)
  end

  def move(name, move, user, client_id) do
    GenServer.call(reg(name), {:move, move, user, client_id}, @call_timeout)
  end

  def roll(name, user, client_id) do
    GenServer.call(reg(name), {:roll, user, client_id}, @call_timeout)
  end

  def undo(name, user, client_id) do
    GenServer.call(reg(name), {:undo, user, client_id}, @call_timeout)
  end

  def confirm(name, user, client_id) do
    GenServer.call(reg(name), {:confirm, user, client_id}, @call_timeout)
  end

  def submit_match_options(name, options, user, client_id) do
    GenServer.call(reg(name), {:submit_match_options, options, user, client_id}, @call_timeout)
  end

  def submit_turn_decision(name, decision, user, client_id) do
    GenServer.call(reg(name), {:submit_turn_decision, decision, user, client_id}, @call_timeout)
  end

  def resign(name, user, client_id) do
    GenServer.call(reg(name), {:resign, user, client_id}, @call_timeout)
  end

  def chat(name, chat, user) do
    GenServer.call(reg(name), {:chat, chat, user}, @call_timeout)
  end

  def peek(name) do
    GenServer.call(reg(name), :peek, @call_timeout)
  end

  def reset(name, _user, _client_id) do
    GenServer.call(reg(name), :reset, @call_timeout)
  end

  def init({name, variant}) do
    engine = Engine.new(name, variant)
    {:ok, %{name: name, chat: [], engine: engine, bot: nil}}
  end

  def handle_call({:join, user, client_id, requested_variant, opts}, _from, state) do
    with :ok <- ensure_variant_match(state.engine, requested_variant, state.name),
         {:ok, requested_bot} <- normalize_requested_bot(opts, state.engine.variant.id),
         {:ok, engine, player} <-
           normalize_engine_join(Engine.join(state.engine, user, client_id)),
         {:ok, updated} <- maybe_configure_bot(%{state | engine: engine}, player, requested_bot),
         {:ok, updated} <- maybe_run_bot_turns(updated, strict: not is_nil(requested_bot)) do
      persist(updated)
      {:reply, {:ok, %{game: snapshot(updated), player: player}}, updated}
    else
      {:error, msg} ->
        {:reply, {:error, msg}, state}
    end
  end

  def handle_call({:move, move, user, client_id}, _from, state) do
    proxy(state, Engine.move(state.engine, move, user, client_id))
  end

  def handle_call({:roll, user, client_id}, _from, state) do
    proxy(state, Engine.roll(state.engine, user, client_id))
  end

  def handle_call({:undo, user, client_id}, _from, state) do
    proxy(state, Engine.undo(state.engine, user, client_id))
  end

  def handle_call({:confirm, user, client_id}, _from, state) do
    proxy(state, Engine.confirm(state.engine, user, client_id))
  end

  def handle_call({:submit_match_options, options, user, client_id}, _from, state) do
    proxy(state, Engine.submit_match_options(state.engine, options, user, client_id))
  end

  def handle_call({:submit_turn_decision, decision, user, client_id}, _from, state) do
    proxy(state, Engine.submit_turn_decision(state.engine, decision, user, client_id))
  end

  def handle_call({:resign, user, client_id}, _from, state) do
    proxy(state, Engine.resign(state.engine, user, client_id))
  end

  def handle_call({:chat, chat, _user}, _from, state) do
    updated = %{state | chat: state.chat ++ [chat]}
    persist(updated)
    {:reply, {:ok, snapshot(updated)}, updated}
  end

  def handle_call(:peek, _from, state) do
    {:ok, updated} = maybe_run_bot_turns(state)
    persist(updated)
    {:reply, snapshot(updated), updated}
  end

  def handle_call(:reset, _from, state) do
    if state.engine.match.is_over do
      engine = Engine.reset(state.engine)
      updated = %{state | engine: engine, chat: []}
      {:ok, updated} = maybe_run_bot_turns(updated)
      persist(updated)
      {:reply, {:ok, snapshot(updated)}, updated}
    else
      {:reply, {:error, "Reset is only available after the match is over."}, state}
    end
  end

  defp proxy(state, {:ok, engine}) do
    updated = %{state | engine: engine}
    {:ok, updated} = maybe_run_bot_turns(updated, broadcast: true)
    persist(updated)
    {:reply, {:ok, snapshot(updated)}, updated}
  end

  defp proxy(state, {:error, msg}), do: {:reply, {:error, msg}, state}

  defp snapshot(state) do
    state.engine
    |> Engine.snapshot()
    |> GameSnapshot.with_chat(state.chat)
    |> GameSnapshot.with_bot(state.bot)
  end

  defp maybe_publish_bot_progress(state, false), do: state

  defp maybe_publish_bot_progress(state, true) do
    persist(state)

    HermesTrictracWeb.Endpoint.broadcast("games:#{state.name}", "update", %{game: snapshot(state)})

    state
  end

  defp persist(state) do
    HermesTrictrac.BackupAgent.put(state.name, state)
  end

  defp normalize_requested_bot(opts, variant_id) when is_map(opts) do
    case Map.get(opts, "bot", Map.get(opts, :bot)) do
      nil ->
        {:ok, nil}

      "" ->
        {:ok, nil}

      @trictrac_bot ->
        with {:ok, margot_enabled} <- normalize_requested_bot_margot(opts),
             {:ok, preset} <- bot_preset_for_variant(variant_id, margot_enabled) do
          {:ok,
           %{
             kind: @trictrac_bot,
             preset: preset,
             margot_enabled: margot_enabled
           }}
        end

      @backgammon_bot when variant_id == "backgammon" ->
        {:ok, %{kind: @backgammon_bot, preset: "backgammon", margot_enabled: false}}

      @backgammon_bot ->
        {:error, "BackgammonAI is only available for English backgammon."}

      other ->
        {:error, "Unsupported bot option: #{other}."}
    end
  end

  defp ensure_variant_match(%{variant: %{id: requested_variant}}, requested_variant, _name),
    do: :ok

  defp ensure_variant_match(%{variant: variant}, requested_variant, name) do
    requested = requested_variant || "backgammon"

    if requested == variant.id do
      :ok
    else
      {:error, "Lobby \"#{name}\" is already a #{variant.title} table."}
    end
  end

  defp normalize_engine_join({:ok, engine, player}), do: {:ok, engine, player}
  defp normalize_engine_join({:error, msg}), do: {:error, msg}

  defp maybe_configure_bot(state, _player, nil), do: {:ok, state}

  defp maybe_configure_bot(%{bot: bot} = state, _player, _requested_bot) when not is_nil(bot) do
    {:ok, state}
  end

  defp maybe_configure_bot(state, %{"color" => "white"}, requested_bot) do
    bot_module = bot_module(requested_bot.kind)

    cond do
      not bot_playable_variant?(requested_bot.kind, state.engine.variant.id) ->
        {:error, bot_unavailable_message(requested_bot.kind)}

      not valid_bot_module?(bot_module) ->
        {:error, "Configured bot is missing the required interface."}

      true ->
        case bot_ready(bot_module, requested_bot.preset) do
          :ok ->
            bot_name = bot_model_name(bot_module, requested_bot.preset)

            case Engine.join(
                   state.engine,
                   bot_name,
                   bot_client_id(requested_bot.kind, state.name)
                 ) do
              {:ok, engine, _player} ->
                {:ok,
                 %{
                   state
                   | engine: engine,
                     bot: %{
                       kind: requested_bot.kind,
                       name: bot_name,
                       color: :black,
                       client_id: bot_client_id(requested_bot.kind, state.name),
                       preset: requested_bot.preset,
                       margot_enabled: requested_bot.margot_enabled
                     }
                 }}

              {:error, msg} ->
                {:error, msg}
            end

          {:error, msg} ->
            {:error, msg}
        end
    end
  end

  defp maybe_configure_bot(_state, _player, _requested_bot) do
    {:error, "Bot opponent can only be selected when creating a new lobby as the host."}
  end

  defp maybe_run_bot_turns(state, opts \\ [])
  defp maybe_run_bot_turns(%{bot: nil} = state, _opts), do: {:ok, state}

  defp maybe_run_bot_turns(state, opts) do
    strict = Keyword.get(opts, :strict, false)
    broadcast = Keyword.get(opts, :broadcast, false)

    case run_bot_turns(state, 0, broadcast) do
      {:ok, updated} ->
        {:ok, updated}

      {:error, msg, updated} ->
        Logger.error("Frontend bot stalled: #{msg}")

        if strict do
          {:error, msg}
        else
          {:ok, updated}
        end
    end
  end

  defp run_bot_turns(state, steps, _broadcast) when steps >= @max_bot_steps do
    {:error, "Bot exceeded #{@max_bot_steps} consecutive actions.", state}
  end

  defp run_bot_turns(state, steps, broadcast) do
    case next_bot_step(state) do
      nil ->
        {:ok, state}

      {:submit_match_options, options} ->
        case Engine.submit_match_options(
               state.engine,
               options,
               state.bot.name,
               state.bot.client_id
             ) do
          {:ok, engine} ->
            state
            |> Map.put(:engine, engine)
            |> maybe_publish_bot_progress(broadcast)
            |> run_bot_turns(steps + 1, broadcast)

          {:error, msg} ->
            {:error, msg, state}
        end

      {:roll} ->
        case Engine.roll(state.engine, state.bot.name, state.bot.client_id) do
          {:ok, engine} ->
            state
            |> Map.put(:engine, engine)
            |> maybe_publish_bot_progress(broadcast)
            |> run_bot_turns(steps + 1, broadcast)

          {:error, msg} ->
            {:error, msg, state}
        end

      {:choose_action, serialized_state} ->
        case bot_choose_action(
               bot_module(state.bot.kind),
               current_bot_preset(state.bot, state.engine),
               serialized_state
             ) do
          {:ok, action} ->
            case apply_bot_action(state.engine, state.bot, action) do
              {:ok, engine} ->
                state
                |> Map.put(:engine, engine)
                |> maybe_publish_bot_progress(broadcast)
                |> run_bot_turns(steps + 1, broadcast)

              {:error, msg} ->
                {:error, msg, state}
            end

          {:error, msg} ->
            {:error, msg, state}
        end
    end
  end

  defp next_bot_step(%{bot: bot, engine: engine}) do
    responses = get_in(engine.pending_match_options || %{}, ["responses"]) || %{}
    serialized_state = maybe_serialize_bot_state(engine, bot)

    cond do
      engine.match.is_over ->
        nil

      engine.pending_match_options &&
        engine.pending_match_options["kind"] == "trictrac_margot_consent" &&
          is_nil(Map.get(responses, Atom.to_string(bot.color))) ->
        {:submit_match_options,
         %{"margotConsent" => if(bot_margot_enabled?(bot), do: "yes", else: "no")}}

      engine.pending_match_options &&
        engine.pending_match_options["kind"] == "trictrac_partie_length_consent" &&
          is_nil(Map.get(responses, Atom.to_string(bot.color))) ->
        {:submit_match_options, %{"aEcrirePartieLengthConsent" => "16"}}

      bot_playable_variant?(bot.kind, engine.variant.id) &&
          opening_roll_pending_for_bot?(engine, bot.color) ->
        {:roll}

      pending_turn_decision_for_bot?(serialized_state, bot.color) ->
        {:choose_action, serialized_state}

      bot_playable_variant?(bot.kind, engine.variant.id) &&
        engine.status == :playing &&
        no_pending_turn_decision?(serialized_state) &&
          engine.turn_color == bot.color ->
        {:choose_action, serialized_state}

      true ->
        nil
    end
  end

  defp apply_bot_action(engine, bot, %{"type" => "special", "id" => "ROLL"}) do
    Engine.roll(engine, bot.name, bot.client_id)
  end

  defp apply_bot_action(engine, bot, %{"type" => "special", "id" => "CONFIRM"}) do
    Engine.confirm(engine, bot.name, bot.client_id)
  end

  defp apply_bot_action(engine, bot, %{"type" => "special", "id" => "DECISION_TENIR"}) do
    Engine.submit_turn_decision(engine, "tenir", bot.name, bot.client_id)
  end

  defp apply_bot_action(engine, bot, %{"type" => "special", "id" => "DECISION_SEN_ALLER"}) do
    Engine.submit_turn_decision(engine, "s'en aller", bot.name, bot.client_id)
  end

  defp apply_bot_action(engine, bot, %{"type" => "special", "id" => "DECISION_SUSPEND_CLASSIQUE"}) do
    Engine.submit_turn_decision(engine, "suspend_classique", bot.name, bot.client_id)
  end

  defp apply_bot_action(engine, bot, %{"type" => "special", "id" => "DECISION_SUSPEND_A_ECRIRE"}) do
    Engine.submit_turn_decision(engine, "suspend_a_ecrire", bot.name, bot.client_id)
  end

  defp apply_bot_action(engine, bot, %{"type" => "special", "id" => "DECISION_NONE"}) do
    Engine.submit_turn_decision(engine, "none", bot.name, bot.client_id)
  end

  defp apply_bot_action(engine, bot, %{"type" => "move"} = action) do
    move =
      %{
        "from" => Map.get(action, "from"),
        "to" => Map.get(action, "to")
      }
      |> maybe_put_sequence(action)

    Engine.move(engine, move, bot.name, bot.client_id)
  end

  defp apply_bot_action(_engine, _bot, action) do
    {:error, "Unsupported bot action: #{inspect(action)}"}
  end

  defp maybe_put_sequence(move, action) do
    case Map.get(action, "sequence") do
      sequence when is_list(sequence) -> Map.put(move, "sequence", sequence)
      _ -> move
    end
  end

  defp bot_module(@trictrac_bot) do
    Application.get_env(
      :hermes_trictrac,
      :trictrac_model_bot_impl,
      HermesTrictrac.TrictracModelBot
    )
  end

  defp bot_module(@backgammon_bot) do
    Application.get_env(:hermes_trictrac, :backgammon_ai_bot_impl, HermesTrictrac.BackgammonAiBot)
  end

  defp bot_module(_kind), do: HermesTrictrac.BackgammonAiBot

  defp bot_playable_variant?(@trictrac_bot, variant_id), do: variant_id in @trictrac_bot_variants
  defp bot_playable_variant?(@backgammon_bot, "backgammon"), do: true
  defp bot_playable_variant?(_kind, _variant_id), do: false

  defp normalize_requested_bot_margot(opts) do
    case Map.get(opts, "bot_margot", Map.get(opts, :bot_margot, "no")) do
      nil -> {:ok, false}
      "" -> {:ok, false}
      false -> {:ok, false}
      true -> {:ok, true}
      "no" -> {:ok, false}
      "false" -> {:ok, false}
      "off" -> {:ok, false}
      "yes" -> {:ok, true}
      "true" -> {:ok, true}
      "on" -> {:ok, true}
      other -> {:error, "Unsupported bot Margot option: #{inspect(other)}."}
    end
  end

  defp bot_preset_for_variant("trictrac_classique", false), do: {:ok, "classique"}
  defp bot_preset_for_variant("trictrac_classique", true), do: {:ok, "classique-margot"}
  defp bot_preset_for_variant("trictrac_aecrire", false), do: {:ok, "aecrire"}
  defp bot_preset_for_variant("trictrac_aecrire", true), do: {:ok, "aecrire-margot"}
  defp bot_preset_for_variant("trictrac_combine", false), do: {:ok, "combine"}
  defp bot_preset_for_variant("trictrac_combine", true), do: {:ok, "combine-margot"}
  defp bot_preset_for_variant("toc", false), do: {:ok, "toc"}
  defp bot_preset_for_variant("toc", true), do: {:ok, "toc-margot"}
  defp bot_preset_for_variant("toccategli", false), do: {:ok, "toccategli"}
  defp bot_preset_for_variant("toccategli", true), do: {:ok, "toccategli-margot"}

  defp bot_preset_for_variant(_variant_id, _margot_enabled) do
    {:error,
     "The current model is only available for Trictrac Classique, Trictrac a ecrire, Trictrac combine, Jeu du Toc, and Toccategli."}
  end

  defp bot_unavailable_message(@trictrac_bot) do
    "The current model is only available for Trictrac Classique, Trictrac a ecrire, Trictrac combine, Jeu du Toc, and Toccategli."
  end

  defp bot_unavailable_message(@backgammon_bot),
    do: "BackgammonAI is only available for English backgammon."

  defp bot_unavailable_message(_kind), do: "Unsupported bot option."

  defp valid_bot_module?(bot_module) do
    Code.ensure_loaded?(bot_module) and
      (function_exported?(bot_module, :ready, 1) or function_exported?(bot_module, :ready, 0)) and
      (function_exported?(bot_module, :choose_action, 2) or
         function_exported?(bot_module, :choose_action, 1)) and
      (function_exported?(bot_module, :model_name, 1) or
         function_exported?(bot_module, :model_name, 0))
  end

  defp bot_ready(bot_module, preset) do
    cond do
      function_exported?(bot_module, :ready, 1) -> bot_module.ready(preset)
      function_exported?(bot_module, :ready, 0) -> bot_module.ready()
      true -> {:error, "Configured bot cannot be warmed."}
    end
  end

  defp bot_model_name(bot_module, preset) do
    cond do
      function_exported?(bot_module, :model_name, 1) -> bot_module.model_name(preset)
      function_exported?(bot_module, :model_name, 0) -> bot_module.model_name()
      true -> "Bot"
    end
  end

  defp bot_choose_action(bot_module, preset, serialized_state) do
    cond do
      function_exported?(bot_module, :choose_action, 2) ->
        bot_module.choose_action(preset, serialized_state)

      function_exported?(bot_module, :choose_action, 1) ->
        bot_module.choose_action(serialized_state)

      true ->
        {:error, "Configured bot cannot choose an action."}
    end
  end

  defp maybe_serialize_bot_state(engine, %{kind: @trictrac_bot}) do
    if bot_playable_variant?(@trictrac_bot, engine.variant.id) do
      TrictracBridge.serialize_state(Engine.runtime_view(engine))
    else
      nil
    end
  end

  defp maybe_serialize_bot_state(engine, %{kind: @backgammon_bot}) do
    if bot_playable_variant?(@backgammon_bot, engine.variant.id) do
      HermesTrictrac.BackgammonAiBot.serialize_state(Engine.runtime_view(engine), engine.variant)
    else
      nil
    end
  end

  defp maybe_serialize_bot_state(_engine, _bot), do: nil

  defp bot_margot_enabled?(bot) do
    Map.get(bot, :margot_enabled, false)
  end

  defp current_bot_preset(bot, engine) do
    case Map.get(bot, :preset) do
      nil ->
        case bot_preset_for_variant(
               engine.variant.id,
               get_in(engine.match, [:options, "margotEnabled"]) == true
             ) do
          {:ok, preset} -> preset
          {:error, _msg} -> "classique"
        end

      preset ->
        preset
    end
  end

  defp pending_turn_decision_for_bot?(serialized_state, color) when is_map(serialized_state) do
    serialized_state
    |> serialized_pending_turn_decision()
    |> case do
      %{"actorColor" => actor_color} when is_binary(actor_color) ->
        actor_color == Atom.to_string(color)

      _ ->
        false
    end
  end

  defp pending_turn_decision_for_bot?(_serialized_state, _color), do: false

  defp no_pending_turn_decision?(serialized_state) when is_map(serialized_state) do
    is_nil(serialized_pending_turn_decision(serialized_state))
  end

  defp no_pending_turn_decision?(_serialized_state), do: true

  defp serialized_pending_turn_decision(serialized_state) do
    get_in(serialized_state, ["runtime", "pending_turn_decision"])
  end

  defp opening_roll_pending_for_bot?(engine, color) do
    engine.status == :playing and
      is_nil(engine.pending_match_options) and
      is_nil(engine.turn_color) and
      is_nil(engine.dice) and
      engine.turn_number == 0 and
      is_nil(get_in(opening_roll_rolls(engine), [color]))
  end

  defp opening_roll_rolls(%{variant: %{id: id}} = engine)
       when id in [
              "backgammon",
              "trictrac_classique",
              "trictrac_aecrire",
              "trictrac_combine",
              "toc",
              "toccategli"
            ] do
    get_in(engine.runtime, [:variant_state, :opening_rolls]) || %{white: nil, black: nil}
  end

  defp opening_roll_rolls(_engine), do: %{white: 0, black: 0}

  defp bot_client_id(kind, lobby) do
    "bot:#{kind}:#{lobby}"
  end
end
