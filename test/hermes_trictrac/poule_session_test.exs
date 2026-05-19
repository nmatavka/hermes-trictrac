defmodule HermesTrictrac.PouleSessionTest do
  use ExUnit.Case, async: true

  alias HermesTrictrac.PouleSession
  alias HermesTrictrac.Rules.Registry

  test "fills the competitor roster, starts play, and charges the opening ante once" do
    session = new_growing_session(queue_size: 1, ante: 4, margot_enabled: true)

    {:ok, session, host_viewer, nil} = PouleSession.join(session, "nick", "c1")
    assert host_viewer["role"] == "queued"
    assert session.phase == :waiting_for_competitors

    {:ok, session, guest_viewer, nil} = PouleSession.join(session, "jane", "c2")
    assert guest_viewer["role"] == "queued"
    assert session.phase == :waiting_for_competitors

    {:ok, session, queued_viewer, {:start_round, host_id, guest_id}} =
      PouleSession.join(session, "bob", "c3")

    assert queued_viewer["role"] in ["active", "queued"]
    assert session.phase == :playing
    assert session.active == %{host: host_id, guest: guest_id}
    assert Enum.sort(session.draw_order) == [1, 2, 3]
    assert Enum.take(session.draw_order, 2) == [session.active.host, session.active.guest]
    assert session.queue == Enum.drop(session.draw_order, 2)
    assert session.pool == 12
    assert session.members[1].contributed == 4
    assert session.members[2].contributed == 4
    assert session.members[3].contributed == 4
    assert session.members[host_id].active_entries == 1
    assert session.members[guest_id].active_entries == 1

    queued_ids = Enum.drop(session.draw_order, 2)

    Enum.each(queued_ids, fn member_id ->
      assert session.members[member_id].active_entries == 0
    end)

    host_client_id = session.members[host_id].client_id
    guest_client_id = session.members[guest_id].client_id
    assert PouleSession.viewer(session, host_client_id)["role"] == "active"
    assert PouleSession.viewer(session, host_client_id)["seat"] == "host"
    assert PouleSession.viewer(session, guest_client_id)["seat"] == "guest"
  end

  test "winner-stays rotation charges re-entry ante and ends at the streak target" do
    session = started_growing_session(queue_size: 1, ante: 5)
    initial_winner_id = session.active.host
    initial_loser_id = session.active.guest
    first_entrant_id = hd(session.queue)

    {:ok, session, {:start_round, next_host_id, next_guest_id}} =
      PouleSession.record_round(session, round_engine("white"))

    assert {next_host_id, next_guest_id} == {initial_winner_id, first_entrant_id}
    assert session.active == %{host: initial_winner_id, guest: first_entrant_id}
    assert session.queue == [initial_loser_id]
    assert session.pool == 15
    assert session.streak == 1
    assert List.last(session.history).entrant_id == first_entrant_id
    refute List.last(session.history).ante_paid_on_entry

    {:ok, session, {:start_round, final_host_id, final_guest_id}} =
      PouleSession.record_round(session, round_engine("white"))

    assert {final_host_id, final_guest_id} == {initial_winner_id, initial_loser_id}
    assert session.active == %{host: initial_winner_id, guest: initial_loser_id}
    assert session.queue == [first_entrant_id]
    assert session.pool == 20
    assert session.streak == 2
    assert session.members[initial_loser_id].contributed == 10
    assert List.last(session.history).entrant_id == initial_loser_id
    assert List.last(session.history).ante_paid_on_entry

    {:ok, session, :finished} = PouleSession.record_round(session, round_engine("white"))

    assert session.phase == :finished
    assert session.winner_id == initial_winner_id
    assert session.streak == 3
    assert session.pool == 20
    assert session.members[initial_winner_id].payout == 20
  end

  test "queued disconnects open queue slots that spectators can claim without paying ante" do
    session = started_growing_session(queue_size: 1, ante: 6)
    {:ok, session, spectator_viewer, nil} = PouleSession.join(session, "dana", "c4")

    assert spectator_viewer["role"] == "spectator"
    assert spectator_viewer["can_claim_queue_spot"] == false

    queued_id = hd(session.queue)
    {:ok, session, nil} = PouleSession.leave(session, session.members[queued_id].client_id)

    assert session.queue == [{:open_slot, 1}]
    assert session.pool == 18
    assert PouleSession.viewer(session, "c4")["can_claim_queue_spot"] == true
    assert PouleSession.serialize(session)["open_queue_slots"] == 1

    {:ok, session, claimed_viewer, nil} = PouleSession.claim_queue_spot(session, "c4")

    assert claimed_viewer["role"] == "queued"
    assert session.queue == [4]
    assert session.spectators == []
    assert session.pool == 18
    assert session.members[4].contributed == 0
    assert PouleSession.serialize(session)["open_queue_slots"] == 0
  end

  test "plucked poule funds the common mass once and rotates in a fixed ring" do
    session = started_plucked_session(queue_size: 2, stake: 50, hole_value: 5)
    initial_host_id = session.active.host
    initial_guest_id = session.active.guest
    [first_queue_id, second_queue_id] = session.queue

    assert session.pool == 200
    assert Enum.sort(session.draw_order) == [1, 2, 3, 4]
    assert session.active == %{host: initial_host_id, guest: initial_guest_id}
    assert session.queue == [first_queue_id, second_queue_id]
    assert session.members[1].contributed == 50
    assert session.members[2].contributed == 50
    assert session.members[3].contributed == 50
    assert session.members[4].contributed == 50

    {:ok, session, {:start_round, next_host_id, next_guest_id}} =
      PouleSession.record_round(session, plucked_round_engine(10, 4, "white"))

    assert {next_host_id, next_guest_id} == {initial_guest_id, first_queue_id}
    assert session.active == %{host: initial_guest_id, guest: first_queue_id}
    assert session.queue == [second_queue_id, initial_host_id]
    assert session.pool == 170
    assert session.members[initial_host_id].payout == 30
    assert List.last(session.history).settlement_trous == 6
    assert List.last(session.history).payout_amount == 30

    {:ok, session, {:start_round, final_host_id, final_guest_id}} =
      PouleSession.record_round(session, plucked_round_engine(9, 6, "black"))

    assert {final_host_id, final_guest_id} == {first_queue_id, second_queue_id}
    assert session.active == %{host: first_queue_id, guest: second_queue_id}
    assert session.queue == [initial_host_id, initial_guest_id]
    assert session.pool == 155
    assert session.members[initial_guest_id].payout == 15
    assert session.members[first_queue_id].contributed == 50
    assert session.members[initial_guest_id].contributed == 50
  end

  test "plucked poule clamps the final payout to the remaining fund" do
    session = started_plucked_session(queue_size: 1, stake: 5, hole_value: 4)
    winner_id = session.active.host
    session = %{session | pool: 7}

    {:ok, session, :finished} =
      PouleSession.record_round(session, plucked_round_engine(10, 4, "white"))

    assert session.phase == :finished
    assert session.pool == 0
    assert session.winner_id == winner_id
    assert session.members[winner_id].payout == 7
    assert List.last(session.history).payout_amount == 7
    assert List.last(session.history).settlement_trous == 6
  end

  test "plucked poule pauses for queue refill when the next ring seat is open" do
    session = started_plucked_session(queue_size: 2, stake: 50, hole_value: 5)
    initial_host_id = session.active.host
    initial_guest_id = session.active.guest
    queued_id = hd(session.queue)
    second_queue_id = Enum.at(session.queue, 1)
    {:ok, session, nil} = PouleSession.leave(session, session.members[queued_id].client_id)

    assert session.queue == [{:open_slot, 1}, second_queue_id]

    {:ok, session, :waiting_for_queue_refill} =
      PouleSession.record_round(session, plucked_round_engine(10, 4, "white"))

    assert session.phase == :waiting_for_queue_refill
    assert session.active == %{host: initial_guest_id, guest: nil}
    assert session.queue == [{:open_slot, 1}, second_queue_id, initial_host_id]
    assert session.pool == 170

    {:ok, session, spectator_viewer, nil} = PouleSession.join(session, "dana", "c5")
    assert spectator_viewer["role"] == "spectator"

    {:ok, session, claimed_viewer, {:start_round, resumed_host_id, resumed_guest_id}} =
      PouleSession.claim_queue_spot(session, "c5")

    assert claimed_viewer["role"] == "active"
    assert {resumed_host_id, resumed_guest_id} == {initial_guest_id, 5}
    assert session.active == %{host: initial_guest_id, guest: 5}
    assert session.queue == [second_queue_id, initial_host_id]
    assert session.members[5].contributed == 0
  end

  test "same auth_id rejoin updates the existing poule member instead of creating a duplicate" do
    session = new_growing_session(queue_size: 1, ante: 4, margot_enabled: true)

    {:ok, session, _viewer, nil} =
      PouleSession.join(session, "alice.bsky.social", "c1", "did:plc:alice")

    {:ok, session, viewer, nil} =
      PouleSession.join(session, "alice-renamed.bsky.social", "c2", "did:plc:alice")

    assert map_size(session.members) == 1
    assert session.member_ids_by_client["c1"] == nil
    assert session.member_ids_by_client["c2"] == 1
    assert session.members[1].name == "alice-renamed.bsky.social"
    assert session.members[1].client_id == "c2"
    assert session.members[1].auth_id == "did:plc:alice"
    assert viewer["id"] == 1
  end

  defp new_growing_session(opts) do
    variant = Registry.fetch!("trictrac_en_poule")

    {:ok, session} =
      PouleSession.new(variant, %{
        "queue_size" => Keyword.fetch!(opts, :queue_size),
        "ante" => Keyword.fetch!(opts, :ante),
        "margot_enabled" => Keyword.get(opts, :margot_enabled, false)
      })

    session
  end

  defp started_growing_session(opts) do
    session = new_growing_session(opts)
    {:ok, session, _viewer, nil} = PouleSession.join(session, "nick", "c1")
    {:ok, session, _viewer, nil} = PouleSession.join(session, "jane", "c2")

    {:ok, session, _viewer, {:start_round, _host_id, _guest_id}} =
      PouleSession.join(session, "bob", "c3")

    session
  end

  defp new_plucked_session(opts) do
    variant = Registry.fetch!("trictrac_en_poule_plumee")

    {:ok, session} =
      PouleSession.new(variant, %{
        "queue_size" => Keyword.fetch!(opts, :queue_size),
        "stake" => Keyword.fetch!(opts, :stake),
        "hole_value" => Keyword.fetch!(opts, :hole_value),
        "margot_enabled" => Keyword.get(opts, :margot_enabled, false)
      })

    session
  end

  defp started_plucked_session(opts) do
    session = new_plucked_session(opts)
    {:ok, session, _viewer, nil} = PouleSession.join(session, "nick", "c1")
    {:ok, session, _viewer, nil} = PouleSession.join(session, "jane", "c2")
    {:ok, session, _viewer, action} = PouleSession.join(session, "bob", "c3")

    if Keyword.fetch!(opts, :queue_size) == 1 do
      assert match?({:start_round, _host_id, _guest_id}, action)
      session
    else
      {:ok, session, _viewer, {:start_round, _host_id, _guest_id}} =
        PouleSession.join(session, "zoe", "c4")

      session
    end
  end

  defp round_engine(winner) do
    %{match: %{winner: winner, winner_kind: "trous"}}
  end

  defp plucked_round_engine(white_trous, black_trous, winner_kind) do
    %{
      trictrac: %{
        score: [
          %{points: 0, trous: white_trous},
          %{points: 0, trous: black_trous}
        ]
      },
      match: %{winner_kind: winner_kind}
    }
  end
end
