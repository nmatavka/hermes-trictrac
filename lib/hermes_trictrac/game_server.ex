defmodule HermesTrictrac.GameServer do
  use GenServer

  alias HermesTrictrac.{GameSnapshot, TableSession}
  alias HermesTrictrac.Rules.Engine
  alias HermesTrictrac.Rules.Registry, as: VariantRegistry
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
  @seat_reclaim_code "seat_reclaim_pending"

  def reg(name) do
    {:via, Elixir.Registry, {HermesTrictrac.GameReg, name}}
  end

  def start(name, variant \\ "backgammon", opts \\ %{}) do
    spec = %{
      id: {__MODULE__, name},
      start: {__MODULE__, :start_link, [name, variant, opts]},
      restart: :permanent,
      type: :worker
    }

    HermesTrictrac.GameSup.start_child(spec)
  end

  def start_link(name, variant, opts) do
    GenServer.start_link(__MODULE__, {name, variant, opts}, name: reg(name))
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

  def chat(name, chat, user, client_id) do
    GenServer.call(reg(name), {:chat, chat, user, client_id}, @call_timeout)
  end

  def peek(name) do
    GenServer.call(reg(name), :peek, @call_timeout)
  end

  def reset(name, _user, _client_id) do
    GenServer.call(reg(name), :reset, @call_timeout)
  end

  def remain_seated(name, user, client_id) do
    GenServer.call(reg(name), {:remain_seated, user, client_id}, @call_timeout)
  end

  def claim_queue_spot(name, user, client_id) do
    GenServer.call(reg(name), {:claim_queue_spot, user, client_id}, @call_timeout)
  end

  def claim_roster_slot(name, user, client_id) do
    GenServer.call(reg(name), {:claim_roster_slot, user, client_id}, @call_timeout)
  end

  def leave(name, user, client_id) do
    GenServer.call(reg(name), {:leave, user, client_id}, @call_timeout)
  end

  def viewer(name, user, client_id) do
    GenServer.call(reg(name), {:viewer, user, client_id}, @call_timeout)
  end

  def init({name, variant_id, opts}) do
    table_variant = VariantRegistry.get(variant_id)
    base_variant_id = Map.get(table_variant, :base_variant_id, table_variant.id)
    engine = Engine.new(name, base_variant_id)

    session =
      if VariantRegistry.session_variant?(variant_id) do
        {:ok, session} = TableSession.new(table_variant, opts)
        session
      end

    {:ok,
     %{
       name: name,
       chat: [],
       engine: engine,
       bot: nil,
       seat_reclaim: nil,
       table_variant: table_variant,
       session: session
     }}
  end

  def handle_call({:join, user, client_id, requested_variant, opts}, _from, state) do
    auth_id = Map.get(opts, "auth_id")

    with :ok <- ensure_variant_match(state, requested_variant, state.name),
         {:ok, requested_bot} <-
           normalize_requested_bot(opts, state.table_variant.id, state.session) do
      if reclaimable_seat(state.engine, user, client_id, auth_id, state.bot) do
        reply_with_seat_reclaim(state, user, client_id, auth_id)
      else
        join_table(state, user, client_id, requested_bot, auth_id)
      end
    else
      {:error, msg} ->
        {:reply, {:error, error_payload(msg)}, state}
    end
  end

  def handle_call({:viewer, user, client_id}, _from, state) do
    {:reply, viewer_payload(state, user, client_id), state}
  end

  def handle_call({:leave, _user, _client_id}, _from, %{session: nil} = state) do
    {:reply, :ok, state}
  end

  def handle_call({:leave, _user, client_id}, _from, state) do
    {:ok, session, _action} = TableSession.leave(state.session, client_id)
    updated = %{state | session: session}
    persist(updated)
    broadcast_snapshot(updated)
    {:reply, :ok, updated}
  end

  def handle_call({:claim_queue_spot, _user, _client_id}, _from, %{session: nil} = state) do
    {:reply, {:error, "No open queue slot is available."}, state}
  end

  def handle_call({:claim_queue_spot, user, client_id}, _from, state) do
    case TableSession.claim_queue_spot(state.session, client_id) do
      {:ok, session, _viewer, {:start_round, host_id, guest_id}} ->
        updated =
          state
          |> Map.put(:session, session)
          |> clear_seat_reclaim()
          |> start_session_round(host_id, guest_id)

        persist(updated)
        {:reply, {:ok, snapshot_for(updated, user, client_id)}, updated}

      {:ok, session, _viewer, nil} ->
        updated = %{state | session: session}
        persist(updated)
        {:reply, {:ok, snapshot_for(updated, user, client_id)}, updated}

      {:error, msg} ->
        {:reply, {:error, msg}, state}
    end
  end

  def handle_call({:claim_roster_slot, _user, _client_id}, _from, %{session: nil} = state) do
    {:reply, {:error, "No open roster slot is available."}, state}
  end

  def handle_call({:claim_roster_slot, user, client_id}, _from, state) do
    case TableSession.claim_roster_slot(state.session, client_id) do
      {:ok, session, _viewer, {:start_round, host_id, guest_id}} ->
        updated =
          state
          |> Map.put(:session, session)
          |> clear_seat_reclaim()
          |> start_session_round(host_id, guest_id)

        persist(updated)
        {:reply, {:ok, snapshot_for(updated, user, client_id)}, updated}

      {:ok, session, _viewer, {:seat_pair, host_id, guest_id}} ->
        updated =
          state
          |> Map.put(:session, session)
          |> clear_seat_reclaim()
          |> seat_session_pair(host_id, guest_id)

        persist(updated)
        {:reply, {:ok, snapshot_for(updated, user, client_id)}, updated}

      {:ok, session, _viewer, {:seat_pair, host_id, guest_id, metadata}} ->
        updated =
          state
          |> Map.put(:session, session)
          |> clear_seat_reclaim()
          |> seat_session_pair(host_id, guest_id, metadata)

        persist(updated)
        {:reply, {:ok, snapshot_for(updated, user, client_id)}, updated}

      {:ok, session, _viewer, nil} ->
        updated = %{state | session: session}
        persist(updated)
        {:reply, {:ok, snapshot_for(updated, user, client_id)}, updated}

      {:error, msg} ->
        {:reply, {:error, msg}, state}
    end
  end

  def handle_call({:move, move, user, client_id}, _from, state) do
    with :ok <- ensure_active_viewer(state, user, client_id) do
      proxy(state, Engine.move(state.engine, move, user, client_id))
    else
      {:error, msg} -> {:reply, {:error, msg}, state}
    end
  end

  def handle_call({:roll, user, client_id}, _from, %{session: session} = state)
      when not is_nil(session) do
    cond do
      TableSession.pending_order_draw?(session) ->
        case TableSession.roll_for_order(session, client_id) do
          {:ok, next_session, nil} ->
            updated = %{state | session: next_session}
            persist(updated)
            {:reply, {:ok, snapshot_for(updated, user, client_id)}, updated}

          {:error, msg} ->
            {:reply, {:error, msg}, state}
        end

      true ->
        with :ok <- ensure_active_viewer(state, user, client_id) do
          proxy(state, Engine.roll(state.engine, user, client_id))
        else
          {:error, msg} -> {:reply, {:error, msg}, state}
        end
    end
  end

  def handle_call({:roll, user, client_id}, _from, state) do
    with :ok <- ensure_active_viewer(state, user, client_id) do
      proxy(state, Engine.roll(state.engine, user, client_id))
    else
      {:error, msg} -> {:reply, {:error, msg}, state}
    end
  end

  def handle_call({:undo, user, client_id}, _from, state) do
    with :ok <- ensure_active_viewer(state, user, client_id) do
      proxy(state, Engine.undo(state.engine, user, client_id))
    else
      {:error, msg} -> {:reply, {:error, msg}, state}
    end
  end

  def handle_call({:confirm, user, client_id}, _from, state) do
    with :ok <- ensure_active_viewer(state, user, client_id) do
      proxy(state, Engine.confirm(state.engine, user, client_id))
    else
      {:error, msg} -> {:reply, {:error, msg}, state}
    end
  end

  def handle_call({:submit_match_options, options, user, client_id}, _from, state) do
    cond do
      state.session && TableSession.pending_match_options?(state.session) ->
        case TableSession.submit_match_options(state.session, options, client_id) do
          {:ok, session, {:start_round, host_id, guest_id}} ->
            updated =
              state
              |> Map.put(:session, session)
              |> clear_seat_reclaim()
              |> start_session_round(host_id, guest_id)

            persist(updated)
            {:reply, {:ok, snapshot_for(updated, user, client_id)}, updated}

          {:ok, session, nil} ->
            updated = %{state | session: session}
            persist(updated)
            {:reply, {:ok, snapshot_for(updated, user, client_id)}, updated}

          {:error, msg} ->
            {:reply, {:error, msg}, state}
        end

      true ->
        with :ok <- ensure_active_viewer(state, user, client_id) do
          proxy(state, Engine.submit_match_options(state.engine, options, user, client_id))
        else
          {:error, msg} -> {:reply, {:error, msg}, state}
        end
    end
  end

  def handle_call({:submit_turn_decision, decision, user, client_id}, _from, state) do
    with :ok <- ensure_active_viewer(state, user, client_id) do
      proxy(state, Engine.submit_turn_decision(state.engine, decision, user, client_id))
    else
      {:error, msg} -> {:reply, {:error, msg}, state}
    end
  end

  def handle_call({:resign, user, client_id}, _from, state) do
    with :ok <- ensure_active_viewer(state, user, client_id),
         :ok <- ensure_resign_available(state) do
      proxy(state, Engine.resign(state.engine, user, client_id))
    else
      {:error, msg} -> {:reply, {:error, msg}, state}
    end
  end

  def handle_call({:remain_seated, user, client_id}, _from, state) do
    case maybe_cancel_seat_reclaim(state, user, client_id) do
      {:ok, updated} ->
        persist(updated)
        {:reply, {:ok, snapshot_for(updated, user, client_id)}, updated}

      {:error, msg} ->
        {:reply, {:error, msg}, state}
    end
  end

  def handle_call({:chat, chat, user, client_id}, _from, state) do
    updated = %{state | chat: state.chat ++ [enrich_chat(chat, state, user, client_id)]}
    persist(updated)
    {:reply, {:ok, snapshot_for(updated, user, client_id)}, updated}
  end

  def handle_call(:peek, _from, state) do
    {:ok, updated} = maybe_run_bot_turns(state)
    persist(updated)
    {:reply, snapshot(updated), updated}
  end

  def handle_call(:reset, _from, %{session: session} = state) when not is_nil(session) do
    if session.phase == :finished do
      updated =
        state
        |> reset_session_table()
        |> clear_seat_reclaim()

      persist(updated)
      {:reply, {:ok, snapshot(updated)}, updated}
    else
      {:reply, {:error, "Reset is only available after the match is over."}, state}
    end
  end

  def handle_call(:reset, _from, state) do
    if state.engine.match.is_over do
      engine = Engine.reset(state.engine)
      updated = clear_seat_reclaim(%{state | engine: engine, chat: []})
      {:ok, updated} = maybe_run_bot_turns(updated)
      persist(updated)
      {:reply, {:ok, snapshot(updated)}, updated}
    else
      {:reply, {:error, "Reset is only available after the match is over."}, state}
    end
  end

  def handle_info({:seat_reclaim_expired, seat_key, claimant_client_id}, state) do
    case state.seat_reclaim do
      %{seat_key: ^seat_key, claimant_client_id: ^claimant_client_id} = reclaim ->
        updated =
          state
          |> reclaim_seat(reclaim)
          |> clear_seat_reclaim()

        persist(updated)
        broadcast_snapshot(updated)
        {:noreply, updated}

      _ ->
        {:noreply, state}
    end
  end

  defp proxy(state, {:ok, engine}) do
    updated =
      state
      |> Map.put(:engine, engine)
      |> maybe_advance_session()

    {:ok, updated} = maybe_run_bot_turns(updated, broadcast: true)
    persist(updated)
    {:reply, {:ok, snapshot(updated)}, updated}
  end

  defp proxy(state, {:error, msg}), do: {:reply, {:error, msg}, state}

  defp snapshot(state) do
    base_snapshot =
      state.engine
      |> Engine.snapshot()
      |> GameSnapshot.with_chat(state.chat)
      |> GameSnapshot.with_bot(state.bot)
      |> GameSnapshot.with_seat_reclaim(state.seat_reclaim)

    if state.session do
      TableSession.inject_snapshot(base_snapshot, state.session)
    else
      base_snapshot
    end
  end

  defp snapshot_for(state, user, client_id) do
    snapshot(state)
    |> GameSnapshot.with_viewer(viewer_payload(state, user, client_id))
  end

  defp viewer_payload(%{session: session} = _state, _user, client_id) when not is_nil(session) do
    TableSession.viewer(session, client_id)
  end

  defp viewer_payload(state, _user, client_id) do
    case actor_by_client_id(state.engine, client_id) do
      nil ->
        nil

      player ->
        %{
          "id" => player.id,
          "name" => player.name,
          "role" => "active",
          "seat" => if(player.color == :white, do: "host", else: "guest"),
          "seat_color" => Atom.to_string(player.color),
          "can_claim_queue_spot" => false
        }
    end
  end

  defp join_table(%{session: session} = state, user, client_id, _requested_bot, auth_id)
       when not is_nil(session) do
    join_session_table(state, user, client_id, auth_id)
  end

  defp join_table(state, user, client_id, requested_bot, auth_id) do
    case normalize_engine_join(Engine.join(state.engine, user, client_id, auth_id)) do
      {:ok, engine, player} ->
        with {:ok, cleared} <- maybe_clear_seat_reclaim(state, player),
             {:ok, updated} <-
               maybe_configure_bot(%{cleared | engine: engine}, player, requested_bot),
             {:ok, updated} <-
               maybe_prepare_bot_game(updated, user, client_id, requested_bot) do
          persist(updated)

          {:reply,
           {:ok,
            %{
              game: snapshot_for(updated, user, client_id),
              player: player,
              viewer: viewer_payload(updated, user, client_id)
            }}, updated}
        else
          {:error, msg} ->
            {:reply, {:error, error_payload(msg)}, state}
        end

      {:error, "Lobby is full."} ->
        reply_with_seat_reclaim(state, user, client_id, auth_id)

      {:error, msg} ->
        {:reply, {:error, error_payload(msg)}, state}
    end
  end

  defp join_session_table(state, user, client_id, auth_id) do
    case TableSession.join(state.session, user, client_id, auth_id) do
      {:ok, session, viewer, {:start_round, host_id, guest_id}} ->
        updated =
          state
          |> Map.put(:session, session)
          |> clear_seat_reclaim()
          |> start_session_round(host_id, guest_id)

        persist(updated)

        {:reply,
         {:ok,
          %{
            game: snapshot_for(updated, user, client_id),
            player: viewer_player(viewer),
            viewer: viewer
          }}, updated}

      {:ok, session, viewer, {:seat_pair, host_id, guest_id}} ->
        updated =
          state
          |> Map.put(:session, session)
          |> clear_seat_reclaim()
          |> seat_session_pair(host_id, guest_id)

        persist(updated)

        {:reply,
         {:ok,
          %{
            game: snapshot_for(updated, user, client_id),
            player: viewer_player(viewer),
            viewer: viewer
          }}, updated}

      {:ok, session, viewer, {:seat_pair, host_id, guest_id, metadata}} ->
        updated =
          state
          |> Map.put(:session, session)
          |> clear_seat_reclaim()
          |> seat_session_pair(host_id, guest_id, metadata)

        persist(updated)

        {:reply,
         {:ok,
          %{
            game: snapshot_for(updated, user, client_id),
            player: viewer_player(viewer),
            viewer: viewer
          }}, updated}

      {:ok, session, viewer, nil} ->
        updated = %{state | session: session}
        persist(updated)

        {:reply,
         {:ok,
          %{
            game: snapshot_for(updated, user, client_id),
            player: viewer_player(viewer),
            viewer: viewer
          }}, updated}
    end
  end

  defp viewer_player(%{"role" => "active"} = viewer) do
    %{
      "id" => viewer["id"],
      "name" => viewer["name"],
      "color" => viewer["seat_color"]
    }
  end

  defp viewer_player(_viewer), do: nil

  defp fresh_session_engine(state) do
    state.name
    |> Engine.new(state.engine.variant.id)
    |> Engine.seed_match_options(TableSession.round_options(state.session))
  end

  defp start_session_round(state, host_id, guest_id) do
    state =
      if state.session do
        %{state | session: TableSession.round_started(state.session)}
      else
        state
      end

    host_member = state.session.members[host_id]
    guest_member = state.session.members[guest_id]

    engine =
      fresh_session_engine(state)
      |> join_round_player(host_member)
      |> join_round_player(guest_member)
      |> maybe_force_session_start(state.session)

    %{state | engine: engine}
  end

  defp start_waiting_poule_round(%{session: %{active: %{host: nil}}} = state) do
    %{state | engine: fresh_session_engine(state)}
  end

  defp start_waiting_poule_round(state) do
    host_member = state.session.members[state.session.active.host]
    engine = fresh_session_engine(state) |> join_round_player(host_member)
    %{state | engine: engine}
  end

  defp seat_session_pair(state, host_id, guest_id, metadata \\ nil) do
    host_member = state.session.members[host_id]
    guest_member = state.session.members[guest_id]

    engine =
      state.engine
      |> replace_round_players(host_member, guest_member)
      |> maybe_force_session_pair_start(metadata)

    %{state | engine: engine}
  end

  defp join_round_player(engine, nil), do: engine

  defp join_round_player(engine, member) do
    {:ok, engine, _player} = Engine.join(engine, member.name, member.client_id, member.auth_id)
    engine
  end

  defp maybe_force_session_start(engine, %{kind: :multiplayer} = session) do
    Engine.force_start_turn(engine, TableSession.round_start_color(session))
  end

  defp maybe_force_session_start(engine, _session), do: engine

  defp maybe_force_session_pair_start(engine, %{start_color: color})
       when color in [:white, :black] do
    Engine.force_coup_starter(engine, color)
  end

  defp maybe_force_session_pair_start(engine, _metadata), do: engine

  defp maybe_advance_session(%{session: nil} = state), do: state

  defp maybe_advance_session(state) do
    case TableSession.advance(state.session, state.engine) do
      {:ok, session, :finished} ->
        %{state | session: session}

      {:ok, session, {:start_round, host_id, guest_id}} ->
        state
        |> Map.put(:session, session)
        |> clear_seat_reclaim()
        |> start_session_round(host_id, guest_id)

      {:ok, session, {:seat_pair, host_id, guest_id}} ->
        state
        |> Map.put(:session, session)
        |> clear_seat_reclaim()
        |> seat_session_pair(host_id, guest_id)

      {:ok, session, {:seat_pair, host_id, guest_id, metadata}} ->
        state
        |> Map.put(:session, session)
        |> clear_seat_reclaim()
        |> seat_session_pair(host_id, guest_id, metadata)

      {:ok, session, :waiting_for_queue_refill} ->
        state
        |> Map.put(:session, session)
        |> clear_seat_reclaim()
        |> start_waiting_poule_round()

      {:ok, session, nil} ->
        %{state | session: session}

      {:error, _msg} ->
        state
    end
  end

  defp reset_session_table(state) do
    {:ok, fresh_session} =
      TableSession.new(state.table_variant, session_reset_opts(state.session))

    {session, action} =
      Enum.reduce(
        TableSession.connected_competitors(state.session),
        {fresh_session, nil},
        fn member, {session_acc, _action_acc} ->
          {:ok, session_next, _viewer, action_next} =
            TableSession.join(session_acc, member.name, member.client_id, member.auth_id)

          {session_next, action_next}
        end
      )

    {session, action} =
      Enum.reduce(TableSession.connected_spectators(state.session), {session, action}, fn member,
                                                                                          {session_acc,
                                                                                           action_acc} ->
        {:ok, session_next, _viewer} =
          TableSession.add_spectator(
            session_acc,
            member.name,
            member.client_id,
            member.auth_id
          )

        {session_next, action_acc}
      end)

    base = %{state | session: session, chat: []}

    case action do
      {:start_round, host_id, guest_id} ->
        start_session_round(base, host_id, guest_id)

      {:seat_pair, host_id, guest_id} ->
        base
        |> Map.put(:engine, fresh_session_engine(base))
        |> seat_session_pair(host_id, guest_id)

      {:seat_pair, host_id, guest_id, metadata} ->
        base
        |> Map.put(:engine, fresh_session_engine(base))
        |> seat_session_pair(host_id, guest_id, metadata)

      _ ->
        %{base | engine: fresh_session_engine(base)}
    end
  end

  defp ensure_active_viewer(%{session: nil}, _user, _client_id), do: :ok

  defp ensure_active_viewer(state, user, client_id) do
    case viewer_payload(state, user, client_id) do
      %{"role" => "active"} -> :ok
      _ -> {:error, "Only an active player can do that."}
    end
  end

  defp ensure_resign_available(%{session: %{kind: :poule, style: :plucked_pot}}),
    do: {:error, "Resign is unavailable for plucked-pool tables."}

  defp ensure_resign_available(_state), do: :ok

  defp enrich_chat(chat, state, user, client_id) do
    viewer =
      viewer_payload(state, user, client_id) ||
        %{"id" => nil, "name" => user, "role" => "spectator"}

    text =
      get_in(chat, ["data", "text"]) ||
        get_in(chat, [:data, :text]) ||
        Map.get(chat, "text") ||
        Map.get(chat, :text) ||
        ""

    %{
      "author" => viewer["name"],
      "author_id" => viewer["id"],
      "author_role" => viewer["role"],
      "author_color" => viewer["seat_color"],
      "type" => "text",
      "data" => %{"text" => to_string(text)}
    }
  end

  defp maybe_put_session_config(map, _key, nil), do: map
  defp maybe_put_session_config(map, key, value), do: Map.put(map, key, value)

  defp replace_round_players(engine, host_member, guest_member) do
    engine
    |> put_in([:players, :host], replace_player(engine.players.host, host_member, :white))
    |> put_in([:players, :guest], replace_player(engine.players.guest, guest_member, :black))
  end

  defp replace_player(nil, nil, _color), do: nil

  defp replace_player(player, member, color) do
    %{
      id: if(player, do: player.id, else: System.unique_integer([:positive])),
      name: member.name,
      color: color,
      client_id: member.client_id,
      auth_id: Map.get(member, :auth_id)
    }
  end

  defp session_reset_opts(%{kind: :poule} = session) do
    %{
      "queue_size" => session.queue_size,
      "margot_enabled" => session.margot_enabled
    }
    |> maybe_put_session_config("ante", session.ante)
    |> maybe_put_session_config("stake", session.stake)
    |> maybe_put_session_config("hole_value", session.hole_value)
  end

  defp session_reset_opts(%{kind: :multiplayer, mode: :a_tourner} = session) do
    %{"cash_per_jeton_minor" => session.cash_per_jeton_minor}
  end

  defp session_reset_opts(%{kind: :multiplayer} = session) do
    %{"cash_per_jeton_minor" => session.cash_per_jeton_minor}
  end

  defp broadcast_snapshot(state) do
    HermesTrictracWeb.Endpoint.broadcast("games:#{state.name}", "update", %{game: snapshot(state)})
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

  defp error_payload(msg) when is_binary(msg), do: %{msg: msg}
  defp error_payload(payload) when is_map(payload), do: payload

  defp reply_with_seat_reclaim(state, user, client_id, auth_id) do
    case maybe_start_seat_reclaim(state, user, client_id, auth_id) do
      {:ok, updated, error} ->
        persist(updated)
        broadcast_snapshot(updated)
        {:reply, {:error, error}, updated}

      {:error, error, updated} ->
        {:reply, {:error, error}, updated}
    end
  end

  defp normalize_requested_bot(opts, _variant_id, session)
       when is_map(opts) and not is_nil(session) do
    case Map.get(opts, "bot", Map.get(opts, :bot)) do
      nil -> {:ok, nil}
      "" -> {:ok, nil}
      _ -> {:error, "Bot opponents are not available for multi-seat tables."}
    end
  end

  defp normalize_requested_bot(opts, variant_id, _session) when is_map(opts) do
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

  defp ensure_variant_match(%{table_variant: %{id: requested_variant}}, requested_variant, _name),
    do: :ok

  defp ensure_variant_match(%{table_variant: variant}, requested_variant, name) do
    requested = requested_variant || "backgammon"

    if requested == variant.id do
      :ok
    else
      {:error, "Lobby \"#{name}\" is already a #{variant.title} table."}
    end
  end

  defp normalize_engine_join({:ok, engine, player}), do: {:ok, engine, player}
  defp normalize_engine_join({:error, msg}), do: {:error, msg}

  defp actor_by_client_id(engine, client_id) do
    Enum.find([engine.players.host, engine.players.guest], &(&1 && &1.client_id == client_id))
  end

  defp maybe_start_seat_reclaim(state, user, client_id, auth_id) do
    case reclaimable_seat(state.engine, user, client_id, auth_id, state.bot) do
      nil ->
        {:error, error_payload("Lobby is full."), state}

      {seat_key, defender} ->
        case state.seat_reclaim do
          %{seat_key: ^seat_key, claimant_client_id: ^client_id} = reclaim ->
            {:ok, state,
             seat_reclaim_error(
               reclaim,
               "Still waiting for the seated browser to confirm the seat."
             )}

          %{seat_key: ^seat_key} = reclaim ->
            {:error,
             seat_reclaim_error(reclaim, "A seat reclaim is already pending for this table."),
             state}

          _ ->
            seat_reclaim = %{
              seat_key: seat_key,
              seat_color: Atom.to_string(defender.color),
              defender_name: defender.name,
              claimant_name: user,
              claimant_client_id: client_id,
              expires_at_ms: System.system_time(:millisecond) + seat_reclaim_window_ms(),
              timer_ref:
                Process.send_after(
                  self(),
                  {:seat_reclaim_expired, seat_key, client_id},
                  seat_reclaim_window_ms()
                )
            }

            updated = %{state | seat_reclaim: seat_reclaim}

            {:ok, updated,
             seat_reclaim_error(seat_reclaim, reclaim_warning_message(defender.name))}
        end
    end
  end

  defp maybe_cancel_seat_reclaim(%{seat_reclaim: nil}, _user, _client_id) do
    {:error, "No seat reclaim warning is waiting for this browser."}
  end

  defp maybe_cancel_seat_reclaim(state, user, client_id) do
    seat_key = state.seat_reclaim.seat_key
    defender = seat_player(state.engine, seat_key)

    cond do
      is_nil(defender) ->
        {:error, "No seated player is available to confirm this seat."}

      defender.client_id != client_id ->
        {:error, "Only the currently seated browser can keep this seat."}

      defender.name != user ->
        {:error, "Only the currently seated browser can keep this seat."}

      true ->
        {:ok, clear_seat_reclaim(state)}
    end
  end

  defp maybe_clear_seat_reclaim(%{seat_reclaim: nil} = state, _player), do: {:ok, state}

  defp maybe_clear_seat_reclaim(state, %{"color" => color}) do
    current_reclaim = state.seat_reclaim

    if current_reclaim && current_reclaim.seat_color == color do
      {:ok, clear_seat_reclaim(state)}
    else
      {:ok, state}
    end
  end

  defp clear_seat_reclaim(%{seat_reclaim: nil} = state), do: state

  defp clear_seat_reclaim(state) do
    if timer_ref = get_in(state, [:seat_reclaim, :timer_ref]) do
      Process.cancel_timer(timer_ref)
    end

    %{state | seat_reclaim: nil}
  end

  defp reclaimable_seat(engine, user, client_id, auth_id, bot) do
    cond do
      eligible_reclaim_player?(engine.players.host, user, client_id, auth_id, bot) ->
        {:host, engine.players.host}

      eligible_reclaim_player?(engine.players.guest, user, client_id, auth_id, bot) ->
        {:guest, engine.players.guest}

      true ->
        nil
    end
  end

  defp eligible_reclaim_player?(nil, _user, _client_id, _auth_id, _bot), do: false

  defp eligible_reclaim_player?(player, user, client_id, auth_id, bot) do
    player.name == user &&
      player.client_id != client_id &&
      (is_nil(auth_id) or Map.get(player, :auth_id) != auth_id) &&
      not bot_client?(player, bot)
  end

  defp bot_client?(_player, nil), do: false
  defp bot_client?(player, bot), do: player.client_id == bot.client_id

  defp seat_reclaim_error(reclaim, msg) do
    %{
      code: @seat_reclaim_code,
      msg: msg,
      retry_after_ms: max(0, reclaim.expires_at_ms - System.system_time(:millisecond))
    }
  end

  defp reclaim_warning_message(name) do
    "#{name} is already seated here. A warning was sent to the current browser. Try again after the grace window if no one clicks Remain Seated."
  end

  defp seat_reclaim_window_ms do
    Application.get_env(:hermes_trictrac, :seat_reclaim_window_ms, 15_000)
  end

  defp seat_player(engine, :host), do: engine.players.host
  defp seat_player(engine, :guest), do: engine.players.guest

  defp reclaim_seat(state, reclaim) do
    player = seat_player(state.engine, reclaim.seat_key)

    if player do
      updated_player = %{
        player
        | name: reclaim.claimant_name,
          client_id: reclaim.claimant_client_id
      }

      updated_engine =
        case reclaim.seat_key do
          :host -> put_in(state.engine, [:players, :host], updated_player)
          :guest -> put_in(state.engine, [:players, :guest], updated_player)
        end

      %{state | engine: updated_engine}
    else
      state
    end
  end

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
        Logger.warning("Bot follow-up failed in lobby #{inspect(state.name)}: #{inspect(msg)}")

        if strict do
          {:error, msg}
        else
          {:ok, updated}
        end
    end
  end

  defp maybe_prepare_bot_game(state, _user, _client_id, nil), do: {:ok, state}

  defp maybe_prepare_bot_game(state, user, client_id, _requested_bot) do
    settle_bot_pregame(state, user, client_id, 0)
  end

  defp settle_bot_pregame(state, _user, _client_id, steps) when steps >= 8 do
    maybe_run_bot_turns(state, strict: true)
  end

  defp settle_bot_pregame(state, user, client_id, steps) do
    with {:ok, bot_updated} <- maybe_run_bot_turns(state, strict: true),
         {:ok, host_updated, host_changed?} <-
           maybe_submit_host_bot_options(bot_updated, user, client_id) do
      if host_changed? do
        settle_bot_pregame(host_updated, user, client_id, steps + 1)
      else
        {:ok, host_updated}
      end
    end
  end

  defp maybe_submit_host_bot_options(%{bot: nil} = state, _user, _client_id),
    do: {:ok, state, false}

  defp maybe_submit_host_bot_options(state, user, client_id) do
    case host_bot_options(state.engine.pending_match_options, state.bot) do
      nil ->
        {:ok, state, false}

      options ->
        case Engine.submit_match_options(state.engine, options, user, client_id) do
          {:ok, engine} -> {:ok, %{state | engine: engine}, true}
          {:error, msg} -> {:error, msg}
        end
    end
  end

  defp host_bot_options(nil, _bot), do: nil

  defp host_bot_options(%{"kind" => "trictrac_margot_consent"} = pending, bot) do
    responses = pending["responses"] || %{}

    if is_nil(Map.get(responses, "white")) do
      %{"margotConsent" => if(bot_margot_enabled?(bot), do: "yes", else: "no")}
    end
  end

  defp host_bot_options(%{"kind" => "trictrac_partie_length_consent"}, _bot), do: nil

  defp host_bot_options(%{"options" => options}, %{kind: @trictrac_bot} = bot)
       when is_list(options) do
    Enum.into(options, %{}, fn option ->
      key = option["key"]

      value =
        if key == "margotEnabled", do: bot_margot_enabled?(bot), else: option["defaultValue"]

      {key, value}
    end)
  end

  defp host_bot_options(_pending, _bot), do: nil

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
        case Map.get(responses, "white") do
          value when value in ["6", "8", "10", "12", "14", "16", "18", "20", "22", "24"] ->
            {:submit_match_options, %{"aEcrirePartieLengthConsent" => value}}

          _ ->
            nil
        end

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
