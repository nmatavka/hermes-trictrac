defmodule BackgammonWeb.PageControllerTest do
  use BackgammonWeb.ConnCase, async: true

  test "GET / renders the join form", %{conn: conn} do
    conn = get(conn, "/")

    body = html_response(conn, 200)
    assert body =~ "Start or Join a Table"
    assert body =~ ~s(name="variant")
    assert body =~ "Tourne-Case"
    assert body =~ "Dames Rabattues"
    assert body =~ "Jeu du Toc"
    assert body =~ "Brade Suedois"
  end

  test "POST /game renders the game root", %{conn: conn} do
    conn = post(conn, "/game", %{game: "lobby", name: "nick", variant: "tapa"})

    body = html_response(conn, 200)
    assert body =~ "Lobby: lobby"
    assert body =~ ~s(data-join-topic="games:lobby")
    assert body =~ ~s(data-variant="tapa")
  end
end
