defmodule HermesTrictracWeb.GamesChannelBlueskyTest do
  use HermesTrictracWeb.ChannelCase, async: false

  alias HermesTrictrac.GameServer
  alias HermesTrictracWeb.UserSocket

  setup do
    original_mode = Application.get_env(:hermes_trictrac, :identity_mode)
    original_resolver = Application.get_env(:hermes_trictrac, :identity_session_resolver)

    Application.put_env(:hermes_trictrac, :identity_mode, :bluesky_oauth)

    Application.put_env(:hermes_trictrac, :identity_session_resolver, fn
      "session-alice" -> {:ok, %{did: "did:plc:alice", handle: "alice.bsky.social"}}
      "session-bob" -> {:ok, %{did: "did:plc:bob", handle: "bob.bsky.social"}}
      _ -> :error
    end)

    on_exit(fn ->
      restore_env(:identity_mode, original_mode)
      restore_env(:identity_session_resolver, original_resolver)
    end)

    :ok
  end

  test "UserSocket.connect hydrates the Bluesky identity from the Plug session" do
    socket = socket(UserSocket, "socket:alice", %{})

    assert {:ok, connected_socket} =
             UserSocket.connect(%{}, socket, %{session: %{atex_active_session: "session-alice"}})

    assert connected_socket.assigns.identity_mode == :bluesky_oauth
    assert connected_socket.assigns.identity_did == "did:plc:alice"
    assert connected_socket.assigns.identity_handle == "alice.bsky.social"
    assert UserSocket.id(connected_socket) == "user_socket:did:plc:alice"
  end

  test "unauthenticated Bluesky joins are rejected" do
    assert {:error, %{code: "unauthorized"}} =
             UserSocket
             |> socket("socket:unauth", %{})
             |> Phoenix.Socket.assign(:identity_mode, :bluesky_oauth)
             |> subscribe_and_join(HermesTrictracWeb.GamesChannel, "games:bluesky-unauth", %{
               "variant" => "backgammon",
               "client_id" => "blue-unauth"
             })
  end

  test "channel joins ignore the submitted user name and use the authenticated handle" do
    {:ok, reply, socket} =
      bluesky_socket("socket:join", "session-alice", "did:plc:alice", "alice.bsky.social")
      |> subscribe_and_join(HermesTrictracWeb.GamesChannel, "games:bluesky-join", %{
        "user" => "Mallory",
        "variant" => "backgammon",
        "client_id" => "blue-1"
      })

    assert socket.assigns.user == "alice.bsky.social"
    assert reply.player["name"] == "alice.bsky.social"
    assert reply.game["players"]["host"]["name"] == "alice.bsky.social"
  end

  test "same DID rejoin updates the existing seat instead of creating a duplicate lobby player" do
    lobby = "bluesky-rejoin-#{System.unique_integer([:positive])}"

    {:ok, host_reply, _host_socket} =
      bluesky_socket("socket:host", "session-alice", "did:plc:alice", "alice.bsky.social")
      |> subscribe_and_join(HermesTrictracWeb.GamesChannel, "games:#{lobby}", %{
        "user" => "ignored",
        "variant" => "backgammon",
        "client_id" => "blue-1"
      })

    assert host_reply.player["color"] == "white"
    assert host_reply.game["players"]["guest"] == nil

    {:ok, rejoin_reply, _rejoin_socket} =
      bluesky_socket("socket:host-2", "session-alice", "did:plc:alice", "alice.bsky.social")
      |> subscribe_and_join(HermesTrictracWeb.GamesChannel, "games:#{lobby}", %{
        "user" => "still-ignored",
        "variant" => "backgammon",
        "client_id" => "blue-2"
      })

    assert rejoin_reply.player["color"] == "white"
    assert rejoin_reply.game["players"]["host"]["name"] == "alice.bsky.social"
    assert rejoin_reply.game["players"]["guest"] == nil

    pid = GenServer.whereis(GameServer.reg(lobby))
    state = :sys.get_state(pid)

    assert state.engine.players.host.client_id == "blue-2"
    assert state.engine.players.host.auth_id == "did:plc:alice"
    assert {:error, "Player not found in lobby."} = GameServer.roll(lobby, "alice.bsky.social", "blue-1")
  end

  defp bluesky_socket(socket_id, session_key, did, handle) do
    UserSocket
    |> socket(socket_id, %{})
    |> Phoenix.Socket.assign(:identity_mode, :bluesky_oauth)
    |> Phoenix.Socket.assign(:identity, %{did: did, handle: handle, session_key: session_key})
    |> Phoenix.Socket.assign(:identity_did, did)
    |> Phoenix.Socket.assign(:identity_handle, handle)
    |> Phoenix.Socket.assign(:identity_session_key, session_key)
  end

  defp restore_env(key, nil), do: Application.delete_env(:hermes_trictrac, key)
  defp restore_env(key, value), do: Application.put_env(:hermes_trictrac, key, value)
end
