defmodule HermesTrictrac.SnapshotContractTest do
  use ExUnit.Case, async: true

  alias HermesTrictrac.GameSnapshot
  alias HermesTrictrac.{MultiplayerSession, PouleSession}
  alias HermesTrictrac.Rules.{Engine, Registry}

  defp ready_engine(lobby, variant_id) do
    engine = Engine.new(lobby, variant_id)
    {:ok, engine, _} = Engine.join(engine, "nick", "tab-a")
    {:ok, engine, _} = Engine.join(engine, "jane", "tab-b")
    engine
  end

  test "backgammon snapshot exposes the mobile contract root fields" do
    snapshot =
      ready_engine("android-contract-bg", "backgammon")
      |> Engine.snapshot()

    assert Map.keys(snapshot) |> Enum.sort() == [
             "board",
             "dice",
             "last_move",
             "last_moves",
             "legal_moves",
             "match",
             "opening_roll",
             "pending_match_options",
             "pending_turn_decision",
             "players",
             "status",
             "trictrac",
             "turn",
             "ui_actions",
             "variant"
           ]

    assert snapshot["variant"]["id"] == "backgammon"
    assert is_list(snapshot["board"]["points"])
    assert is_map(snapshot["board"]["bar"])
    assert is_map(snapshot["board"]["outside"])
    assert is_list(snapshot["legal_moves"])
    assert is_map(snapshot["match"])
    assert is_map(snapshot["ui_actions"])
  end

  test "trictrac aecrire snapshot exposes pending options and trictrac state" do
    snapshot =
      ready_engine("android-contract-tt", "trictrac_aecrire")
      |> Engine.snapshot()

    assert snapshot["variant"]["id"] == "trictrac_aecrire"
    assert snapshot["pending_match_options"]["kind"] == "trictrac_partie_length_consent"
    assert is_map(snapshot["trictrac"])
    assert snapshot["ui_actions"]["can_submit_match_options"] == true
    assert snapshot["pending_turn_decision"] == nil
  end

  test "game snapshot layering exposes chat bot and seat reclaim fields" do
    layered_snapshot =
      ready_engine("android-contract-layering", "backgammon")
      |> Engine.snapshot()
      |> GameSnapshot.with_chat([
        %{"author" => "white", "type" => "text", "data" => %{"text" => "hello"}}
      ])
      |> GameSnapshot.with_bot(%{
        kind: "backgammon_ai",
        name: "BackgammonAI",
        color: :black
      })
      |> GameSnapshot.with_seat_reclaim(%{
        seat_color: :white,
        defender_name: "nick",
        claimant_name: "nick",
        expires_at_ms: 1_700_000_000_000
      })

    assert layered_snapshot["chat"] == [
             %{"author" => "white", "type" => "text", "data" => %{"text" => "hello"}}
           ]

    assert layered_snapshot["bot"] == %{
             "enabled" => true,
             "kind" => "backgammon_ai",
             "name" => "BackgammonAI",
             "color" => "black"
           }

    assert layered_snapshot["seat_reclaim"] == %{
             "seat_color" => :white,
             "defender_name" => "nick",
             "claimant_name" => "nick",
             "expires_at_ms" => 1_700_000_000_000
           }
  end

  test "poule snapshot layering exposes session and viewer metadata" do
    variant = Registry.fetch!("trictrac_en_poule")

    {:ok, session} =
      PouleSession.new(variant, %{"queue_size" => "1", "ante" => "3", "margot_enabled" => "true"})

    {:ok, session, _viewer, nil} = PouleSession.join(session, "nick", "seat-a")
    {:ok, session, _viewer, nil} = PouleSession.join(session, "jane", "seat-b")

    {:ok, session, _viewer, {:start_round, host_id, guest_id}} =
      PouleSession.join(session, "bob", "seat-c")

    engine =
      Engine.new("android-contract-poule", "trictrac_classique")
      |> Engine.seed_match_options(PouleSession.round_options(session))

    {:ok, engine, _} =
      Engine.join(engine, session.members[host_id].name, session.members[host_id].client_id)

    {:ok, engine, _} =
      Engine.join(engine, session.members[guest_id].name, session.members[guest_id].client_id)

    active_host_name = session.members[session.active.host].name
    active_guest_name = session.members[session.active.guest].name
    draw_order_names = Enum.map(session.draw_order, &session.members[&1].name)
    host_client_id = session.members[session.active.host].client_id

    layered_snapshot =
      engine
      |> Engine.snapshot()
      |> PouleSession.inject_snapshot(session)
      |> GameSnapshot.with_viewer(PouleSession.viewer(session, host_client_id))

    assert layered_snapshot["variant"]["id"] == "trictrac_en_poule"
    assert layered_snapshot["variant"]["active_variant_id"] == "trictrac_classique"
    assert layered_snapshot["status"] == "playing"
    assert layered_snapshot["poule"]["style"] == "growing_pot"
    assert layered_snapshot["players"]["host"]["name"] == active_host_name
    assert layered_snapshot["players"]["guest"]["name"] == active_guest_name

    assert layered_snapshot["poule"]["config"] == %{
             "queue_size" => 1,
             "competitor_target" => 3,
             "ante" => 3,
             "margot_enabled" => true,
             "style" => "growing_pot",
             "win_target" => 3,
             "base_variant_id" => "trictrac_classique",
             "base_variant_title" => Registry.fetch!("trictrac_classique").title
           }

    assert Enum.sort(draw_order_names) == ["bob", "jane", "nick"]
    assert Enum.map(layered_snapshot["poule"]["draw_order"], & &1["name"]) == draw_order_names
    assert Enum.take(draw_order_names, 2) == [active_host_name, active_guest_name]

    assert Enum.map(layered_snapshot["poule"]["queue"], & &1["name"]) ==
             Enum.drop(draw_order_names, 2)

    assert layered_snapshot["viewer"]["role"] == "active"
    assert layered_snapshot["viewer"]["seat"] == "host"
    assert layered_snapshot["viewer"]["seat_color"] == "white"
  end

  test "plucked poule snapshot layering exposes fixed-fund config" do
    variant = Registry.fetch!("trictrac_en_poule_plumee")

    {:ok, session} =
      PouleSession.new(variant, %{
        "queue_size" => "1",
        "stake" => "50",
        "hole_value" => "5",
        "margot_enabled" => "true"
      })

    {:ok, session, _viewer, nil} = PouleSession.join(session, "nick", "seat-a")
    {:ok, session, _viewer, nil} = PouleSession.join(session, "jane", "seat-b")

    {:ok, session, _viewer, {:start_round, host_id, guest_id}} =
      PouleSession.join(session, "bob", "seat-c")

    engine =
      Engine.new("android-contract-plucked-poule", "trictrac_classique")
      |> Engine.seed_match_options(PouleSession.round_options(session))

    {:ok, engine, _} =
      Engine.join(engine, session.members[host_id].name, session.members[host_id].client_id)

    {:ok, engine, _} =
      Engine.join(engine, session.members[guest_id].name, session.members[guest_id].client_id)

    host_client_id = session.members[session.active.host].client_id

    layered_snapshot =
      engine
      |> Engine.snapshot()
      |> PouleSession.inject_snapshot(session)
      |> GameSnapshot.with_viewer(PouleSession.viewer(session, host_client_id))

    assert layered_snapshot["variant"]["id"] == "trictrac_en_poule_plumee"
    assert layered_snapshot["variant"]["active_variant_id"] == "trictrac_classique"
    assert layered_snapshot["poule"]["style"] == "plucked_pot"
    assert layered_snapshot["poule"]["config"]["stake"] == 50
    assert layered_snapshot["poule"]["config"]["hole_value"] == 5
    assert layered_snapshot["poule"]["config"]["queue_size"] == 1
    assert layered_snapshot["poule"]["config"]["competitor_target"] == 3
    assert layered_snapshot["poule"]["pool"] == 150

    assert Enum.sort(Enum.map(layered_snapshot["poule"]["draw_order"], & &1["name"])) == [
             "bob",
             "jane",
             "nick"
           ]

    assert layered_snapshot["viewer"]["role"] == "active"
  end

  test "multiplayer snapshot layering exposes roster and bench viewer metadata" do
    variant = Registry.fetch!("trictrac_aecrire_chouette")

    {:ok, session} = MultiplayerSession.new(variant, %{"cash_per_jeton_minor" => "125"})
    {:ok, session, _viewer, nil} = MultiplayerSession.join(session, "nick", "seat-a")
    {:ok, session, _viewer, nil} = MultiplayerSession.join(session, "jane", "seat-b")

    {:ok, session, _viewer, nil} =
      MultiplayerSession.join(session, "bob", "seat-c")

    engine = Engine.new("android-contract-multiplayer", "trictrac_aecrire")

    layered_snapshot =
      engine
      |> Engine.snapshot()
      |> MultiplayerSession.inject_snapshot(session)
      |> GameSnapshot.with_viewer(MultiplayerSession.viewer(session, "seat-c"))

    assert layered_snapshot["variant"]["id"] == "trictrac_aecrire_chouette"
    assert layered_snapshot["variant"]["active_variant_id"] == "trictrac_aecrire"
    assert layered_snapshot["status"] == "awaiting_order_draw"
    assert layered_snapshot["players"]["host"]["name"] == nil
    assert layered_snapshot["players"]["guest"]["name"] == nil
    assert layered_snapshot["pending_match_options"] == nil
    assert layered_snapshot["ui_actions"]["can_submit_match_options"] == false
    assert layered_snapshot["ui_actions"]["can_roll_for_order"] == true

    assert layered_snapshot["multiplayer"]["kind"] == "multiplayer"
    assert layered_snapshot["multiplayer"]["mode"] == "chouette"
    assert layered_snapshot["multiplayer"]["competitor_target"] == 3
    assert layered_snapshot["multiplayer"]["partie_length"] == 12
    assert layered_snapshot["multiplayer"]["awaiting_match_options"] == false
    assert layered_snapshot["multiplayer"]["order_draw"]["step"] == "associates"
    assert layered_snapshot["multiplayer"]["order_draw"]["current_roller"]["name"] == "jane"

    assert layered_snapshot["multiplayer"]["accounting"] == %{
             "cash_per_jeton_minor" => 125,
             "cash_per_fiche_minor" => 1250,
             "cash_minor_scale" => 100
           }

    assert Enum.map(layered_snapshot["multiplayer"]["participants"], & &1["name"]) == [
             "nick",
             "jane",
             "bob"
           ]

    assert layered_snapshot["viewer"]["role"] == "bench"
    assert layered_snapshot["viewer"]["can_claim_roster_slot"] == false
  end
end
