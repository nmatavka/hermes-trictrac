defmodule HermesTrictrac.TableSession do
  alias HermesTrictrac.{MultiplayerSession, PouleSession}

  def new(%{session_mode: :poule} = variant, opts), do: PouleSession.new(variant, opts)
  def new(%{session_mode: :multiplayer} = variant, opts), do: MultiplayerSession.new(variant, opts)
  def new(_variant, _opts), do: {:error, "Unsupported session variant."}

  def round_options(%{kind: :poule} = session), do: PouleSession.round_options(session)
  def round_options(%{kind: :multiplayer} = session), do: MultiplayerSession.round_options(session)

  def join(session, user, client_id, auth_id \\ nil)
  def join(%{kind: :poule} = session, user, client_id, auth_id), do: PouleSession.join(session, user, client_id, auth_id)
  def join(%{kind: :multiplayer} = session, user, client_id, auth_id),
    do: MultiplayerSession.join(session, user, client_id, auth_id)

  def add_spectator(session, user, client_id, auth_id \\ nil)
  def add_spectator(%{kind: :poule} = session, user, client_id, auth_id), do: PouleSession.add_spectator(session, user, client_id, auth_id)
  def add_spectator(%{kind: :multiplayer} = session, user, client_id, auth_id),
    do: MultiplayerSession.add_spectator(session, user, client_id, auth_id)

  def leave(%{kind: :poule} = session, client_id), do: PouleSession.leave(session, client_id)
  def leave(%{kind: :multiplayer} = session, client_id), do: MultiplayerSession.leave(session, client_id)

  def claim_queue_spot(%{kind: :poule} = session, client_id),
    do: PouleSession.claim_queue_spot(session, client_id)

  def claim_queue_spot(_session, _client_id),
    do: {:error, "No open queue slot is available."}

  def claim_roster_slot(%{kind: :multiplayer} = session, client_id),
    do: MultiplayerSession.claim_roster_slot(session, client_id)

  def claim_roster_slot(_session, _client_id),
    do: {:error, "No open roster slot is available."}

  def advance(%{kind: :poule} = session, engine), do: PouleSession.record_round(session, engine)
  def advance(%{kind: :multiplayer} = session, engine), do: MultiplayerSession.advance(session, engine)

  def pending_order_draw?(%{kind: :multiplayer} = session),
    do: MultiplayerSession.pending_order_draw?(session)

  def pending_order_draw?(_session), do: false

  def pending_match_options?(%{kind: :multiplayer} = session),
    do: MultiplayerSession.pending_match_options?(session)

  def pending_match_options?(_session), do: false

  def roll_for_order(%{kind: :multiplayer} = session, client_id),
    do: MultiplayerSession.roll_for_order(session, client_id)

  def roll_for_order(_session, _client_id),
    do: {:error, "Order draw is not available right now."}

  def submit_match_options(%{kind: :multiplayer} = session, options, client_id),
    do: MultiplayerSession.submit_match_options(session, options, client_id)

  def submit_match_options(_session, _options, _client_id),
    do: {:error, "Match options are not available right now."}

  def round_started(%{kind: :multiplayer} = session), do: MultiplayerSession.round_started(session)
  def round_started(session), do: session

  def round_start_color(%{kind: :multiplayer} = session), do: MultiplayerSession.round_start_color(session)
  def round_start_color(_session), do: :white

  def viewer(%{kind: :poule} = session, client_id), do: PouleSession.viewer(session, client_id)
  def viewer(%{kind: :multiplayer} = session, client_id), do: MultiplayerSession.viewer(session, client_id)

  def inject_snapshot(snapshot, %{kind: :poule} = session),
    do: PouleSession.inject_snapshot(snapshot, session)

  def inject_snapshot(snapshot, %{kind: :multiplayer} = session),
    do: MultiplayerSession.inject_snapshot(snapshot, session)

  def connected_competitors(%{kind: :poule} = session), do: PouleSession.connected_competitors(session)
  def connected_competitors(%{kind: :multiplayer} = session), do: MultiplayerSession.connected_competitors(session)

  def connected_spectators(%{kind: :poule} = session), do: PouleSession.connected_spectators(session)
  def connected_spectators(%{kind: :multiplayer} = session), do: MultiplayerSession.connected_spectators(session)
end
