defmodule HermesTrictrac.MultiplayerSession do
  alias HermesTrictrac.Rules.Registry

  @default_partie_length 12
  @default_aecrire_coup_engine_length 6
  @combine_basket_buy_in 2
  @queue_des_paris 20
  @cash_minor_scale 100

  @type member :: %{
          id: integer(),
          name: String.t(),
          client_id: String.t(),
          auth_id: String.t() | nil,
          connected: boolean(),
          joined_order: integer()
        }

  @type slot_entry :: integer() | {:open_slot, integer()}

  def new(
        %{
          id: variant_id,
          title: variant_title,
          base_variant_id: base_variant_id,
          session_family: family,
          session_style: mode,
          competitor_target: competitor_target
        },
        opts
      ) do
    base_variant = Registry.fetch!(base_variant_id)

    with {:ok, cash_per_jeton_minor} <-
           normalize_positive_integer(
             opts,
             "cash_per_jeton_minor",
             "Cash per jeton must be at least 0.01."
           ) do
      {:ok,
       %{
         kind: :multiplayer,
         variant_id: variant_id,
         variant_title: variant_title,
         base_variant_id: base_variant_id,
         base_variant_title: base_variant.title,
         family: family,
         mode: mode,
         competitor_target: competitor_target,
         partie_length: @default_partie_length,
         cash_per_jeton_minor: cash_per_jeton_minor,
         cash_per_fiche_minor: cash_per_jeton_minor * 10,
         phase: :waiting_for_players,
         members: %{},
         member_ids_by_client: %{},
         competitors: [],
         spectators: [],
         active: %{host: nil, guest: nil},
         history: [],
         winner_id: nil,
         side_winner: nil,
         next_member_id: 1,
         next_open_slot_id: 1,
         rotation_state: initial_rotation_state(mode),
         starting_color: :white,
         detection: %{aecrire_coups: 0, honneurs_count: 0, resume_pending: false},
         order_draw: nil,
         pending_match_options: nil,
         pending_rotation: nil,
         a_tourner_ledger: %{},
         combine_poule:
           if(family == :combine,
             do: %{
               basket: 0,
               cycle: 1,
               first_winner_side: nil,
               contract_side: nil,
               last_partie_side: nil,
               last_capture_side: nil,
               last_capture_amount: 0,
               side_stats: %{
                 white: %{parties_won: 0, paid: 0, received: 0, basket_won: 0},
                 black: %{parties_won: 0, paid: 0, received: 0, basket_won: 0}
               }
             },
             else: nil
           )
       }}
    end
  end

  def round_options(session) do
    base = %{"margotEnabled" => false}

    cond do
      session.mode == :a_tourner ->
        Map.put(
          base,
          "aEcrirePartieLength",
          Integer.to_string(@default_aecrire_coup_engine_length)
        )

      session.phase == :playing and is_integer(session.partie_length) ->
        Map.put(base, "aEcrirePartieLength", Integer.to_string(session.partie_length))

      true ->
        base
    end
  end

  def join(session, user, client_id, auth_id \\ nil) do
    case existing_member_id(session, client_id, auth_id) do
      nil ->
        do_join(session, user, client_id, auth_id)

      member_id ->
        previous_client_id = session.members[member_id].client_id

        session =
          session
          |> put_in([:members, member_id, :connected], true)
          |> put_in([:members, member_id, :name], user)
          |> put_in([:members, member_id, :client_id], client_id)
          |> put_in([:members, member_id, :auth_id], auth_id)
          |> maybe_drop_previous_client_id(previous_client_id, client_id)
          |> put_in([:member_ids_by_client, client_id], member_id)
          |> maybe_restore_member_slot(member_id)

        {:ok, session, viewer(session, client_id), maybe_resume_roster_wait(session, client_id)}
    end
  end

  def add_spectator(session, user, client_id, auth_id \\ nil) do
    case existing_member_id(session, client_id, auth_id) do
      nil ->
        member = new_member(session, user, client_id, auth_id)

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
          |> put_in([:members, member_id, :connected], true)
          |> put_in([:members, member_id, :name], user)
          |> put_in([:members, member_id, :client_id], client_id)
          |> put_in([:members, member_id, :auth_id], auth_id)
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

  def claim_roster_slot(session, client_id) do
    with member_id when not is_nil(member_id) <- session.member_ids_by_client[client_id],
         :spectator <- member_role(session, member_id),
         true <- Enum.any?(session.competitors, &open_slot?/1) do
      session =
        session
        |> update_in([:spectators], &Enum.reject(&1, fn id -> id == member_id end))
        |> put_in_first_open_slot(member_id)

      maybe_resume_roster_wait(session, client_id)
    else
      nil ->
        {:error, "Player not found in lobby."}

      false ->
        {:error, "No open roster slot is available."}

      _other ->
        {:error, "Only spectators can claim an open roster slot."}
    end
  end

  def advance(session, engine) do
    session =
      maybe_record_combine_partie(session, engine)

    session =
      maybe_record_aecrire_coup(session, engine)

    session =
      maybe_resume_pending_rotation(session, engine)
      |> put_detection(engine)

    cond do
      session.phase in [:waiting_for_roster_refill, :continuing_honneurs_after_coup] ->
        {:ok, session, nil}

      is_nil(session.pending_rotation) ->
        {:ok, session, nil}

      true ->
        action = session.pending_rotation
        {:ok, %{session | pending_rotation: nil}, action}
    end
  end

  def round_started(session) do
    %{session | detection: %{aecrire_coups: 0, honneurs_count: 0, resume_pending: false}}
  end

  def pending_order_draw?(session),
    do: session.phase == :awaiting_order_draw and is_map(session.order_draw)

  def pending_match_options?(session), do: is_map(session.pending_match_options)

  def round_start_color(%{mode: :a_tourner}), do: :white
  def round_start_color(session), do: session.starting_color || :white

  def roll_for_order(session, client_id, forced_value \\ nil) do
    cond do
      not pending_order_draw?(session) ->
        {:error, "Order draw is not available right now."}

      is_nil(session.member_ids_by_client[client_id]) ->
        {:error, "Player not found in lobby."}

      not competitor_member?(session, session.member_ids_by_client[client_id]) ->
        {:error, "Only a rostered competitor can participate in the order draw."}

      current_order_roller_id(session.order_draw) != session.member_ids_by_client[client_id] ->
        {:error, "Only the current order-draw roller can do that."}

      true ->
        member_id = session.member_ids_by_client[client_id]

        with {:ok, value} <- normalize_order_roll(forced_value) do
          order_draw =
            session.order_draw
            |> put_in([:current_rolls, member_id], value)
            |> Map.update!(:next_index, &(&1 + 1))

          if order_draw.next_index < length(order_draw.queue) do
            {:ok, %{session | order_draw: order_draw}, nil}
          else
            resolve_order_draw(session, order_draw)
          end
        end
    end
  end

  def submit_match_options(session, options, client_id) do
    with pending when is_map(pending) <- session.pending_match_options,
         member_id when not is_nil(member_id) <- session.member_ids_by_client[client_id],
         true <- competitor_member?(session, member_id),
         {:ok, response} <- normalize_partie_length_consent(session.mode, options) do
      responses =
        Map.put(pending["responses"] || %{}, Integer.to_string(member_id), response)

      pending = Map.put(pending, "responses", responses)

      if Enum.all?(Map.values(responses), &is_binary/1) do
        chosen =
          case Enum.uniq(Map.values(responses)) do
            [value] -> value
            _ -> Integer.to_string(@default_partie_length)
          end

        session =
          session
          |> Map.put(:partie_length, String.to_integer(chosen))
          |> Map.put(:pending_match_options, nil)
          |> initialize_ledgers()
          |> Map.put(:phase, :playing)

        {:ok, session, {:start_round, session.active.host, session.active.guest}}
      else
        {:ok, %{session | pending_match_options: pending}, nil}
      end
    else
      nil ->
        {:error, "Match options are not available right now."}

      false ->
        {:error, "Only a rostered competitor can submit match options."}

      {:error, _msg} = error ->
        error
    end
  end

  def viewer(session, client_id) do
    with member_id when not is_nil(member_id) <- session.member_ids_by_client[client_id],
         member when not is_nil(member) <- session.members[member_id] do
      partner_id = partner_id(session, member_id)
      side = side_for_member(session, member_id)

      case member_role(session, member_id) do
        {:active, seat} ->
          %{
            "id" => member.id,
            "name" => member.name,
            "role" => "active",
            "seat" => Atom.to_string(seat),
            "seat_color" => seat_color(seat),
            "side" => side && Atom.to_string(side),
            "partner_id" => partner_id,
            "can_claim_roster_slot" => false
          }

        :bench ->
          %{
            "id" => member.id,
            "name" => member.name,
            "role" => "bench",
            "seat" => nil,
            "seat_color" => nil,
            "side" => side && Atom.to_string(side),
            "partner_id" => partner_id,
            "can_claim_roster_slot" => false
          }

        :spectator ->
          %{
            "id" => member.id,
            "name" => member.name,
            "role" => "spectator",
            "seat" => nil,
            "seat_color" => nil,
            "side" => nil,
            "partner_id" => nil,
            "can_claim_roster_slot" => Enum.any?(session.competitors, &open_slot?/1)
          }
      end
    end
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
    |> Map.put("pending_match_options", session.pending_match_options)
    |> update_in(["match", "options"], fn options ->
      Map.delete(options || %{}, "aEcrirePartieLength")
    end)
    |> Map.put("players", %{
      "host" => serialize_active_member(session, session.active.host, :host),
      "guest" => serialize_active_member(session, session.active.guest, :guest)
    })
    |> update_in(["ui_actions"], fn actions ->
      actions
      |> Kernel.||(%{})
      |> Map.put("can_submit_match_options", is_map(session.pending_match_options))
      |> Map.put("can_roll_for_order", pending_order_draw?(session))
    end)
    |> Map.put("multiplayer", serialize(session, snapshot))
  end

  def connected_competitors(session) do
    session.competitors
    |> Enum.filter(&is_integer/1)
    |> Enum.map(&session.members[&1])
    |> Enum.filter(&(&1 && &1.connected))
    |> Enum.sort_by(& &1.joined_order)
  end

  def connected_spectators(session) do
    session.spectators
    |> Enum.map(&session.members[&1])
    |> Enum.filter(&(&1 && &1.connected))
    |> Enum.sort_by(& &1.joined_order)
  end

  defp serialize(session, snapshot) do
    %{
      "kind" => "multiplayer",
      "family" => Atom.to_string(session.family),
      "mode" => Atom.to_string(session.mode),
      "phase" => Atom.to_string(session.phase),
      "competitor_target" => session.competitor_target,
      "partie_length" => session.partie_length,
      "accounting" => serialize_accounting(session),
      "participants" =>
        Enum.map(session.competitors, fn slot ->
          serialize_participant(session, slot)
        end),
      "active_pair" => %{
        "host" => serialize_active_member(session, session.active.host, :host),
        "guest" => serialize_active_member(session, session.active.guest, :guest)
      },
      "order_draw" => serialize_order_draw(session),
      "waiting_slots" => Enum.count(session.competitors, &open_slot?/1),
      "rotation_state" => serialize_rotation_state(session),
      "ledger" => serialize_ledger(session, snapshot),
      "session_winner" => serialize_session_winner(session),
      "history" => serialize_history(session),
      "awaiting_match_options" => is_map(session.pending_match_options)
    }
  end

  defp serialize_order_draw(%{order_draw: nil}), do: nil

  defp serialize_order_draw(session) do
    order_draw = session.order_draw

    visible_rolls =
      if map_size(order_draw.current_rolls) > 0,
        do: order_draw.current_rolls,
        else: order_draw.last_rolls

    %{
      "step" => Atom.to_string(order_draw.step),
      "current_roller" => serialize_member(session.members[current_order_roller_id(order_draw)]),
      "rolls" =>
        visible_rolls
        |> Enum.sort_by(fn {member_id, _value} -> member_id end)
        |> Enum.map(fn {member_id, value} ->
          %{"member" => serialize_member(session.members[member_id]), "value" => value}
        end),
      "rerolling" => order_draw.reroll_ids != [],
      "reroll_participants" =>
        Enum.map(order_draw.reroll_ids, &serialize_member(session.members[&1])),
      "resolved_opening" => serialize_resolved_opening(session, order_draw.resolved)
    }
  end

  defp serialize_resolved_opening(_session, %{} = resolved) when map_size(resolved) == 0, do: nil

  defp serialize_resolved_opening(session, resolved) when is_map(resolved) do
    if is_nil(Map.get(resolved, :host_id)) or is_nil(Map.get(resolved, :guest_id)) do
      nil
    else
      %{
        "host" => serialize_member(session.members[resolved[:host_id]]),
        "guest" => serialize_member(session.members[resolved[:guest_id]]),
        "resting" => serialize_member(session.members[resolved[:resting_id]]),
        "starting_side" => resolved[:starting_color] && Atom.to_string(resolved[:starting_color]),
        "die_holder" =>
          serialize_member(
            session.members[
              case resolved[:starting_color] do
                :black -> resolved[:guest_id]
                _ -> resolved[:host_id]
              end
            ]
          )
      }
    end
  end

  defp serialize_history(session) do
    Enum.map(session.history, fn entry ->
      %{
        "coup" => entry[:coup],
        "winner" => serialize_member(session.members[entry[:winner_id]]),
        "loser" => serialize_member(session.members[entry[:loser_id]]),
        "resting" => serialize_member(session.members[entry[:resting_id]]),
        "winner_side" => entry[:winner_side] && Atom.to_string(entry[:winner_side]),
        "points_awarded" => entry[:points_awarded],
        "consolation_bonus" => entry[:consolation_bonus],
        "continuing_honneurs" => entry[:continuing_honneurs] || false
      }
    end)
  end

  defp serialize_accounting(session) do
    %{
      "cash_per_jeton_minor" => session.cash_per_jeton_minor,
      "cash_per_fiche_minor" => session.cash_per_fiche_minor,
      "cash_minor_scale" => @cash_minor_scale
    }
  end

  defp serialize_ledger(%{mode: :a_tourner} = session, _snapshot) do
    %{
      "players" =>
        session.a_tourner_ledger
        |> Map.values()
        |> Enum.sort_by(& &1.joined_order)
        |> Enum.map(fn entry ->
          %{
            "id" => entry.id,
            "name" => entry.name,
            "coups_lost" => entry.coups_lost,
            "jetons" => entry.jetons,
            "jetons_cash_minor" => jeton_cash_minor(session, entry.jetons),
            "resting_consolation" => entry.resting_consolation,
            "resting_consolation_cash_minor" =>
              jeton_cash_minor(session, entry.resting_consolation),
            "paris_net" => entry.paris_net,
            "paris_net_cash_minor" => jeton_cash_minor(session, entry.paris_net),
            "queue_paris" => entry.queue_paris,
            "queue_paris_cash_minor" => jeton_cash_minor(session, entry.queue_paris),
            "queue_jetons" => entry.queue_jetons,
            "queue_jetons_cash_minor" => jeton_cash_minor(session, entry.queue_jetons),
            "final_total" => entry.final_total,
            "final_total_cash_minor" => jeton_cash_minor(session, entry.final_total)
          }
        end)
    }
  end

  defp serialize_ledger(session, snapshot) do
    aecrire = get_in(snapshot, ["trictrac", "track_aecrire"]) || %{}
    settlement = get_in(snapshot, ["trictrac", "settlement_ledger"]) || %{}
    honneurs = get_in(snapshot, ["trictrac", "track_classique_honneurs"]) || %{}
    sides = side_members(session)

    side_entries =
      [:white, :black]
      |> Enum.map(fn side ->
        side_key = Atom.to_string(side)
        members = Enum.map(Map.get(sides, side, []), &serialize_member(session.members[&1]))
        ledger = Map.get(settlement, side_key, %{})
        side_honneurs = get_in(honneurs, ["honneurs", side_key]) || 0
        classes = get_in(honneurs, ["classes", side_key]) || %{}
        stats = get_in(session, [:combine_poule, :side_stats, side]) || %{}

        %{
          "side" => side_key,
          "members" => members,
          "marques" => get_in(aecrire, ["marques", side_key]) || 0,
          "points" => get_in(aecrire, ["points_total", side_key]) || 0,
          "coups_won" => ledger["coups_won"] || 0,
          "coups_lost" => ledger["coups_lost"] || 0,
          "paris" => ledger["paris"] || 0,
          "paris_cash_minor" => jeton_cash_minor(session, ledger["paris"] || 0),
          "jetons" => ledger["final_total"] || 0,
          "jetons_cash_minor" => jeton_cash_minor(session, ledger["final_total"] || 0),
          "honneurs" => side_honneurs,
          "classes" => classes,
          "combine_paid" => Map.get(stats, :paid, 0),
          "combine_paid_cash_minor" => fiche_cash_minor(session, Map.get(stats, :paid, 0)),
          "combine_received" => Map.get(stats, :received, 0),
          "combine_received_cash_minor" =>
            fiche_cash_minor(session, Map.get(stats, :received, 0)),
          "basket_won" => Map.get(stats, :basket_won, 0),
          "basket_won_cash_minor" => fiche_cash_minor(session, Map.get(stats, :basket_won, 0))
        }
      end)

    %{
      "sides" => side_entries,
      "combine_poule" => serialize_combine_poule(session)
    }
  end

  defp serialize_combine_poule(%{family: :combine, combine_poule: poule} = session)
       when is_map(poule) do
    %{
      "basket" => poule.basket,
      "basket_cash_minor" => fiche_cash_minor(session, poule.basket),
      "cycle" => poule.cycle,
      "contract_side" => poule.contract_side && Atom.to_string(poule.contract_side),
      "first_winner_side" => poule.first_winner_side && Atom.to_string(poule.first_winner_side),
      "last_partie_side" => poule.last_partie_side && Atom.to_string(poule.last_partie_side),
      "last_capture_side" => poule.last_capture_side && Atom.to_string(poule.last_capture_side),
      "last_capture_amount" => poule.last_capture_amount,
      "last_capture_amount_cash_minor" => fiche_cash_minor(session, poule.last_capture_amount)
    }
  end

  defp serialize_combine_poule(_session), do: nil

  defp do_join(session, user, client_id, auth_id) do
    member = new_member(session, user, client_id, auth_id)

    session =
      session
      |> put_in([:members, member.id], member)
      |> put_in([:member_ids_by_client, client_id], member.id)
      |> Map.update!(:next_member_id, &(&1 + 1))

    cond do
      competitor_count(session) < session.competitor_target ->
        session = add_competitor(session, member.id)

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

  defp start_competition(session, viewer_member_id) do
    session =
      session
      |> Map.put(:phase, :awaiting_order_draw)
      |> Map.put(:active, %{host: nil, guest: nil})
      |> Map.put(:rotation_state, initial_rotation_state(session.mode))
      |> Map.put(:starting_color, :white)
      |> Map.put(:pending_match_options, nil)
      |> Map.put(:order_draw, new_order_draw(session))

    {:ok, session, viewer(session, member_id_to_client(session, viewer_member_id)), nil}
  end

  defp new_order_draw(%{mode: :a_tourner} = session) do
    competitor_ids = competitor_member_ids(session)

    %{
      step: :table,
      rank_groups: [competitor_ids],
      current_group_index: 0,
      queue: competitor_ids,
      next_index: 0,
      current_rolls: %{},
      last_rolls: %{},
      reroll_ids: [],
      resolved: %{}
    }
  end

  defp new_order_draw(%{mode: :chouette} = session) do
    [_host_id | associates] = competitor_member_ids(session)

    %{
      step: :associates,
      rank_groups: [associates],
      current_group_index: 0,
      queue: associates,
      next_index: 0,
      current_rolls: %{},
      last_rolls: %{},
      reroll_ids: [],
      resolved: %{}
    }
  end

  defp new_order_draw(%{mode: :deux_contre_deux} = session) do
    [white_a, white_b, _black_a, _black_b] = competitor_member_ids(session)

    %{
      step: :white_team,
      rank_groups: [[white_a, white_b]],
      current_group_index: 0,
      queue: [white_a, white_b],
      next_index: 0,
      current_rolls: %{},
      last_rolls: %{},
      reroll_ids: [],
      resolved: %{}
    }
  end

  defp resolve_order_draw(session, order_draw) do
    ranked_subgroups = rank_roll_groups(order_draw.queue, order_draw.current_rolls)

    rank_groups =
      Enum.take(order_draw.rank_groups, order_draw.current_group_index) ++
        ranked_subgroups ++
        Enum.drop(order_draw.rank_groups, order_draw.current_group_index + 1)

    next_tie_index = Enum.find_index(rank_groups, &(length(&1) > 1))

    order_draw = %{
      order_draw
      | rank_groups: rank_groups,
        last_rolls: order_draw.current_rolls,
        current_rolls: %{},
        next_index: 0
    }

    if is_integer(next_tie_index) do
      reroll_ids = Enum.at(rank_groups, next_tie_index) || []

      {:ok,
       %{
         session
         | order_draw: %{
             order_draw
             | current_group_index: next_tie_index,
               queue: reroll_ids,
               reroll_ids: reroll_ids
           }
       }, nil}
    else
      complete_order_draw_step(session, %{order_draw | reroll_ids: []})
    end
  end

  defp complete_order_draw_step(%{mode: :a_tourner} = session, %{step: :table} = order_draw) do
    [host_id, guest_id, resting_id] = List.flatten(order_draw.rank_groups)

    finalize_order_draw(
      session,
      %{
        order_draw
        | resolved: %{
            host_id: host_id,
            guest_id: guest_id,
            resting_id: resting_id,
            starting_color: :white
          }
      }
    )
  end

  defp complete_order_draw_step(%{mode: :chouette} = session, %{step: :associates} = order_draw) do
    [host_id | _rest] = competitor_member_ids(session)
    [guest_id, bench_id] = List.flatten(order_draw.rank_groups)

    finalize_order_draw(
      session,
      %{
        order_draw
        | resolved: %{
            host_id: host_id,
            guest_id: guest_id,
            resting_id: bench_id,
            starting_color: :white
          }
      }
    )
  end

  defp complete_order_draw_step(
         %{mode: :deux_contre_deux} = session,
         %{step: :white_team} = order_draw
       ) do
    [white_leader_id, white_partner_id] = List.flatten(order_draw.rank_groups)
    [_white_a, _white_b, black_a, black_b] = competitor_member_ids(session)

    next_draw = %{
      order_draw
      | step: :black_team,
        rank_groups: [[black_a, black_b]],
        current_group_index: 0,
        queue: [black_a, black_b],
        next_index: 0,
        current_rolls: %{},
        reroll_ids: [],
        resolved:
          Map.merge(order_draw.resolved, %{
            white_leader_id: white_leader_id,
            white_partner_id: white_partner_id
          })
    }

    {:ok, %{session | order_draw: next_draw}, nil}
  end

  defp complete_order_draw_step(
         %{mode: :deux_contre_deux} = session,
         %{step: :black_team} = order_draw
       ) do
    [black_leader_id, black_partner_id] = List.flatten(order_draw.rank_groups)
    white_leader_id = Map.fetch!(order_draw.resolved, :white_leader_id)

    next_draw = %{
      order_draw
      | step: :leaders,
        rank_groups: [[white_leader_id, black_leader_id]],
        current_group_index: 0,
        queue: [white_leader_id, black_leader_id],
        next_index: 0,
        current_rolls: %{},
        reroll_ids: [],
        resolved:
          Map.merge(order_draw.resolved, %{
            black_leader_id: black_leader_id,
            black_partner_id: black_partner_id
          })
    }

    {:ok, %{session | order_draw: next_draw}, nil}
  end

  defp complete_order_draw_step(
         %{mode: :deux_contre_deux} = session,
         %{step: :leaders} = order_draw
       ) do
    [starter_id, _other_id] = List.flatten(order_draw.rank_groups)
    white_leader_id = Map.fetch!(order_draw.resolved, :white_leader_id)
    black_leader_id = Map.fetch!(order_draw.resolved, :black_leader_id)

    finalize_order_draw(
      session,
      %{
        order_draw
        | resolved:
            Map.merge(order_draw.resolved, %{
              host_id: white_leader_id,
              guest_id: black_leader_id,
              starting_color: if(starter_id == white_leader_id, do: :white, else: :black)
            })
      }
    )
  end

  defp finalize_order_draw(session, order_draw) do
    resolved = order_draw.resolved

    session =
      case session.mode do
        :a_tourner ->
          session
          |> Map.put(:active, %{host: resolved.host_id, guest: resolved.guest_id})
          |> put_in([:rotation_state, :resting_id], resolved.resting_id)

        :chouette ->
          session
          |> Map.put(:active, %{host: resolved.host_id, guest: resolved.guest_id})
          |> put_in([:rotation_state, :associate_order], [resolved.guest_id, resolved.resting_id])
          |> put_in([:rotation_state, :associate_index], 0)
          |> put_in([:rotation_state, :associate_coups_in_block], 0)

        :deux_contre_deux ->
          session
          |> Map.put(:active, %{host: resolved.host_id, guest: resolved.guest_id})
          |> put_in([:rotation_state, :host_partner_id], resolved.white_partner_id)
          |> put_in([:rotation_state, :guest_partner_id], resolved.black_partner_id)
      end

    session =
      session
      |> Map.put(:phase, :awaiting_match_options)
      |> Map.put(:starting_color, resolved.starting_color || :white)
      |> Map.put(:pending_match_options, nil)
      |> Map.put(:order_draw, %{
        order_draw
        | step: :complete,
          queue: [],
          next_index: 0,
          current_rolls: %{},
          reroll_ids: []
      })

    session = Map.put(session, :pending_match_options, multiplayer_partie_length_consent(session))

    {:ok, session, nil}
  end

  defp rank_roll_groups(ids, rolls) do
    ids
    |> Enum.group_by(&Map.get(rolls, &1, 0))
    |> Enum.sort_by(fn {value, _group} -> -value end)
    |> Enum.map(fn {_value, group} ->
      Enum.sort_by(group, &session_member_order(rolls, &1))
    end)
  end

  defp session_member_order(_ignored_rolls, member_id), do: member_id

  defp initialize_ledgers(%{mode: :a_tourner} = session) do
    ledger =
      session.competitors
      |> Enum.filter(&is_integer/1)
      |> Enum.map(fn member_id ->
        member = session.members[member_id]

        {member_id,
         %{
           id: member_id,
           name: member.name,
           joined_order: member.joined_order,
           coups_lost: 0,
           jetons: 0,
           resting_consolation: 0,
           paris_net: 0,
           queue_paris: 0,
           queue_jetons: 0,
           final_total: 0
         }}
      end)
      |> Enum.into(%{})

    %{session | a_tourner_ledger: ledger}
  end

  defp initialize_ledgers(%{family: :combine} = session) do
    side_stats =
      side_members(session)
      |> Enum.map(fn {side, member_ids} ->
        buy_in = length(member_ids) * @combine_basket_buy_in
        {side, %{parties_won: 0, paid: buy_in, received: 0, basket_won: 0}}
      end)
      |> Enum.into(%{})

    put_in(session, [:combine_poule], %{
      session.combine_poule
      | basket: session.competitor_target * @combine_basket_buy_in,
        side_stats: side_stats
    })
  end

  defp initialize_ledgers(session), do: session

  defp maybe_record_aecrire_coup(session, engine) do
    coups_played = get_in(engine, [:trictrac, :track_aecrire, :coups_played]) || 0

    if coups_played > session.detection.aecrire_coups do
      process_aecrire_coup(session, engine)
    else
      session
    end
  end

  defp process_aecrire_coup(%{mode: :a_tourner} = session, engine) do
    result = get_in(engine, [:trictrac, :track_aecrire, :last_marque_result]) || %{}
    winner_side = color_atom(result["winner"] || result[:winner])
    loser_side = opposite(winner_side)
    winner_id = member_for_side(session, winner_side)
    loser_id = member_for_side(session, loser_side)
    resting_id = resting_competitor_id(session)
    multiplier = result["multiplier"] || result[:multiplier] || 1
    consolation = result["consolation"] || result[:consolation] || 0
    consolation_bonus = consolation * multiplier
    points_awarded = result["points_awarded"] || result[:points_awarded] || 0

    session =
      session
      |> update_in([:a_tourner_ledger, winner_id, :jetons], &((&1 || 0) + points_awarded))
      |> update_in(
        [:a_tourner_ledger, loser_id, :jetons],
        &((&1 || 0) - points_awarded - consolation_bonus)
      )
      |> update_in([:a_tourner_ledger, loser_id, :coups_lost], &((&1 || 0) + 1))
      |> update_in([:a_tourner_ledger, resting_id, :jetons], &((&1 || 0) + consolation_bonus))
      |> update_in(
        [:a_tourner_ledger, resting_id, :resting_consolation],
        &((&1 || 0) + consolation_bonus)
      )
      |> update_in([:history], fn history ->
        history ++
          [
            %{
              coup: length(history) + 1,
              winner_id: winner_id,
              loser_id: loser_id,
              resting_id: resting_id,
              points_awarded: points_awarded,
              consolation_bonus: consolation_bonus
            }
          ]
      end)

    if length(session.history) >= session.partie_length do
      finalize_a_tourner(session)
    else
      next_pair = {loser_id, resting_id}

      case pair_ready?(session, next_pair) do
        true ->
          %{session | active: %{host: elem(next_pair, 0), guest: elem(next_pair, 1)}}
          |> put_in([:rotation_state, :resting_id], winner_id)
          |> Map.put(:pending_rotation, {:start_round, elem(next_pair, 0), elem(next_pair, 1)})

        false ->
          session
          |> Map.put(:phase, :waiting_for_roster_refill)
          |> Map.put(:pending_rotation, {:start_round, elem(next_pair, 0), elem(next_pair, 1)})
      end
    end
  end

  defp process_aecrire_coup(session, engine) do
    result = get_in(engine, [:trictrac, :track_aecrire, :last_marque_result]) || %{}
    winner_side = color_atom(result["winner"] || result[:winner])
    loser_side = opposite(winner_side)
    winner_id = member_for_side(session, winner_side)
    loser_id = member_for_side(session, loser_side)

    session =
      update_in(session, [:history], fn history ->
        history ++
          [
            %{
              coup: length(history) + 1,
              winner_id: winner_id,
              loser_id: loser_id,
              winner_side: winner_side,
              points_awarded: result["points_awarded"] || result[:points_awarded] || 0,
              continuing_honneurs:
                session.family == :combine and
                  get_in(engine, [:trictrac, :suspension_state, :resume_pending]) == true and
                  get_in(engine, [:trictrac, :suspension_state, :suspended_track]) == "a_ecrire"
            }
          ]
      end)

    if engine.match.is_over do
      session
      |> Map.put(:phase, :finished)
      |> Map.put(:side_winner, winner_side)
    else
      rotation_action = side_rotation_action(session, winner_side)

      cond do
        is_nil(rotation_action) ->
          session

        session.family == :combine and
          get_in(engine, [:trictrac, :suspension_state, :resume_pending]) == true and
            get_in(engine, [:trictrac, :suspension_state, :suspended_track]) == "a_ecrire" ->
          session
          |> Map.put(:phase, :continuing_honneurs_after_coup)
          |> Map.put(:pending_rotation, rotation_action)

        pair_ready?(session, rotation_pair(rotation_action)) ->
          session
          |> apply_rotation_action(rotation_action)
          |> Map.put(:pending_rotation, rotation_action)

        true ->
          session
          |> Map.put(:phase, :waiting_for_roster_refill)
          |> Map.put(:pending_rotation, rotation_action)
      end
    end
  end

  defp maybe_record_combine_partie(%{family: :combine} = session, engine) do
    honneurs_count = honneurs_count(engine)

    if honneurs_count > session.detection.honneurs_count do
      result = get_in(engine, [:trictrac, :track_classique_honneurs, :last_partie_result]) || %{}
      winner_side = color_atom(result["winner"] || result[:winner])
      value = result["value"] || result[:value] || 0

      update_combine_poule(session, winner_side, value)
    else
      session
    end
  end

  defp maybe_record_combine_partie(session, _engine), do: session

  defp update_combine_poule(session, winner_side, value) do
    loser_side = opposite(winner_side)
    current = session.combine_poule
    previous_side = current.last_partie_side
    final_coup = length(session.history) + 1 >= session.partie_length

    current =
      current
      |> put_in(
        [:side_stats, winner_side, :parties_won],
        get_in(current, [:side_stats, winner_side, :parties_won]) + 1
      )
      |> put_in(
        [:side_stats, winner_side, :received],
        get_in(current, [:side_stats, winner_side, :received]) + value
      )
      |> put_in(
        [:side_stats, loser_side, :paid],
        get_in(current, [:side_stats, loser_side, :paid]) + value * 2
      )
      |> Map.put(:basket, current.basket + value)
      |> Map.put(:last_partie_side, winner_side)

    current =
      cond do
        previous_side == winner_side ->
          capture_side = winner_side
          capture_amount = current.basket

          side_stats =
            current.side_stats
            |> put_in(
              [capture_side, :basket_won],
              get_in(current, [:side_stats, capture_side, :basket_won]) + capture_amount
            )

          if final_coup do
            %{
              current
              | contract_side: nil,
                first_winner_side: nil,
                last_capture_side: capture_side,
                last_capture_amount: capture_amount,
                basket: 0,
                side_stats: side_stats
            }
          else
            %{
              current
              | contract_side: capture_side,
                first_winner_side: capture_side,
                last_capture_side: capture_side,
                last_capture_amount: capture_amount,
                basket: session.competitor_target * @combine_basket_buy_in,
                cycle: current.cycle + 1,
                side_stats:
                  side_stats
                  |> put_in(
                    [:white, :paid],
                    get_in(side_stats, [:white, :paid]) + side_buy_in(session, :white)
                  )
                  |> put_in(
                    [:black, :paid],
                    get_in(side_stats, [:black, :paid]) + side_buy_in(session, :black)
                  )
            }
          end

        final_coup and previous_side in [:white, :black] and previous_side != winner_side ->
          [winner_share, previous_share] = split_integer(current.basket, 2)

          side_stats =
            current.side_stats
            |> put_in(
              [winner_side, :basket_won],
              get_in(current, [:side_stats, winner_side, :basket_won]) + winner_share
            )
            |> put_in(
              [previous_side, :basket_won],
              get_in(current, [:side_stats, previous_side, :basket_won]) + previous_share
            )

          %{
            current
            | contract_side: nil,
              first_winner_side: nil,
              last_capture_side: nil,
              last_capture_amount: current.basket,
              basket: 0,
              side_stats: side_stats
          }

        true ->
          %{current | contract_side: winner_side, first_winner_side: winner_side}
      end

    %{session | combine_poule: current}
  end

  defp maybe_resume_pending_rotation(%{pending_rotation: nil} = session, _engine), do: session

  defp maybe_resume_pending_rotation(
         %{family: :combine, phase: :continuing_honneurs_after_coup} = session,
         engine
       ) do
    resume_pending = get_in(engine, [:trictrac, :suspension_state, :resume_pending]) == true

    if not resume_pending do
      action = rotation_action_with_start_color(session.pending_rotation, engine.turn_color)
      pair = rotation_pair(action)

      if pair_ready?(session, pair) do
        session
        |> apply_rotation_action(action)
        |> Map.put(:pending_rotation, action)
      else
        session
        |> Map.put(:phase, :waiting_for_roster_refill)
        |> Map.put(:pending_rotation, action)
      end
    else
      session
    end
  end

  defp maybe_resume_pending_rotation(%{phase: :waiting_for_roster_refill} = session, _engine) do
    case session.pending_rotation do
      nil ->
        session

      action ->
        pair = rotation_pair(action)

        if pair_ready?(session, pair) do
          session
          |> apply_rotation_action(action)
          |> Map.put(:pending_rotation, action)
        else
          session
        end
    end
  end

  defp maybe_resume_pending_rotation(session, _engine), do: session

  defp finalize_a_tourner(session) do
    played_each = div(session.partie_length * 2, 3)
    entries = Map.values(session.a_tourner_ledger)

    net_paris =
      Enum.into(entries, %{}, fn entry ->
        {entry.id, 2 * entry.coups_lost - played_each}
      end)

    {queue_paris_by_id, paris_by_id} = allocate_paris(net_paris)
    queue_jetons_by_id = allocate_queue_jetons(entries, session.partie_length)

    winner_id =
      pick_highest_final_total(entries, paris_by_id, queue_paris_by_id, queue_jetons_by_id)

    ledger =
      Enum.reduce(entries, %{}, fn entry, acc ->
        paris_net = Map.get(net_paris, entry.id, 0)
        queue_paris = Map.get(queue_paris_by_id, entry.id, 0)
        queue_jetons = Map.get(queue_jetons_by_id, entry.id, 0)

        final_total =
          entry.jetons + Map.get(paris_by_id, entry.id, 0) + queue_paris + queue_jetons

        Map.put(acc, entry.id, %{
          entry
          | paris_net: paris_net,
            queue_paris: queue_paris,
            queue_jetons: queue_jetons,
            final_total: final_total
        })
      end)

    %{
      session
      | phase: :finished,
        winner_id: winner_id,
        a_tourner_ledger: ledger
    }
  end

  defp allocate_paris(net_paris) do
    payers =
      net_paris
      |> Enum.filter(fn {_id, value} -> value > 0 end)
      |> Enum.sort_by(fn {id, _value} -> id end)

    payees =
      net_paris
      |> Enum.filter(fn {_id, value} -> value < 0 end)
      |> Enum.map(fn {id, value} -> {id, abs(value)} end)
      |> Enum.sort_by(fn {id, _value} -> id end)

    paris_by_id = Enum.into(Map.keys(net_paris), %{}, &{&1, 0})

    {paris_by_id, _remaining_payers, _remaining_payees} =
      Enum.reduce(payers, {paris_by_id, payers, payees}, fn {payer_id, _},
                                                            {acc, payer_list, payee_list} ->
        {remaining_payers, remaining_payees, next_acc} =
          satisfy_payer(payer_id, payer_list, payee_list, acc)

        {next_acc, remaining_payers, remaining_payees}
      end)

    payer_ids = Enum.map(payers, &elem(&1, 0))
    payee_ids = Enum.map(payees, &elem(&1, 0))
    payer_splits = split_integer(-@queue_des_paris, length(payer_ids))
    payee_splits = split_integer(@queue_des_paris, length(payee_ids))

    queue_paris_by_id =
      Enum.into(Map.keys(net_paris), %{}, fn id ->
        payer_value =
          case Enum.find_index(payer_ids, &(&1 == id)) do
            nil -> 0
            index -> Enum.at(payer_splits, index) || 0
          end

        payee_value =
          case Enum.find_index(payee_ids, &(&1 == id)) do
            nil -> 0
            index -> Enum.at(payee_splits, index) || 0
          end

        {id, payer_value + payee_value}
      end)

    {queue_paris_by_id, paris_by_id}
  end

  defp satisfy_payer(_payer_id, [], payees, acc), do: {[], payees, acc}

  defp satisfy_payer(payer_id, [{current_payer_id, payer_amount} | rest_payers], payees, acc)
       when current_payer_id == payer_id do
    Enum.reduce_while(payees, {rest_payers, payees, acc, payer_amount}, fn
      {payee_id, payee_amount}, {current_payers, current_payees, current_acc, remaining}
      when remaining > 0 ->
        transfer = min(remaining, payee_amount)

        next_payees =
          current_payees
          |> Enum.map(fn
            {^payee_id, amount} -> {payee_id, amount - transfer}
            other -> other
          end)
          |> Enum.reject(fn {_id, amount} -> amount <= 0 end)

        next_acc =
          current_acc
          |> Map.update!(payer_id, &(&1 - transfer * 4))
          |> Map.update!(payee_id, &(&1 + transfer * 4))

        next_remaining = remaining - transfer

        if next_remaining > 0 do
          {:cont, {current_payers, next_payees, next_acc, next_remaining}}
        else
          {:halt, {current_payers, next_payees, next_acc, next_remaining}}
        end

      _payee, state ->
        {:cont, state}
    end)
    |> then(fn {current_payers, current_payees, current_acc, remaining} ->
      next_payers =
        if remaining > 0 do
          [{payer_id, remaining} | current_payers]
        else
          current_payers
        end

      {next_payers, current_payees, current_acc}
    end)
  end

  defp satisfy_payer(_payer_id, payers, payees, acc), do: {payers, payees, acc}

  defp allocate_queue_jetons(entries, queue_pot) do
    highest_jetons =
      entries
      |> Enum.map(& &1.jetons)
      |> Enum.max(fn -> 0 end)

    leader_ids =
      entries
      |> Enum.filter(&(&1.jetons == highest_jetons))
      |> Enum.sort_by(& &1.joined_order)
      |> Enum.map(& &1.id)

    shares = split_integer(queue_pot, length(leader_ids))

    Enum.into(entries, %{}, fn entry ->
      share =
        case Enum.find_index(leader_ids, &(&1 == entry.id)) do
          nil -> 0
          index -> Enum.at(shares, index) || 0
        end

      {entry.id, share}
    end)
  end

  defp pick_highest_final_total(entries, paris_by_id, queue_paris_by_id, queue_jetons_by_id) do
    entries
    |> Enum.max_by(fn entry ->
      {
        entry.jetons + Map.get(paris_by_id, entry.id, 0) + Map.get(queue_paris_by_id, entry.id, 0) +
          Map.get(queue_jetons_by_id, entry.id, 0),
        -entry.joined_order
      }
    end)
    |> Map.fetch!(:id)
  end

  defp do_leave(session, member_id) do
    member = session.members[member_id]

    cond do
      member_role(session, member_id) == :spectator ->
        session
        |> update_in([:spectators], &Enum.reject(&1, fn id -> id == member_id end))
        |> update_in([:member_ids_by_client], &Map.delete(&1, member.client_id))
        |> update_in([:members], &Map.delete(&1, member_id))

      session.phase == :waiting_for_players ->
        session
        |> update_in([:competitors], &Enum.reject(&1, fn id -> id == member_id end))
        |> update_in([:member_ids_by_client], &Map.delete(&1, member.client_id))
        |> update_in([:members], &Map.delete(&1, member_id))

      session.phase in [:awaiting_order_draw, :awaiting_match_options] ->
        session
        |> update_in([:member_ids_by_client], &Map.delete(&1, member.client_id))
        |> put_in([:members, member_id, :connected], false)
        |> replace_slot_with_open_slot(member_id)
        |> reset_preplay_competition()

      member_role(session, member_id) == :bench ->
        session
        |> update_in([:member_ids_by_client], &Map.delete(&1, member.client_id))
        |> put_in([:members, member_id, :connected], false)
        |> replace_slot_with_open_slot(member_id)

      match?({:active, _seat}, member_role(session, member_id)) ->
        session
        |> update_in([:member_ids_by_client], &Map.delete(&1, member.client_id))
        |> put_in([:members, member_id, :connected], false)

      true ->
        session
    end
  end

  defp member_role(session, member_id) do
    cond do
      session.phase in [:awaiting_order_draw, :awaiting_match_options] and
          Enum.any?(session.competitors, &(&1 == member_id)) ->
        :bench

      session.active.host == member_id ->
        {:active, :host}

      session.active.guest == member_id ->
        {:active, :guest}

      Enum.any?(session.spectators, &(&1 == member_id)) ->
        :spectator

      Enum.any?(session.competitors, &(&1 == member_id)) ->
        :bench

      true ->
        nil
    end
  end

  defp maybe_resume_roster_wait(session, viewer_client_id) do
    cond do
      session.phase == :waiting_for_players and
        session.history == [] and
          competitor_count(session) == session.competitor_target ->
        start_competition(session, session.member_ids_by_client[viewer_client_id])

      is_nil(session.pending_rotation) ->
        {:ok, session, viewer(session, viewer_client_id), nil}

      true ->
        action = session.pending_rotation
        pair = rotation_pair(action)

        if pair_ready?(session, pair) do
          session = apply_rotation_pair(session, pair)
          {:ok, session, viewer(session, viewer_client_id), action}
        else
          {:ok, session, viewer(session, viewer_client_id), nil}
        end
    end
  end

  defp side_rotation_action(%{mode: :chouette} = session, _winner_side) do
    order = session.rotation_state.associate_order || []
    current_index = session.rotation_state.associate_index || 0
    coups_in_block = session.rotation_state.associate_coups_in_block || 0
    current_guest = session.active.guest
    start_color = next_chouette_start_color(session)

    if coups_in_block + 1 >= 2 do
      next_index = rem(current_index + 1, length(order))
      next_guest = Enum.at(order, next_index)

      {:seat_pair, session.active.host, next_guest,
       %{
         associate_index: next_index,
         associate_coups_in_block: 0,
         start_color: start_color
       }}
    else
      {:seat_pair, session.active.host, current_guest,
       %{
         associate_index: current_index,
         associate_coups_in_block: coups_in_block + 1,
         start_color: start_color
       }}
    end
  end

  defp side_rotation_action(%{mode: :deux_contre_deux} = session, winner_side) do
    case winner_side do
      :white ->
        next_host = slot_partner(session, session.active.host)
        {:seat_pair, next_host, session.active.guest, %{start_color: :black}}

      :black ->
        next_guest = slot_partner(session, session.active.guest)
        {:seat_pair, session.active.host, next_guest, %{start_color: :white}}
    end
  end

  defp side_rotation_action(_session, _winner_side), do: nil

  defp slot_partner(session, member_id) do
    side = side_for_member(session, member_id)

    session
    |> side_members()
    |> Map.get(side, [])
    |> Enum.find(fn id -> id != member_id end)
  end

  defp rotation_pair({:seat_pair, host_id, guest_id}), do: {host_id, guest_id}
  defp rotation_pair({:seat_pair, host_id, guest_id, _metadata}), do: {host_id, guest_id}
  defp rotation_pair({:start_round, host_id, guest_id}), do: {host_id, guest_id}

  defp apply_rotation_pair(session, {host_id, guest_id}) do
    metadata =
      case session.pending_rotation do
        {:seat_pair, _host_id, _guest_id, metadata} -> metadata
        _ -> %{}
      end

    session
    |> Map.put(:phase, :playing)
    |> Map.put(:active, %{host: host_id, guest: guest_id})
    |> Map.put(:pending_rotation, nil)
    |> update_in([:rotation_state], &Map.merge(&1, metadata))
  end

  defp apply_rotation_action(session, {:seat_pair, host_id, guest_id, metadata}) do
    session
    |> Map.put(:phase, :playing)
    |> Map.put(:active, %{host: host_id, guest: guest_id})
    |> Map.put(:pending_rotation, nil)
    |> update_in([:rotation_state], &Map.merge(&1, metadata))
  end

  defp apply_rotation_action(session, {:seat_pair, host_id, guest_id}) do
    session
    |> Map.put(:phase, :playing)
    |> Map.put(:active, %{host: host_id, guest: guest_id})
    |> Map.put(:pending_rotation, nil)
  end

  defp next_chouette_start_color(session) do
    next_coup_number = length(session.history) + 1

    if rem(next_coup_number, 2) == 1, do: :white, else: :black
  end

  defp rotation_action_with_start_color({:seat_pair, host_id, guest_id, metadata}, color)
       when color in [:white, :black] do
    {:seat_pair, host_id, guest_id, Map.put(metadata || %{}, :start_color, color)}
  end

  defp rotation_action_with_start_color(action, _color), do: action

  defp pair_ready?(session, {host_id, guest_id}) do
    member_present?(session, host_id) and member_present?(session, guest_id)
  end

  defp member_present?(_session, nil), do: false

  defp member_present?(session, member_id) do
    Enum.any?(session.competitors, &(&1 == member_id))
  end

  defp member_for_side(session, :white), do: session.active.host
  defp member_for_side(session, :black), do: session.active.guest
  defp member_for_side(_session, _side), do: nil

  defp resting_competitor_id(session) do
    session.competitors
    |> Enum.filter(&is_integer/1)
    |> Enum.find(fn member_id -> member_id not in [session.active.host, session.active.guest] end)
  end

  defp side_members(%{mode: :chouette, competitors: [host, guest, bench]}) do
    %{white: [host], black: [guest, bench]}
  end

  defp side_members(%{mode: :deux_contre_deux, competitors: [host, partner, guest, partner2]}) do
    %{white: [host, partner], black: [guest, partner2]}
  end

  defp side_members(_session), do: %{white: [], black: []}

  defp side_for_member(%{mode: :a_tourner}, _member_id), do: nil

  defp side_for_member(session, member_id) do
    cond do
      member_id in Map.get(side_members(session), :white, []) -> :white
      member_id in Map.get(side_members(session), :black, []) -> :black
      true -> nil
    end
  end

  defp partner_id(%{mode: :a_tourner}, _member_id), do: nil

  defp partner_id(session, member_id) do
    session
    |> side_members()
    |> Map.get(side_for_member(session, member_id), [])
    |> Enum.find(&(&1 != member_id))
  end

  defp serialize_participant(_session, {:open_slot, slot_id}) do
    %{
      "kind" => "open_slot",
      "slot_id" => slot_id,
      "role" => "open_slot",
      "side" => nil
    }
  end

  defp serialize_participant(session, member_id) do
    member = session.members[member_id]

    %{
      "kind" => "member",
      "id" => member.id,
      "name" => member.name,
      "connected" => member.connected,
      "role" => serialize_role(member_role(session, member_id)),
      "side" =>
        side_for_member(session, member_id) && Atom.to_string(side_for_member(session, member_id))
    }
  end

  defp serialize_rotation_state(%{mode: :a_tourner} = session) do
    %{
      "resting" => serialize_member(session.members[session.rotation_state.resting_id])
    }
  end

  defp serialize_rotation_state(%{mode: :chouette} = session) do
    order = session.rotation_state.associate_order || []

    %{
      "associate_coups_in_block" => session.rotation_state.associate_coups_in_block || 0,
      "associate_order" => Enum.map(order, &serialize_member(session.members[&1]))
    }
  end

  defp serialize_rotation_state(%{mode: :deux_contre_deux} = session) do
    %{
      "white_partner" =>
        serialize_member(session.members[session.rotation_state.host_partner_id]),
      "black_partner" =>
        serialize_member(session.members[session.rotation_state.guest_partner_id])
    }
  end

  defp serialize_session_winner(%{mode: :a_tourner, winner_id: winner_id} = session)
       when is_integer(winner_id),
       do: serialize_member(session.members[winner_id])

  defp serialize_session_winner(%{side_winner: side}) when side in [:white, :black],
    do: %{"side" => Atom.to_string(side)}

  defp serialize_session_winner(_session), do: nil

  defp serialize_active_member(_session, nil, seat) do
    %{
      "id" => nil,
      "name" => nil,
      "color" => seat_color(seat)
    }
  end

  defp serialize_active_member(session, member_id, seat) do
    member = session.members[member_id]

    %{
      "id" => member.id,
      "name" => member.name,
      "color" => seat_color(seat)
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

  defp serialize_role({:active, _seat}), do: "active"
  defp serialize_role(:bench), do: "bench"
  defp serialize_role(:spectator), do: "spectator"
  defp serialize_role(_role), do: "unknown"

  defp seat_color(:host), do: "white"
  defp seat_color(:guest), do: "black"

  defp status_for_snapshot(_snapshot, %{phase: :waiting_for_players}), do: "waiting_for_players"

  defp status_for_snapshot(_snapshot, %{phase: :awaiting_order_draw}),
    do: "awaiting_order_draw"

  defp status_for_snapshot(_snapshot, %{phase: :awaiting_match_options}),
    do: "awaiting_match_options"

  defp status_for_snapshot(_snapshot, %{phase: :waiting_for_roster_refill}),
    do: "waiting_for_roster_refill"

  defp status_for_snapshot(_snapshot, %{phase: :continuing_honneurs_after_coup}),
    do: "continuing_honneurs_after_coup"

  defp status_for_snapshot(_snapshot, %{phase: :finished}), do: "finished"
  defp status_for_snapshot(snapshot, _session), do: snapshot["status"]

  defp initial_rotation_state(:a_tourner), do: %{resting_id: nil}

  defp initial_rotation_state(:chouette),
    do: %{associate_order: [], associate_index: 0, associate_coups_in_block: 0}

  defp initial_rotation_state(:deux_contre_deux),
    do: %{host_partner_id: nil, guest_partner_id: nil}

  defp put_detection(session, engine) do
    %{
      session
      | detection: %{
          aecrire_coups:
            get_in(engine, [:trictrac, :track_aecrire, :coups_played]) ||
              session.detection.aecrire_coups,
          honneurs_count: honneurs_count(engine),
          resume_pending: get_in(engine, [:trictrac, :suspension_state, :resume_pending]) == true
        }
    }
  end

  defp honneurs_count(engine) do
    classes = get_in(engine, [:trictrac, :track_classique_honneurs, :classes]) || %{}

    [:white, :black]
    |> Enum.map(fn side ->
      side_classes = Map.get(classes, side, Map.get(classes, Atom.to_string(side), %{}))

      Enum.reduce([:simple, :double, :triple, :quadruple], 0, fn key, acc ->
        acc + (Map.get(side_classes, key, Map.get(side_classes, Atom.to_string(key), 0)) || 0)
      end)
    end)
    |> Enum.sum()
  end

  defp current_order_roller_id(%{queue: queue, next_index: next_index}) do
    Enum.at(queue || [], next_index)
  end

  defp competitor_member_ids(session) do
    Enum.filter(session.competitors, &is_integer/1)
  end

  defp competitor_count(session) do
    Enum.count(session.competitors, &is_integer/1)
  end

  defp competitor_member?(session, member_id) do
    Enum.any?(session.competitors, &(&1 == member_id))
  end

  defp new_member(session, user, client_id, auth_id) do
    %{
      id: session.next_member_id,
      name: user,
      client_id: client_id,
      auth_id: auth_id,
      connected: true,
      joined_order: session.next_member_id
    }
  end

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

  defp member_id_to_client(session, member_id), do: session.members[member_id].client_id

  defp add_competitor(session, member_id) do
    if Enum.any?(session.competitors, &open_slot?/1) do
      put_in_first_open_slot(session, member_id)
    else
      update_in(session.competitors, &(&1 ++ [member_id]))
    end
  end

  defp maybe_restore_member_slot(session, member_id) do
    cond do
      not is_nil(member_role(session, member_id)) ->
        session

      Enum.any?(session.competitors, &open_slot?/1) ->
        put_in_first_open_slot(session, member_id)

      true ->
        update_in(session.spectators, fn spectators ->
          if member_id in spectators, do: spectators, else: spectators ++ [member_id]
        end)
    end
  end

  defp reset_preplay_competition(session) do
    %{
      session
      | phase: :waiting_for_players,
        order_draw: nil,
        pending_match_options: nil,
        active: %{host: nil, guest: nil},
        rotation_state: initial_rotation_state(session.mode),
        starting_color: :white,
        partie_length: @default_partie_length
    }
  end

  defp multiplayer_partie_length_consent(session) do
    choices = allowed_partie_lengths(session.mode)

    %{
      "kind" => "multiplayer_partie_length_consent",
      "rule" => "TrictracMultiplayerPartieLengthConsent",
      "prompt" => "Choose the coup length.",
      "choices" => Enum.map(choices, &Integer.to_string/1),
      "choiceLabels" =>
        Enum.into(choices, %{}, fn choice ->
          {Integer.to_string(choice), "#{choice} coups"}
        end),
      "defaultChoice" => Integer.to_string(@default_partie_length),
      "participants" =>
        session.competitors
        |> Enum.filter(&is_integer/1)
        |> Enum.map(fn member_id ->
          member = session.members[member_id]
          %{"id" => member.id, "name" => member.name}
        end),
      "responses" =>
        session.competitors
        |> Enum.filter(&is_integer/1)
        |> Enum.into(%{}, fn member_id -> {Integer.to_string(member_id), nil} end)
    }
  end

  defp allowed_partie_lengths(:a_tourner),
    do: Enum.filter(6..24, &(rem(&1, 3) == 0))

  defp allowed_partie_lengths(:chouette),
    do: Enum.filter(6..24, &(rem(&1, 4) == 0))

  defp allowed_partie_lengths(:deux_contre_deux),
    do: Enum.filter(6..24, &(rem(&1, 2) == 0))

  defp normalize_partie_length_consent(mode, options) do
    with value when not is_nil(value) <-
           Map.get(
             options,
             "aEcrirePartieLengthConsent",
             Map.get(options, :aEcrirePartieLengthConsent)
           ),
         text <- to_string(value),
         {parsed, ""} <- Integer.parse(String.trim(text)),
         true <- parsed in allowed_partie_lengths(mode) do
      {:ok, Integer.to_string(parsed)}
    else
      _ -> {:error, "Choose a valid coup length."}
    end
  end

  defp replace_slot_with_open_slot(session, member_id) do
    open_slot = {:open_slot, session.next_open_slot_id}

    session
    |> update_in([:competitors], fn competitors ->
      Enum.map(competitors, fn
        ^member_id -> open_slot
        other -> other
      end)
    end)
    |> Map.update!(:next_open_slot_id, &(&1 + 1))
  end

  defp put_in_first_open_slot(session, member_id) do
    update_in(session, [:competitors], fn competitors ->
      {updated, _used?} =
        Enum.map_reduce(competitors, false, fn
          {:open_slot, _slot_id}, false -> {member_id, true}
          other, used? -> {other, used?}
        end)

      updated
    end)
  end

  defp open_slot?({:open_slot, _slot_id}), do: true
  defp open_slot?(_entry), do: false

  defp split_integer(_value, 0), do: []

  defp split_integer(value, count) do
    base = div(value, count)
    remainder = rem(value, count)

    Enum.map(0..(count - 1), fn index ->
      if index < abs(remainder) do
        base + if(value >= 0, do: 1, else: -1)
      else
        base
      end
    end)
  end

  defp normalize_order_roll(nil), do: {:ok, :rand.uniform(6)}

  defp normalize_order_roll(value) when is_integer(value) and value in 1..6,
    do: {:ok, value}

  defp normalize_order_roll(_value), do: {:error, "Order draws use a single die from 1 to 6."}

  defp jeton_cash_minor(session, value), do: value * session.cash_per_jeton_minor
  defp fiche_cash_minor(session, value), do: value * session.cash_per_fiche_minor

  defp side_buy_in(session, side) do
    session
    |> side_members()
    |> Map.get(side, [])
    |> length()
    |> Kernel.*(@combine_basket_buy_in)
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

  defp color_atom("white"), do: :white
  defp color_atom("black"), do: :black
  defp color_atom(:white), do: :white
  defp color_atom(:black), do: :black
  defp color_atom(_value), do: :white

  defp opposite(:white), do: :black
  defp opposite(:black), do: :white
end
