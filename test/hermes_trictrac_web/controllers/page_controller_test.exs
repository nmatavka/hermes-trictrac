defmodule HermesTrictracWeb.PageControllerTest do
  use HermesTrictracWeb.ConnCase, async: true

  test "GET / renders the join form", %{conn: conn} do
    conn = get(conn, "/")

    body = html_response(conn, 200)
    assert body =~ "Start or Join a Table"
    assert body =~ ~s(name="variant")
    assert body =~ "Choose a Game"
    assert body =~ "Backgammon"
    assert body =~ "Trictrac classique"
    assert body =~ "Trictrac &agrave; &eacute;crire"
    assert body =~ "Trictrac combin&eacute;"
    assert body =~ "Toc"
    assert body =~ "Toccategli"
    assert body =~ "More games"
    assert body =~ "Jacquet / Pheuga"
    assert body =~ "Garanguet"
    assert body =~ "Tavli"
    assert body =~ ~s(name="bot")
    assert body =~ "Play against"
    assert body =~ "Human"
    assert body =~ "Computer"
    assert body =~ ~s(name="bot_margot")
    assert body =~ "Margot"
    assert body =~ "Off"
    assert body =~ "On"
    assert body =~ "Tourne-Case"
    assert body =~ "Dames Rabattues"
    assert body =~ "Sbaraglio"
    assert body =~ "Sbaraglino"
    assert body =~ "Bräde"
    assert body =~ "Plein"
    refute body =~ "Brade Suedois"
    refute body =~ "Jeu du Plein"

    assert body =~ "More games are not available for computer play yet."
    assert body =~ "Computer play uses BackgammonAI for English backgammon"
    assert body =~ "the current TricTrac model for Trictrac classique"
  end

  test "POST /game renders the game root", %{conn: conn} do
    conn = post(conn, "/game", %{game: "lobby", name: "nick", variant: "tapa"})

    body = html_response(conn, 200)
    assert body =~ ~s(data-join-topic="games:lobby")
    assert body =~ ~s(data-variant="tapa")
    assert body =~ ~s(data-client-id-scope="tab")
  end

  test "POST /game preserves trictrac bot settings for supported variants", %{conn: conn} do
    conn =
      post(conn, "/game", %{
        game: "combine-bot",
        name: "nick",
        variant: "trictrac_combine",
        bot: "trictrac_zero",
        bot_margot: "yes"
      })

    body = html_response(conn, 200)
    assert body =~ ~s(data-bot="trictrac_zero")
    assert body =~ ~s(data-bot-margot="yes")
    assert body =~ ~s(data-variant="trictrac_combine")
  end

  test "POST /game preserves BackgammonAI for English backgammon", %{conn: conn} do
    conn =
      post(conn, "/game", %{
        game: "backgammon-bot",
        name: "nick",
        variant: "backgammon",
        bot: "backgammon_ai"
      })

    body = html_response(conn, 200)
    assert body =~ ~s(data-bot="backgammon_ai")
    assert body =~ ~s(data-variant="backgammon")
  end

  test "POST /game drops BackgammonAI for non-backgammon variants", %{conn: conn} do
    conn =
      post(conn, "/game", %{
        game: "tapa-bot",
        name: "nick",
        variant: "tapa",
        bot: "backgammon_ai"
      })

    body = html_response(conn, 200)
    assert body =~ ~s(data-bot="")
    assert body =~ ~s(data-variant="tapa")
  end
end
