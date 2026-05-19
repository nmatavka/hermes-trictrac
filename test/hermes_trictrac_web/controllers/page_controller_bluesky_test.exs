defmodule HermesTrictracWeb.PageControllerBlueskyTest do
  use HermesTrictracWeb.ConnCase, async: false

  setup do
    original_mode = Application.get_env(:hermes_trictrac, :identity_mode)
    original_resolver = Application.get_env(:hermes_trictrac, :identity_session_resolver)

    Application.put_env(:hermes_trictrac, :identity_mode, :bluesky_oauth)

    Application.put_env(:hermes_trictrac, :identity_session_resolver, fn
      "session-alice" -> {:ok, %{did: "did:plc:alice", handle: "alice.bsky.social"}}
      _ -> :error
    end)

    on_exit(fn ->
      restore_env(:identity_mode, original_mode)
      restore_env(:identity_session_resolver, original_resolver)
    end)

    :ok
  end

  test "GET / shows the Bluesky sign-in flow when no identity is present", %{conn: conn} do
    conn = get(conn, "/")

    body = html_response(conn, 200)
    assert body =~ "Bluesky Handle:"
    assert body =~ "Sign in with Bluesky"
    assert body =~ "Sign in before opening, joining, or watching a table."
    assert body =~ ~s(data-identity-mode="bluesky_oauth")
    assert body =~ ~s(data-authenticated="false")
    assert body =~ ~s(data-login-url="/auth/bluesky/login")
    assert body =~ ~s(data-return-to="/")
    assert body =~ ~s(data-lobby-submit disabled)
    refute body =~ ~s(name="name")
  end

  test "GET / shows the signed-in Bluesky banner when identity is present", %{conn: conn} do
    conn =
      conn
      |> init_test_session(%{atex_active_session: "session-alice"})
      |> get("/")

    body = html_response(conn, 200)
    assert body =~ "Signed in as"
    assert body =~ "alice.bsky.social"
    assert body =~ "Log out"
    assert body =~ ~s(data-authenticated="true")
    refute body =~ "Bluesky Handle:"
    refute body =~ ~s(data-lobby-submit disabled)
  end

  test "GET /game redirects unauthenticated Bluesky visitors back to the lobby", %{conn: conn} do
    conn = get(conn, "/game/test-table")

    assert redirected_to(conn) == "/?return_to=%2Fgame%2Ftest-table"
  end

  test "POST /game redirects unauthenticated Bluesky visitors back to the lobby", %{conn: conn} do
    conn = post(conn, "/game", %{game: "test-table", variant: "backgammon"})

    assert redirected_to(conn) == "/?return_to=%2F"
  end

  test "POST /game derives the rendered player name from the Bluesky handle", %{conn: conn} do
    conn =
      conn
      |> init_test_session(%{atex_active_session: "session-alice"})
      |> post("/game", %{game: "test-table", name: "manual-name", variant: "backgammon"})

    body = html_response(conn, 200)
    assert body =~ ~s(data-user="alice.bsky.social")
    assert body =~ ~s(data-identity-mode="bluesky_oauth")
    assert body =~ ~s(data-authenticated="true")
  end

  defp restore_env(key, nil), do: Application.delete_env(:hermes_trictrac, key)
  defp restore_env(key, value), do: Application.put_env(:hermes_trictrac, key, value)
end
