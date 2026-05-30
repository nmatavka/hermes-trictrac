defmodule HermesTrictrac.MultiplayerSessionTest do
  use ExUnit.Case, async: true

  alias HermesTrictrac.MultiplayerSession
  alias HermesTrictrac.Rules.{Engine, Registry}

  test "a tourner fills the roster, runs the opening draw, then rotates loser-stays" do
    session = new_session("trictrac_aecrire_a_tourner", %{})

    assert session.cash_per_jeton_minor == 125
    assert session.cash_per_fiche_minor == 1250

    {:ok, session, host_viewer, nil} = MultiplayerSession.join(session, "nick", "c1")
    assert host_viewer["role"] == "bench"
    assert session.phase == :waiting_for_players

    {:ok, session, guest_viewer, nil} = MultiplayerSession.join(session, "jane", "c2")
    assert guest_viewer["role"] == "bench"
    assert session.phase == :waiting_for_players

    {:ok, session, resting_viewer, nil} =
      MultiplayerSession.join(session, "bob", "c3")

    assert resting_viewer["role"] == "bench"
    assert session.phase == :awaiting_order_draw
    assert session.pending_match_options == nil
    assert session.active == %{host: nil, guest: nil}
    assert session.order_draw.queue == [1, 2, 3]
    assert session.order_draw.next_index == 0
    assert MultiplayerSession.viewer(session, "c1")["role"] == "bench"
    assert MultiplayerSession.viewer(session, "c3")["role"] == "bench"

    {:ok, session, nil} = MultiplayerSession.roll_for_order(session, "c1", 6)
    {:ok, session, nil} = MultiplayerSession.roll_for_order(session, "c2", 4)
    {:ok, session, nil} = MultiplayerSession.roll_for_order(session, "c3", 2)

    assert session.phase == :awaiting_match_options
    assert session.active == %{host: 1, guest: 2}
    assert session.rotation_state.resting_id == 3
    assert session.starting_color == :white
    assert session.pending_match_options["kind"] == "multiplayer_partie_length_consent"
    assert session.pending_match_options["defaultChoice"] == "12"
    assert session.pending_match_options["choices"] == ["6", "9", "12", "15", "18", "21", "24"]
    assert session.order_draw.resolved.host_id == 1
    assert session.order_draw.resolved.guest_id == 2
    assert session.order_draw.resolved.resting_id == 3

    {:ok, session, nil} =
      MultiplayerSession.submit_match_options(
        session,
        %{"aEcrirePartieLengthConsent" => "9"},
        "c1"
      )

    {:ok, session, nil} =
      MultiplayerSession.submit_match_options(
        session,
        %{"aEcrirePartieLengthConsent" => "9"},
        "c2"
      )

    {:ok, session, {:start_round, 1, 2}} =
      MultiplayerSession.submit_match_options(
        session,
        %{"aEcrirePartieLengthConsent" => "9"},
        "c3"
      )

    assert session.phase == :playing
    assert session.partie_length == 9
    assert session.pending_match_options == nil

    {:ok, session, {:start_round, 2, 3}} =
      MultiplayerSession.advance(
        session,
        aecrire_coup_engine(1, "white", points_awarded: 8, consolation: 2, multiplier: 1)
      )

    assert session.active == %{host: 2, guest: 3}
    assert session.rotation_state.resting_id == 1
    assert session.a_tourner_ledger[1].jetons == 8
    assert session.a_tourner_ledger[2].jetons == -10
    assert session.a_tourner_ledger[2].coups_lost == 1
    assert session.a_tourner_ledger[3].jetons == 2
    assert List.last(session.history).resting_id == 3
  end

  test "a tourner rerolls only the tied players in the opening draw" do
    session = assembled_session("trictrac_aecrire_a_tourner", ["nick", "jane", "bob"])

    {:ok, session, nil} = MultiplayerSession.roll_for_order(session, "c1", 6)
    {:ok, session, nil} = MultiplayerSession.roll_for_order(session, "c2", 6)
    {:ok, session, nil} = MultiplayerSession.roll_for_order(session, "c3", 3)

    assert session.phase == :awaiting_order_draw
    assert session.order_draw.last_rolls == %{1 => 6, 2 => 6, 3 => 3}
    assert session.order_draw.reroll_ids == [1, 2]
    assert session.order_draw.queue == [1, 2]
    assert session.order_draw.next_index == 0

    {:ok, session, nil} = MultiplayerSession.roll_for_order(session, "c1", 5)
    {:ok, session, nil} = MultiplayerSession.roll_for_order(session, "c2", 2)

    assert session.phase == :awaiting_match_options
    assert session.active == %{host: 1, guest: 2}
    assert session.rotation_state.resting_id == 3
  end

  test "a tourner finalizes queue des jetons from raw jetons before paris" do
    session =
      started_session("trictrac_aecrire_a_tourner", ["nick", "jane", "bob"], %{partie_length: "9"})

    session = %{
      session
      | history: Enum.map(1..8, &%{coup: &1}),
        a_tourner_ledger: %{
          1 => %{
            id: 1,
            name: "nick",
            joined_order: 1,
            coups_lost: 4,
            jetons: 5,
            resting_consolation: 0,
            paris_net: 0,
            queue_paris: 0,
            queue_jetons: 0,
            final_total: 0
          },
          2 => %{
            id: 2,
            name: "jane",
            joined_order: 2,
            coups_lost: 0,
            jetons: 4,
            resting_consolation: 0,
            paris_net: 0,
            queue_paris: 0,
            queue_jetons: 0,
            final_total: 0
          },
          3 => %{
            id: 3,
            name: "bob",
            joined_order: 3,
            coups_lost: 4,
            jetons: 0,
            resting_consolation: 0,
            paris_net: 0,
            queue_paris: 0,
            queue_jetons: 0,
            final_total: 0
          }
        }
    }

    {:ok, session, nil} =
      MultiplayerSession.advance(
        session,
        aecrire_coup_engine(9, "white", points_awarded: 0, consolation: 0, multiplier: 1)
      )

    assert session.phase == :finished
    assert session.winner_id == 2
    assert session.a_tourner_ledger[1].queue_jetons == 9
    assert session.a_tourner_ledger[2].queue_jetons == 0
    assert session.a_tourner_ledger[2].queue_paris == 20
    assert session.a_tourner_ledger[2].final_total == 40
  end

  test "a tourner keeps the winner's consolation inside points_awarded and only adds the resting share" do
    session =
      started_session("trictrac_aecrire_a_tourner", ["nick", "jane", "bob"], %{partie_length: "9"})

    {:ok, session, {:start_round, 2, 3}} =
      MultiplayerSession.advance(
        session,
        aecrire_coup_engine(1, "white", points_awarded: 8, consolation: 2, multiplier: 1)
      )

    assert session.a_tourner_ledger[1].jetons == 8
    assert session.a_tourner_ledger[2].jetons == -10
    assert session.a_tourner_ledger[3].jetons == 2
    assert session.a_tourner_ledger[3].resting_consolation == 2
  end

  test "a tourner splits queue des jetons across tied raw leaders" do
    session =
      started_session("trictrac_aecrire_a_tourner", ["nick", "jane", "bob"], %{partie_length: "9"})

    session = %{
      session
      | history: Enum.map(1..8, &%{coup: &1}),
        a_tourner_ledger: %{
          1 => %{
            id: 1,
            name: "nick",
            joined_order: 1,
            coups_lost: 2,
            jetons: 10,
            resting_consolation: 0,
            paris_net: 0,
            queue_paris: 0,
            queue_jetons: 0,
            final_total: 0
          },
          2 => %{
            id: 2,
            name: "jane",
            joined_order: 2,
            coups_lost: 2,
            jetons: 10,
            resting_consolation: 0,
            paris_net: 0,
            queue_paris: 0,
            queue_jetons: 0,
            final_total: 0
          },
          3 => %{
            id: 3,
            name: "bob",
            joined_order: 3,
            coups_lost: 4,
            jetons: 0,
            resting_consolation: 0,
            paris_net: 0,
            queue_paris: 0,
            queue_jetons: 0,
            final_total: 0
          }
        }
    }

    {:ok, session, nil} =
      MultiplayerSession.advance(
        session,
        aecrire_coup_engine(9, "white", points_awarded: 0, consolation: 0, multiplier: 1)
      )

    assert session.phase == :finished
    assert session.a_tourner_ledger[1].queue_jetons == 5
    assert session.a_tourner_ledger[2].queue_jetons == 4
    assert session.a_tourner_ledger[3].queue_jetons == 0
  end

  test "a tourner scales queue des jetons to the configured coup count" do
    session =
      started_session("trictrac_aecrire_a_tourner", ["nick", "jane", "bob"], %{
        partie_length: "15"
      })

    session = %{
      session
      | history: Enum.map(1..14, &%{coup: &1}),
        a_tourner_ledger: %{
          1 => %{
            id: 1,
            name: "nick",
            joined_order: 1,
            coups_lost: 5,
            jetons: 11,
            resting_consolation: 0,
            paris_net: 0,
            queue_paris: 0,
            queue_jetons: 0,
            final_total: 0
          },
          2 => %{
            id: 2,
            name: "jane",
            joined_order: 2,
            coups_lost: 2,
            jetons: 11,
            resting_consolation: 0,
            paris_net: 0,
            queue_paris: 0,
            queue_jetons: 0,
            final_total: 0
          },
          3 => %{
            id: 3,
            name: "bob",
            joined_order: 3,
            coups_lost: 7,
            jetons: 3,
            resting_consolation: 0,
            paris_net: 0,
            queue_paris: 0,
            queue_jetons: 0,
            final_total: 0
          }
        }
    }

    {:ok, session, nil} =
      MultiplayerSession.advance(
        session,
        aecrire_coup_engine(15, "white", points_awarded: 0, consolation: 0, multiplier: 1)
      )

    assert session.phase == :finished
    assert session.a_tourner_ledger[1].queue_jetons == 8
    assert session.a_tourner_ledger[2].queue_jetons == 7
    assert session.a_tourner_ledger[3].queue_jetons == 0
  end

  test "chouette opening draw chooses the first associate block and rotation still advances every two coups" do
    session = assembled_session("trictrac_aecrire_chouette", ["nick", "jane", "bob"])
    session = resolve_order_draw!(session, [{"c2", 2}, {"c3", 6}])

    assert session.phase == :awaiting_match_options
    assert session.active == %{host: 1, guest: 3}
    assert session.rotation_state.associate_order == [3, 2]
    assert session.starting_color == :white

    session = consent_session!(session, "12")

    {:ok, session, {:seat_pair, 1, 3, %{associate_coups_in_block: 1}}} =
      MultiplayerSession.advance(session, aecrire_coup_engine(1, "white"))

    assert session.active == %{host: 1, guest: 3}
    assert session.rotation_state.associate_index == 0
    assert session.rotation_state.associate_coups_in_block == 1
    assert session.pending_rotation == nil
    assert session.rotation_state.start_color == :black

    {:ok, session,
     {:seat_pair, 1, 2, %{associate_index: 1, associate_coups_in_block: 0, start_color: :white}}} =
      MultiplayerSession.advance(session, aecrire_coup_engine(2, "black"))

    assert session.active == %{host: 1, guest: 2}
    assert session.rotation_state.associate_index == 1
    assert session.rotation_state.associate_coups_in_block == 0
    assert session.rotation_state.start_color == :white
  end

  test "chouette rotation actions apply the live die ownership across three coups" do
    session = assembled_session("trictrac_aecrire_chouette", ["nick", "jane", "bob"])
    session = resolve_order_draw!(session, default_order_draw_rolls("trictrac_aecrire_chouette"))
    {session, start_action} = consent_session_with_action!(session, "12")
    engine = apply_session_action(engine_for(session), session, start_action)

    assert engine.turn_color == :white

    {:ok, session, action} = MultiplayerSession.advance(session, aecrire_coup_engine(1, "white"))
    engine = apply_session_action(engine, session, action)

    assert engine.turn_color == :black
    assert get_in(engine, [:trictrac, :track_aecrire, :coup_starter]) == :black

    {:ok, session, action} = MultiplayerSession.advance(session, aecrire_coup_engine(2, "black"))
    engine = apply_session_action(engine, session, action)

    assert engine.turn_color == :white
    assert get_in(engine, [:trictrac, :track_aecrire, :coup_starter]) == :white
  end

  test "deux contre deux opening draw chooses side leaders and the opening side" do
    session =
      assembled_session(
        "trictrac_aecrire_deux_contre_deux",
        ["amelie", "benoit", "claire", "didier"]
      )

    session =
      resolve_order_draw!(session, [
        {"c1", 2},
        {"c2", 6},
        {"c3", 5},
        {"c4", 1},
        {"c2", 3},
        {"c3", 6}
      ])

    assert session.phase == :awaiting_match_options
    assert session.active == %{host: 2, guest: 3}
    assert session.rotation_state.host_partner_id == 1
    assert session.rotation_state.guest_partner_id == 4
    assert session.starting_color == :black
  end

  test "deux contre deux gives the die to the marked player who stays" do
    session =
      started_session(
        "trictrac_aecrire_deux_contre_deux",
        ["amelie", "benoit", "claire", "didier"]
      )

    {:ok, session, {:seat_pair, 2, 3, %{start_color: :black}}} =
      MultiplayerSession.advance(session, aecrire_coup_engine(1, "white"))

    assert session.active == %{host: 2, guest: 3}
    assert session.rotation_state.start_color == :black

    {:ok, session, {:seat_pair, 2, 4, %{start_color: :white}}} =
      MultiplayerSession.advance(session, aecrire_coup_engine(2, "black"))

    assert session.active == %{host: 2, guest: 4}
    assert session.rotation_state.start_color == :white
  end

  test "deux contre deux rotation actions apply the staying player's die to the live engine" do
    session =
      assembled_session(
        "trictrac_aecrire_deux_contre_deux",
        ["amelie", "benoit", "claire", "didier"]
      )

    session =
      resolve_order_draw!(session, default_order_draw_rolls("trictrac_aecrire_deux_contre_deux"))

    {session, start_action} = consent_session_with_action!(session, "12")
    engine = apply_session_action(engine_for(session), session, start_action)

    assert engine.turn_color == :white

    {:ok, session, action} = MultiplayerSession.advance(session, aecrire_coup_engine(1, "white"))
    engine = apply_session_action(engine, session, action)

    assert engine.turn_color == :black
    assert get_in(engine, [:trictrac, :track_aecrire, :coup_starter]) == :black

    {:ok, session, action} = MultiplayerSession.advance(session, aecrire_coup_engine(2, "black"))
    engine = apply_session_action(engine, session, action)

    assert engine.turn_color == :white
    assert get_in(engine, [:trictrac, :track_aecrire, :coup_starter]) == :white
  end

  test "spectators can claim an open roster slot and the table reruns preplay" do
    session = started_session("trictrac_aecrire_chouette", ["nick", "jane", "bob"])
    {:ok, session, spectator_viewer, nil} = MultiplayerSession.join(session, "dana", "c4")

    assert spectator_viewer["role"] == "spectator"
    assert spectator_viewer["can_claim_roster_slot"] == false

    {:ok, session, nil} = MultiplayerSession.leave(session, "c3")

    assert session.competitors == [1, 2, {:open_slot, 1}]
    assert session.phase == :playing
    assert MultiplayerSession.viewer(session, "c4")["can_claim_roster_slot"] == true

    {:ok, session, claimed_viewer, nil} = MultiplayerSession.claim_roster_slot(session, "c4")

    assert claimed_viewer["role"] == "bench"
    assert session.competitors == [1, 2, 4]
    assert session.phase == :playing
    assert session.spectators == []
  end

  test "same auth_id rejoin updates the existing multiplayer member instead of creating a duplicate" do
    session = new_session("trictrac_aecrire_chouette", %{})

    {:ok, session, _viewer, nil} =
      MultiplayerSession.join(session, "alice.bsky.social", "c1", "did:plc:alice")

    {:ok, session, viewer, _action} =
      MultiplayerSession.join(session, "alice-renamed.bsky.social", "c2", "did:plc:alice")

    assert map_size(session.members) == 1
    assert session.member_ids_by_client["c1"] == nil
    assert session.member_ids_by_client["c2"] == 1
    assert session.members[1].name == "alice-renamed.bsky.social"
    assert session.members[1].client_id == "c2"
    assert session.members[1].auth_id == "did:plc:alice"
    assert viewer["id"] == 1
  end

  test "combine basket captures after two consecutive honneurs wins" do
    session = started_session("trictrac_combine_chouette", ["nick", "jane", "bob"])

    assert session.combine_poule.basket == 6

    {:ok, session, nil} =
      MultiplayerSession.advance(session, combine_partie_engine(1, "white", 2))

    assert session.combine_poule.basket == 8
    assert session.combine_poule.contract_side == :white
    assert session.combine_poule.first_winner_side == :white

    {:ok, session, nil} =
      MultiplayerSession.advance(session, combine_partie_engine(2, "white", 4))

    assert session.combine_poule.last_capture_side == :white
    assert session.combine_poule.last_capture_amount == 12
    assert session.combine_poule.basket == 6
    assert session.combine_poule.cycle == 2
    assert session.combine_poule.side_stats.white.basket_won == 12
  end

  test "combine final-coup odd basket split preserves the started basket rights" do
    session = started_session("trictrac_combine_chouette", ["nick", "jane", "bob"])

    {:ok, session, nil} =
      MultiplayerSession.advance(session, combine_partie_engine(1, "white", 3))

    session = %{session | history: Enum.map(1..11, &%{coup: &1})}

    {:ok, session, nil} =
      MultiplayerSession.advance(session, combine_partie_engine(2, "black", 4))

    assert session.combine_poule.basket == 0
    assert session.combine_poule.side_stats.white.basket_won == 10
    assert session.combine_poule.side_stats.black.basket_won == 3
    assert session.combine_poule.last_capture_side == nil
    assert session.combine_poule.last_capture_amount == 13
  end

  test "combine final-coup even basket split still divides the whole basket" do
    session = started_session("trictrac_combine_chouette", ["nick", "jane", "bob"])

    {:ok, session, nil} =
      MultiplayerSession.advance(session, combine_partie_engine(1, "white", 2))

    session = %{session | history: Enum.map(1..11, &%{coup: &1})}

    {:ok, session, nil} =
      MultiplayerSession.advance(session, combine_partie_engine(2, "black", 4))

    assert session.combine_poule.basket == 0
    assert session.combine_poule.side_stats.white.basket_won == 6
    assert session.combine_poule.side_stats.black.basket_won == 6
    assert session.combine_poule.last_capture_side == nil
    assert session.combine_poule.last_capture_amount == 12
  end

  test "combine delays seat handoff until honneurs continuation ends" do
    session = started_session("trictrac_combine_chouette", ["nick", "jane", "bob"])

    {:ok, session, {:seat_pair, 1, 2, %{associate_coups_in_block: 1}}} =
      MultiplayerSession.advance(session, combine_coup_engine(1, resume_pending: false))

    {:ok, session, nil} =
      MultiplayerSession.advance(
        session,
        combine_coup_engine(2, winner: "white", resume_pending: true, suspended_track: "a_ecrire")
      )

    assert session.phase == :continuing_honneurs_after_coup

    assert session.pending_rotation ==
             {:seat_pair, 1, 3,
              %{associate_index: 1, associate_coups_in_block: 0, start_color: :white}}

    assert session.active == %{host: 1, guest: 2}

    {:ok, session,
     {:seat_pair, 1, 3, %{associate_index: 1, associate_coups_in_block: 0, start_color: :black}}} =
      MultiplayerSession.advance(
        session,
        combine_coup_engine(2,
          winner: "white",
          resume_pending: false,
          suspended_track: "a_ecrire",
          turn_color: :black
        )
      )

    assert session.phase == :playing
    assert session.active == %{host: 1, guest: 3}
    assert session.pending_rotation == nil
    assert session.rotation_state.start_color == :black
  end

  test "combine delayed handoff applies the continuing player's live die to the resumed pair" do
    session = assembled_session("trictrac_combine_chouette", ["nick", "jane", "bob"])
    session = resolve_order_draw!(session, default_order_draw_rolls("trictrac_combine_chouette"))
    {session, start_action} = consent_session_with_action!(session, "12")
    engine = apply_session_action(engine_for(session), session, start_action)

    assert engine.turn_color == :white

    {:ok, session, action} =
      MultiplayerSession.advance(session, combine_coup_engine(1, resume_pending: false))

    engine = apply_session_action(engine, session, action)
    assert engine.turn_color == :black

    {:ok, session, nil} =
      MultiplayerSession.advance(
        session,
        combine_coup_engine(2, winner: "white", resume_pending: true, suspended_track: "a_ecrire")
      )

    {:ok, session, action} =
      MultiplayerSession.advance(
        session,
        combine_coup_engine(2,
          winner: "white",
          resume_pending: false,
          suspended_track: "a_ecrire",
          turn_color: :black
        )
      )

    engine = apply_session_action(engine, session, action)

    assert engine.turn_color == :black
    assert get_in(engine, [:trictrac, :track_aecrire, :coup_starter]) == :black
  end

  test "multiplayer longueur disagreement falls back to 12 coups after the draw resolves" do
    session = assembled_session("trictrac_aecrire_chouette", ["nick", "jane", "bob"])
    session = resolve_order_draw!(session, default_order_draw_rolls("trictrac_aecrire_chouette"))

    {:ok, session, nil} =
      MultiplayerSession.submit_match_options(
        session,
        %{"aEcrirePartieLengthConsent" => "8"},
        "c1"
      )

    {:ok, session, nil} =
      MultiplayerSession.submit_match_options(
        session,
        %{"aEcrirePartieLengthConsent" => "12"},
        "c2"
      )

    {:ok, session, {:start_round, 1, 2}} =
      MultiplayerSession.submit_match_options(
        session,
        %{"aEcrirePartieLengthConsent" => "16"},
        "c3"
      )

    assert session.phase == :playing
    assert session.partie_length == 12
    assert session.pending_match_options == nil
  end

  defp new_session(variant_id, opts) do
    variant = Registry.fetch!(variant_id)

    {:ok, session} =
      MultiplayerSession.new(variant, Map.put_new(opts, "cash_per_jeton_minor", 125))

    session
  end

  defp assembled_session(variant_id, names, opts \\ %{}) do
    session = new_session(variant_id, drop_partie_length_opt(opts))

    Enum.with_index(names, 1)
    |> Enum.reduce(session, fn {name, index}, session_acc ->
      {:ok, next_session, _viewer, _action} =
        MultiplayerSession.join(session_acc, name, "c#{index}")

      next_session
    end)
  end

  defp started_session(variant_id, names, opts \\ %{}) do
    partie_length =
      opts
      |> Map.get(:partie_length, Map.get(opts, "partie_length", "12"))
      |> to_string()

    session =
      variant_id
      |> assembled_session(names, opts)
      |> resolve_order_draw!(default_order_draw_rolls(variant_id))

    consent_session!(session, partie_length)
  end

  defp consent_session!(session, partie_length) do
    competitor_client_ids =
      session.competitors
      |> Enum.filter(&is_integer/1)
      |> Enum.map(fn member_id -> "c#{member_id}" end)

    Enum.reduce(competitor_client_ids, session, fn client_id, session_acc ->
      {:ok, next_session, _action} =
        MultiplayerSession.submit_match_options(
          session_acc,
          %{"aEcrirePartieLengthConsent" => partie_length},
          client_id
        )

      next_session
    end)
  end

  defp consent_session_with_action!(session, partie_length) do
    competitor_client_ids =
      session.competitors
      |> Enum.filter(&is_integer/1)
      |> Enum.map(fn member_id -> "c#{member_id}" end)

    Enum.reduce(competitor_client_ids, {session, nil}, fn client_id, {session_acc, _action_acc} ->
      {:ok, next_session, next_action} =
        MultiplayerSession.submit_match_options(
          session_acc,
          %{"aEcrirePartieLengthConsent" => partie_length},
          client_id
        )

      {next_session, next_action}
    end)
  end

  defp resolve_order_draw!(session, rolls) do
    Enum.reduce(rolls, session, fn {client_id, value}, session_acc ->
      {:ok, next_session, _action} =
        MultiplayerSession.roll_for_order(session_acc, client_id, value)

      next_session
    end)
  end

  defp default_order_draw_rolls(variant_id) do
    case Registry.fetch!(variant_id).session_style do
      :a_tourner ->
        [{"c1", 6}, {"c2", 4}, {"c3", 2}]

      :chouette ->
        [{"c2", 6}, {"c3", 4}]

      :deux_contre_deux ->
        [{"c1", 6}, {"c2", 4}, {"c3", 5}, {"c4", 3}, {"c1", 6}, {"c3", 5}]
    end
  end

  defp drop_partie_length_opt(opts) do
    Map.drop(opts, [:partie_length, "partie_length"])
  end

  defp engine_for(session), do: Engine.new("multiplayer-session-test", session.base_variant_id)

  defp apply_session_action(engine, session, {:start_round, _host_id, _guest_id}) do
    Engine.force_start_turn(engine, MultiplayerSession.round_start_color(session))
  end

  defp apply_session_action(engine, _session, {:seat_pair, _host_id, _guest_id, metadata}) do
    Engine.force_coup_starter(engine, Map.fetch!(metadata, :start_color))
  end

  defp apply_session_action(engine, _session, {:seat_pair, _host_id, _guest_id}) do
    engine
  end

  defp aecrire_coup_engine(coups_played, winner, opts \\ []) do
    %{
      trictrac: %{
        track_aecrire: %{
          coups_played: coups_played,
          last_marque_result: %{
            "winner" => winner,
            "points_awarded" => Keyword.get(opts, :points_awarded, 6),
            "consolation" => Keyword.get(opts, :consolation, 2),
            "multiplier" => Keyword.get(opts, :multiplier, 1)
          }
        },
        suspension_state: %{
          resume_pending: Keyword.get(opts, :resume_pending, false),
          suspended_track: Keyword.get(opts, :suspended_track)
        }
      },
      match: %{
        is_over: Keyword.get(opts, :is_over, false)
      }
    }
  end

  defp combine_coup_engine(coups_played, opts) do
    engine =
      aecrire_coup_engine(coups_played, Keyword.get(opts, :winner, "white"),
        resume_pending: Keyword.get(opts, :resume_pending, false),
        suspended_track: Keyword.get(opts, :suspended_track),
        points_awarded: Keyword.get(opts, :points_awarded, 6),
        consolation: Keyword.get(opts, :consolation, 2),
        multiplier: Keyword.get(opts, :multiplier, 1)
      )

    engine
    |> put_in([:trictrac, :track_classique_honneurs], %{
      classes: %{
        "white" => %{"simple" => 0, "double" => 0, "triple" => 0, "quadruple" => 0},
        "black" => %{"simple" => 0, "double" => 0, "triple" => 0, "quadruple" => 0}
      },
      last_partie_result: %{}
    })
    |> Map.put(:turn_color, Keyword.get(opts, :turn_color))
  end

  defp combine_partie_engine(partie_count, winner, value) do
    loser = if winner == "white", do: "black", else: "white"

    %{
      trictrac: %{
        track_aecrire: %{coups_played: 0, last_marque_result: %{}},
        suspension_state: %{resume_pending: false, suspended_track: nil},
        track_classique_honneurs: %{
          classes: %{
            winner => %{"simple" => partie_count, "double" => 0, "triple" => 0, "quadruple" => 0},
            loser => %{"simple" => 0, "double" => 0, "triple" => 0, "quadruple" => 0}
          },
          last_partie_result: %{"winner" => winner, "value" => value}
        }
      },
      match: %{is_over: false}
    }
  end
end
