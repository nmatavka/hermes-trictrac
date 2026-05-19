defmodule HermesTrictrac.PouleSession do
  alias HermesTrictrac.Rules.Registry
  alias HermesTrictrac.Rules.Trictrac.Classique

  @type member :: %{
          id: integer(),
          name: String.t(),
          client_id: String.t(),
          auth_id: String.t() | nil,
          connected: boolean(),
          joined_order: integer(),
          contributed: integer(),
          payout: integer(),
          active_entries: integer()
        }

  @type queue_entry :: integer() | {:open_slot, integer()}

  def new(
        %{id: variant_id, title: variant_title, base_variant_id: base_variant_id} = variant,
        opts
      ) do
    style = Map.get(variant, :session_style, :growing_pot)

    with {:ok, queue_size} <-
           normalize_positive_integer(opts, "queue_size", "Queue size must be at least 1."),
         {:ok, margot_enabled} <- normalize_boolean(opts, "margot_enabled"),
         {:ok, style_config} <- normalize_style_config(style, opts) do
      base_variant = Registry.fetch!(base_variant_id)

      {:ok,
       %{
         kind: :poule,
         variant_id: variant_id,
         variant_title: variant_title,
         style: style,
         base_variant_id: base_variant_id,
         base_variant_title: base_variant.title,
         hole_target: if(style == :growing_pot, do: 6, else: nil),
         queue_size: queue_size,
         competitor_target: queue_size + 2,
         win_target: if(style == :growing_pot, do: queue_size + 2, else: nil),
         ante: Map.get(style_config, :ante),
         stake: Map.get(style_config, :stake),
         hole_value: Map.get(style_config, :hole_value),
         margot_enabled: margot_enabled,
         phase: :waiting_for_competitors,
         members: %{},
         member_ids_by_client: %{},
         active: %{host: nil, guest: nil},
         queue: [],
         draw_order: [],
         spectators: [],
         champion_id: nil,
         streak: 0,
         pool: 0,
         winner_id: nil,
         history: [],
         next_member_id: 1,
         next_open_slot_id: 1
       }}
    end
  end

  def round_options(session) do
    base = %{"margotEnabled" => session.margot_enabled}

    case session.style do
      :growing_pot ->
        Map.put(base, "classiqueHoleTarget", session.hole_target)

      :plucked_pot ->
        Map.put(base, "pluckedPouleMode", true)
    end
  end

  def join(session, user, client_id, auth_id \\ nil) do
    case existing_member_id(session, client_id, auth_id) do
      nil ->
        do_join(session, user, client_id, auth_id)

      member_id ->
        previous_client_id = session.members[member_id].client_id

        session =
          update_in(session, [:members, member_id], fn member ->
            member
            |> Map.put(:connected, true)
            |> Map.put(:name, user)
            |> Map.put(:client_id, client_id)
            |> Map.put(:auth_id, auth_id)
          end)
          |> maybe_drop_previous_client_id(previous_client_id, client_id)
          |> put_in([:member_ids_by_client, client_id], member_id)

        {:ok, session, viewer(session, client_id), nil}
    end
  end

  def add_spectator(session, user, client_id, auth_id \\ nil) do
    case existing_member_id(session, client_id, auth_id) do
      nil ->
        member = %{
          id: session.next_member_id,
          name: user,
          client_id: client_id,
          auth_id: auth_id,
          connected: true,
          joined_order: session.next_member_id,
          contributed: 0,
          payout: 0,
          active_entries: 0
        }

        session =
          session
          |> put_in([:members, member.id], member)
          |> put_in([:member_ids_by_client, client_id], member.id)
          |> update_in([:spectators], &(&1 ++ [member.id]))
          |> Map.update!(:next_member_id, &(&1 + 1))

        {:ok, session, viewer(session, client_id)}

      member_id ->
        previous_client_id = session.members[member_id].client_id

        session =
          session
          |> update_in([:members, member_id], fn member ->
            member
            |> Map.put(:connected, true)
            |> Map.put(:name, user)
            |> Map.put(:client_id, client_id)
            |> Map.put(:auth_id, auth_id)
          end)
          |> maybe_drop_previous_client_id(previous_client_id, client_id)
          |> put_in([:member_ids_by_client, client_id], member_id)

        {:ok, session, viewer(session, client_id)}
    end
  end

  def leave(session, client_id) do
    case session.member_ids_by_client[client_id] do
      nil ->
        {:ok, session, nil}

      member_id ->
        session = do_leave(session, member_id)
        {:ok, session, nil}
    end
  end

  def claim_queue_spot(session, client_id) do
    with member_id when not is_nil(member_id) <- session.member_ids_by_client[client_id],
         :spectator <- member_role(session, member_id),
         true <- Enum.any?(session.queue, &open_slot?/1) do
      session =
        session
        |> update_in([:spectators], &Enum.reject(&1, fn id -> id == member_id end))
        |> put_in_first_open_queue_slot(member_id)

      maybe_resume_waiting_round(session, client_id)
    else
      nil ->
        {:error, "Player not found in lobby."}

      false ->
        {:error, "No open queue slot is available."}

      _other ->
        {:error, "Only spectators can claim an open queue slot."}
    end
  end

  def record_round(session, engine) do
    case session.style do
      :growing_pot -> record_growing_round(session, engine)
      :plucked_pot -> record_plucked_round(session, engine)
    end
  end

  def viewer(session, client_id) do
    with member_id when not is_nil(member_id) <- session.member_ids_by_client[client_id],
         member when not is_nil(member) <- session.members[member_id] do
      case member_role(session, member_id) do
        {:active, seat} ->
          %{
            "id" => member.id,
            "name" => member.name,
            "role" => "active",
            "seat" => Atom.to_string(seat),
            "seat_color" => seat_color(seat),
            "can_claim_queue_spot" => false
          }

        :queued ->
          %{
            "id" => member.id,
            "name" => member.name,
            "role" => "queued",
            "seat" => nil,
            "seat_color" => nil,
            "can_claim_queue_spot" => false
          }

        :spectator ->
          %{
            "id" => member.id,
            "name" => member.name,
            "role" => "spectator",
            "seat" => nil,
            "seat_color" => nil,
            "can_claim_queue_spot" => Enum.any?(session.queue, &open_slot?/1)
          }

        _ ->
          nil
      end
    end
  end

  def serialize(session) do
    %{
      "style" => Atom.to_string(session.style),
      "phase" => Atom.to_string(session.phase),
      "config" => serialize_config(session),
      "active" => %{
        "host" => serialize_active_member(session, session.active.host, :host),
        "guest" => serialize_active_member(session, session.active.guest, :guest)
      },
      "draw_order" => Enum.map(session.draw_order, &serialize_draw_entry(session, &1)),
      "competitors" =>
        [
          serialize_active_member(session, session.active.host, :host),
          serialize_active_member(session, session.active.guest, :guest)
        ] ++ Enum.map(session.queue, &serialize_queue_entry(session, &1)),
      "queue" => Enum.map(session.queue, &serialize_queue_entry(session, &1)),
      "spectators" => Enum.map(session.spectators, &serialize_member(session.members[&1])),
      "open_queue_slots" => Enum.count(session.queue, &open_slot?/1),
      "champion" => serialize_member(session.members[session.champion_id]),
      "streak" => session.streak,
      "pool" => session.pool,
      "remaining_fund" => session.pool,
      "winner" => serialize_member(session.members[session.winner_id]),
      "ledger" =>
        session.members
        |> Map.values()
        |> Enum.filter(&ledger_member?(session, &1.id))
        |> Enum.sort_by(& &1.joined_order)
        |> Enum.map(fn member ->
          %{
            "id" => member.id,
            "name" => member.name,
            "connected" => member.connected,
            "contributed" => member.contributed,
            "payout" => member.payout,
            "net" => member.payout - member.contributed,
            "active_entries" => member.active_entries,
            "role" => serialize_role(member_role(session, member.id))
          }
        end),
      "history" =>
        Enum.map(session.history, fn entry ->
          %{
            "round" => entry.round,
            "winner" => serialize_member(session.members[entry.winner_id]),
            "loser" => serialize_member(session.members[entry.loser_id]),
            "entrant" => serialize_member(session.members[entry[:entrant_id]]),
            "winner_kind" => entry.winner_kind,
            "ante_paid_on_entry" => entry[:ante_paid_on_entry] || false,
            "settlement_trous" => entry[:settlement_trous],
            "payout_amount" => entry[:payout_amount],
            "pool_after" => entry[:pool_after] || session.pool
          }
        end)
    }
  end

  def inject_snapshot(snapshot, session) do
    variant =
      snapshot["variant"]
      |> Map.put("id", session.variant_id)
      |> Map.put("title", session.variant_title)
      |> Map.put("rule_name", session.variant_title)
      |> Map.put("active_variant_id", session.base_variant_id)
      |> Map.put("active_variant_title", session.base_variant_title)

    snapshot
    |> Map.put("variant", variant)
    |> Map.put("status", status_for_snapshot(snapshot, session))
    |> Map.put("players", %{
      "host" => serialize_active_member(session, session.active.host, :host),
      "guest" => serialize_active_member(session, session.active.guest, :guest)
    })
    |> Map.put("poule", serialize(session))
  end

  def connected_competitors(session) do
    session.members
    |> Map.values()
    |> Enum.filter(fn member ->
      role = member_role(session, member.id)
      member.connected && (match?({:active, _seat}, role) or role == :queued)
    end)
    |> Enum.sort_by(& &1.joined_order)
  end

  def connected_spectators(session) do
    session.spectators
    |> Enum.map(&session.members[&1])
    |> Enum.filter(&(&1 && &1.connected))
    |> Enum.sort_by(& &1.joined_order)
  end

  defp record_growing_round(session, engine) do
    with winner_id when not is_nil(winner_id) <- winner_member_id(session, engine.match.winner),
         loser_id when not is_nil(loser_id) <- loser_member_id(session, engine.match.winner) do
      {champion_id, streak} =
        if session.champion_id == winner_id do
          {winner_id, session.streak + 1}
        else
          {winner_id, 1}
        end

      history_entry = %{
        round: length(session.history) + 1,
        winner_id: winner_id,
        loser_id: loser_id,
        winner_kind: engine.match.winner_kind
      }

      session =
        session
        |> Map.put(:champion_id, champion_id)
        |> Map.put(:streak, streak)
        |> update_in([:history], &(&1 ++ [history_entry]))

      if streak >= session.win_target do
        winner_payout = session.pool

        session =
          session
          |> Map.put(:phase, :finished)
          |> Map.put(:winner_id, winner_id)
          |> update_in([:members, winner_id, :payout], &((&1 || 0) + winner_payout))

        {:ok, session, :finished}
      else
        queue_after_rotation = session.queue ++ [loser_id]

        case queue_after_rotation do
          [head | rest] when is_integer(head) ->
            {session, paid_ante?} =
              activate_member(
                %{
                  session
                  | queue: rest,
                    active: %{host: winner_id, guest: head},
                    phase: :playing
                },
                head
              )

            session =
              session
              |> update_last_history_entry(fn entry ->
                entry
                |> Map.put(:entrant_id, head)
                |> Map.put(:ante_paid_on_entry, paid_ante?)
                |> Map.put(:pool_after, session.pool)
              end)

            {:ok, session, {:start_round, winner_id, head}}

          _queue ->
            session =
              session
              |> Map.put(:active, %{host: winner_id, guest: nil})
              |> Map.put(:queue, queue_after_rotation)
              |> Map.put(:phase, :waiting_for_queue_refill)
              |> update_last_history_entry(&Map.put(&1, :pool_after, session.pool))

            {:ok, session, :waiting_for_queue_refill}
        end
      end
    else
      _ ->
        {:error, "Poule round result is missing a winner."}
    end
  end

  defp record_plucked_round(session, engine) do
    with {:ok, round_result} <- plucked_round_result(session, engine) do
      %{winner_id: winner_id, loser_id: loser_id, winner_kind: winner_kind} = round_result
      settlement_trous = round_result.settlement_trous
      payout_amount = min(session.pool, settlement_trous * session.hole_value)
      remaining_fund = max(session.pool - payout_amount, 0)

      history_entry = %{
        round: length(session.history) + 1,
        winner_id: winner_id,
        loser_id: loser_id,
        winner_kind: winner_kind,
        settlement_trous: settlement_trous,
        payout_amount: payout_amount
      }

      session =
        session
        |> update_in([:history], &(&1 ++ [history_entry]))
        |> update_in([:members, winner_id, :payout], &((&1 || 0) + payout_amount))
        |> Map.put(:pool, remaining_fund)

      if remaining_fund == 0 do
        session =
          session
          |> Map.put(:phase, :finished)
          |> Map.put(:winner_id, winner_id)
          |> update_last_history_entry(&Map.put(&1, :pool_after, 0))

        {:ok, session, :finished}
      else
        next_host_id = session.active.guest
        queue_after_rotation = session.queue ++ [session.active.host]

        case queue_after_rotation do
          [head | rest] when is_integer(head) ->
            {session, _paid_ante?} =
              activate_member(
                %{
                  session
                  | queue: rest,
                    active: %{host: next_host_id, guest: head},
                    phase: :playing
                },
                head
              )

            session =
              update_last_history_entry(session, fn entry ->
                entry
                |> Map.put(:entrant_id, head)
                |> Map.put(:pool_after, session.pool)
              end)

            {:ok, session, {:start_round, next_host_id, head}}

          [head | rest] ->
            session =
              session
              |> Map.put(:active, %{host: next_host_id, guest: nil})
              |> Map.put(:queue, [head | rest])
              |> Map.put(:phase, :waiting_for_queue_refill)
              |> update_last_history_entry(&Map.put(&1, :pool_after, session.pool))

            {:ok, session, :waiting_for_queue_refill}

          [] ->
            {:error, "Poule queue rotation is missing the next competitor."}
        end
      end
    end
  end

  defp plucked_round_result(session, engine) do
    white_trous = Classique.trous_for(engine.trictrac, :white)
    black_trous = Classique.trous_for(engine.trictrac, :black)

    cond do
      white_trous > black_trous ->
        {:ok,
         %{
           winner_id: session.active.host,
           loser_id: session.active.guest,
           settlement_trous: white_trous - black_trous,
           winner_kind: engine.match.winner_kind || "trous"
         }}

      black_trous > white_trous ->
        {:ok,
         %{
           winner_id: session.active.guest,
           loser_id: session.active.host,
           settlement_trous: black_trous - white_trous,
           winner_kind: engine.match.winner_kind || "trous"
         }}

      true ->
        {:error, "Plucked-pool round is tied and cannot be settled yet."}
    end
  end

  defp serialize_config(session) do
    %{
      "style" => Atom.to_string(session.style),
      "queue_size" => session.queue_size,
      "competitor_target" => session.competitor_target,
      "margot_enabled" => session.margot_enabled,
      "base_variant_id" => session.base_variant_id,
      "base_variant_title" => session.base_variant_title
    }
    |> maybe_put("win_target", session.win_target)
    |> maybe_put("ante", session.ante)
    |> maybe_put("stake", session.stake)
    |> maybe_put("hole_value", session.hole_value)
  end

  defp do_join(session, user, client_id, auth_id) do
    member = %{
      id: session.next_member_id,
      name: user,
      client_id: client_id,
      auth_id: auth_id,
      connected: true,
      joined_order: session.next_member_id,
      contributed: 0,
      payout: 0,
      active_entries: 0
    }

    session =
      session
      |> put_in([:members, member.id], member)
      |> put_in([:member_ids_by_client, client_id], member.id)
      |> Map.update!(:next_member_id, &(&1 + 1))

    cond do
      session.phase == :waiting_for_competitors and
          competitor_count(session) < session.competitor_target ->
        session = update_in(session.queue, &(&1 ++ [member.id]))

        if competitor_count(session) == session.competitor_target do
          start_competition(session, member.id)
        else
          {:ok, session, viewer(session, client_id), nil}
        end

      true ->
        session = update_in(session.spectators, &(&1 ++ [member.id]))
        {:ok, session, viewer(session, client_id), nil}
    end
  end

  defp start_competition(session, member_id) do
    draw_order = Enum.shuffle(session.queue)
    [host_id, guest_id | queue] = draw_order
    competitors = [host_id, guest_id] ++ queue

    session =
      session
      |> Map.put(:draw_order, draw_order)
      |> Map.put(:queue, queue)
      |> Map.put(:active, %{host: host_id, guest: guest_id})
      |> Map.put(:phase, :playing)
      |> charge_opening_fund_for(competitors)
      |> mark_member_active(host_id)
      |> mark_member_active(guest_id)

    {:ok, session, viewer(session, member_id_to_client(session, member_id)),
     {:start_round, host_id, guest_id}}
  end

  defp maybe_resume_waiting_round(session, viewer_client_id) do
    case {session.phase, session.active.host, session.active.guest, session.queue} do
      {:waiting_for_queue_refill, host_id, nil, [head | rest]}
      when is_integer(head) and is_integer(host_id) ->
        {session, _paid_ante?} =
          activate_member(
            %{session | queue: rest, active: %{host: host_id, guest: head}, phase: :playing},
            head
          )

        {:ok, session, viewer(session, member_id_to_client(session, head)),
         {:start_round, host_id, head}}

      _ ->
        {:ok, session, viewer(session, viewer_client_id), nil}
    end
  end

  defp do_leave(session, member_id) do
    case member_role(session, member_id) do
      :spectator ->
        session
        |> update_in(
          [:member_ids_by_client],
          &Map.delete(&1, session.members[member_id].client_id)
        )
        |> update_in([:spectators], &Enum.reject(&1, fn id -> id == member_id end))
        |> update_in([:members], &Map.delete(&1, member_id))

      :queued when session.phase == :waiting_for_competitors ->
        session
        |> update_in(
          [:member_ids_by_client],
          &Map.delete(&1, session.members[member_id].client_id)
        )
        |> update_in([:queue], &Enum.reject(&1, fn entry -> entry == member_id end))
        |> update_in([:members], &Map.delete(&1, member_id))

      :queued ->
        session
        |> update_in(
          [:member_ids_by_client],
          &Map.delete(&1, session.members[member_id].client_id)
        )
        |> update_in([:members, member_id, :connected], fn _ -> false end)
        |> replace_queue_entry_with_open_slot(member_id)

      {:active, _seat} ->
        update_in(session, [:members, member_id, :connected], fn _ -> false end)

      _ ->
        session
    end
  end

  defp competitor_count(session) do
    active_count =
      session.active
      |> Map.values()
      |> Enum.reject(&is_nil/1)
      |> length()

    queued_count = Enum.count(session.queue, &is_integer/1)
    active_count + queued_count
  end

  defp member_role(session, member_id) do
    cond do
      session.active.host == member_id -> {:active, :host}
      session.active.guest == member_id -> {:active, :guest}
      Enum.any?(session.queue, &(&1 == member_id)) -> :queued
      Enum.any?(session.spectators, &(&1 == member_id)) -> :spectator
      true -> nil
    end
  end

  defp winner_member_id(session, "white"), do: session.active.host
  defp winner_member_id(session, "black"), do: session.active.guest
  defp winner_member_id(_session, _winner), do: nil

  defp loser_member_id(session, "white"), do: session.active.guest
  defp loser_member_id(session, "black"), do: session.active.host
  defp loser_member_id(_session, _winner), do: nil

  defp activate_member(session, member_id) do
    paid_ante? = session.style == :growing_pot and session.members[member_id].active_entries > 0

    session =
      session
      |> maybe_charge_reentry_ante(member_id, paid_ante?)
      |> mark_member_active(member_id)

    {session, paid_ante?}
  end

  defp maybe_charge_reentry_ante(session, member_id, true),
    do: charge_opening_fund_for(session, [member_id])

  defp maybe_charge_reentry_ante(session, _member_id, false), do: session

  defp charge_opening_fund_for(session, member_ids) do
    amount =
      case session.style do
        :growing_pot -> session.ante
        :plucked_pot -> session.stake
      end

    Enum.reduce(member_ids, session, fn member_id, acc ->
      acc
      |> update_in([:members, member_id, :contributed], &((&1 || 0) + amount))
      |> Map.update!(:pool, &(&1 + amount))
    end)
  end

  defp mark_member_active(session, member_id) do
    update_in(session, [:members, member_id, :active_entries], &((&1 || 0) + 1))
  end

  defp replace_queue_entry_with_open_slot(session, member_id) do
    open_slot = {:open_slot, session.next_open_slot_id}

    session
    |> Map.update!(:next_open_slot_id, &(&1 + 1))
    |> update_in([:queue], &replace_entry_with_open_slot(&1, member_id, open_slot))
    |> update_in([:draw_order], &replace_entry_with_open_slot(&1, member_id, open_slot))
  end

  defp put_in_first_open_queue_slot(session, member_id) do
    session
    |> update_in([:queue], &fill_first_open_slot(&1, member_id))
    |> update_in([:draw_order], &fill_first_open_slot(&1, member_id))
  end

  defp serialize_active_member(session, member_id, seat) when is_integer(member_id) do
    session.members[member_id]
    |> serialize_member()
    |> Map.put("color", seat_color(seat))
    |> Map.put("seat", Atom.to_string(seat))
  end

  defp serialize_active_member(_session, _member_id, _seat), do: nil

  defp serialize_queue_entry(session, member_id) when is_integer(member_id) do
    serialize_member(session.members[member_id])
  end

  defp serialize_queue_entry(_session, {:open_slot, slot_id}) do
    %{
      "id" => "open-slot-#{slot_id}",
      "name" => "Open queue slot",
      "kind" => "open_slot"
    }
  end

  defp serialize_draw_entry(session, member_id) when is_integer(member_id) do
    serialize_member(session.members[member_id])
  end

  defp serialize_draw_entry(_session, {:open_slot, slot_id}) do
    %{
      "id" => "open-slot-#{slot_id}",
      "name" => "Open queue slot",
      "kind" => "open_slot"
    }
  end

  defp serialize_member(nil), do: nil

  defp serialize_member(member) do
    %{
      "id" => member.id,
      "name" => member.name,
      "connected" => member.connected
    }
  end

  defp ledger_member?(session, member_id) do
    member = session.members[member_id]

    member.contributed > 0 or member.payout > 0 or member.active_entries > 0 or
      member_role(session, member_id) in [:queued, {:active, :host}, {:active, :guest}]
  end

  defp open_slot?({:open_slot, _slot_id}), do: true
  defp open_slot?(_entry), do: false

  defp replace_entry_with_open_slot(entries, member_id, open_slot) do
    Enum.map(entries, fn
      ^member_id -> open_slot
      other -> other
    end)
  end

  defp fill_first_open_slot(entries, member_id) do
    {updated, _filled?} =
      Enum.map_reduce(entries, false, fn
        {:open_slot, _slot_id}, false -> {member_id, true}
        entry, filled? -> {entry, filled?}
      end)

    updated
  end

  defp seat_color(:host), do: "white"
  defp seat_color(:guest), do: "black"

  defp serialize_role({:active, _seat}), do: "active"
  defp serialize_role(role) when is_atom(role), do: Atom.to_string(role)
  defp serialize_role(_role), do: nil

  defp status_for_snapshot(_snapshot, %{phase: :waiting_for_competitors}),
    do: "waiting_for_competitors"

  defp status_for_snapshot(_snapshot, %{phase: :waiting_for_queue_refill}),
    do: "waiting_for_queue_refill"

  defp status_for_snapshot(_snapshot, %{phase: :finished}), do: "finished"
  defp status_for_snapshot(snapshot, _session), do: snapshot["status"]

  defp member_id_to_client(session, member_id), do: session.members[member_id].client_id

  defp existing_member_id(session, client_id, auth_id) do
    session.member_ids_by_client[client_id] ||
      if(is_binary(auth_id), do: member_id_by_auth(session, auth_id), else: nil)
  end

  defp member_id_by_auth(session, auth_id) do
    session.members
    |> Enum.find_value(fn
      {member_id, %{auth_id: ^auth_id}} -> member_id
      _ -> nil
    end)
  end

  defp maybe_drop_previous_client_id(session, previous_client_id, client_id)
       when is_binary(previous_client_id) and previous_client_id != client_id do
    update_in(session, [:member_ids_by_client], &Map.delete(&1, previous_client_id))
  end

  defp maybe_drop_previous_client_id(session, _previous_client_id, _client_id), do: session

  defp update_last_history_entry(session, fun) do
    {last_entry, history} = List.pop_at(session.history, -1)

    case last_entry do
      nil -> session
      entry -> %{session | history: history ++ [fun.(entry)]}
    end
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp normalize_style_config(:growing_pot, opts) do
    with {:ok, ante} <- normalize_positive_integer(opts, "ante", "Ante must be at least 1.") do
      {:ok, %{ante: ante}}
    end
  end

  defp normalize_style_config(:plucked_pot, opts) do
    with {:ok, stake} <- normalize_positive_integer(opts, "stake", "Stake must be at least 1."),
         {:ok, hole_value} <-
           normalize_positive_integer(opts, "hole_value", "Hole value must be at least 1.") do
      {:ok, %{stake: stake, hole_value: hole_value}}
    end
  end

  defp normalize_positive_integer(opts, key, error_message) do
    case Map.get(opts, key, Map.get(opts, String.to_atom(key))) do
      value when is_integer(value) and value >= 1 ->
        {:ok, value}

      value when is_binary(value) ->
        case Integer.parse(String.trim(value)) do
          {parsed, ""} when parsed >= 1 -> {:ok, parsed}
          _ -> {:error, error_message}
        end

      _ ->
        {:error, error_message}
    end
  end

  defp normalize_boolean(opts, key) do
    case Map.get(opts, key, Map.get(opts, String.to_atom(key), false)) do
      value when value in [true, "true", "yes", "on", 1, "1"] -> {:ok, true}
      _ -> {:ok, false}
    end
  end
end
