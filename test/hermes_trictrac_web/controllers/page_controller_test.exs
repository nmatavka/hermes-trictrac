defmodule HermesTrictracWeb.PageControllerTest do
  use HermesTrictracWeb.ConnCase, async: true

  test "GET / renders the join form", %{conn: conn} do
    conn = get(conn, "/")

    body = html_response(conn, 200)
    assert body =~ "Start or Join a Table"
    assert body =~ ~s(name="play_mode")
    assert body =~ "Table mode"
    assert body =~ "Head-to-head"
    assert body =~ "Multi-seat"
    assert body =~ ~s(name="variant")
    assert body =~ ~s(data-play-mode-choice)
    assert body =~ ~s(data-play-mode-input)
    assert body =~ ~s(data-variant-input)
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
    assert body =~ ~s(name="head_to_head_variant")
    assert body =~ ~s(data-head-to-head-variant)
    assert body =~ ~s(name="multi_seat_variant")
    assert body =~ ~s(data-multi-seat-variant)
    assert body =~ ~s(data-session-kind="poule")
    assert body =~ ~s(data-session-kind="multiplayer")
    assert body =~ ~s(data-poule-style="growing_pot")
    assert body =~ ~s(data-poule-style="plucked_pot")
    assert body =~ ~s(data-multiplayer-mode="a_tourner")
    assert body =~ ~s(data-multiplayer-mode="chouette")
    assert body =~ ~s(data-multiplayer-mode="combine_deux_contre_deux")
    assert body =~ "Choose a Multi-seat Table"
    assert body =~ "Trictrac en poule"
    assert body =~ "Toccategli en poule"
    assert body =~ "Trictrac en poule (plumée)"
    assert body =~ "Toccategli en poule (plumée)"
    assert body =~ "Trictrac à écrire à tourner"
    assert body =~ "Trictrac à écrire chouette"
    assert body =~ "Trictrac à écrire deux contre deux"
    assert body =~ "Trictrac combiné chouette"
    assert body =~ "Trictrac combiné deux contre deux"

    assert body =~
             "Some multi-seat tables rotate a queue, while others use fixed roles."

    assert body =~ ~s(name="queue_size")
    assert body =~ "Queue Size:"
    assert body =~ ~s(name="ante")
    assert body =~ "Ante:"
    assert body =~ ~s(name="stake")
    assert body =~ "Stake:"
    assert body =~ ~s(name="hole_value")
    assert body =~ "Hole value:"
    assert body =~ ~s(name="cash_per_jeton")
    assert body =~ "Cash per jeton:"
    assert body =~ ~s(name="margot_enabled")

    assert body =~
             "Extra joiners watch as spectators. If a roster spot opens, a spectator can claim it."

    assert body =~ ~s(data-poule-growing-config)
    assert body =~ ~s(data-plucked-pot-config)
    assert body =~ ~s(data-poule-margot-config)
    assert body =~ ~s(data-multiplayer-cash-config)
    assert body =~ "Enter Multi-seat Table"
    refute body =~ "Brade Suedois"
    refute body =~ "Jeu du Plein"
    refute body =~ ~s(name="multi_seat_format")
    refute body =~ ~s(data-multiplayer-fixed-config)
    refute body =~ "being wired"
    refute body =~ "This historical table always uses 12 coups."

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

  test "POST /game preserves multi-seat poule config", %{conn: conn} do
    conn =
      post(conn, "/game", %{
        game: "poule-lobby",
        name: "nick",
        variant: "trictrac_en_poule",
        queue_size: "3",
        ante: "7",
        margot_enabled: "true"
      })

    body = html_response(conn, 200)
    assert body =~ ~s(data-variant="trictrac_en_poule")
    assert body =~ ~s(data-queue-size="3")
    assert body =~ ~s(data-ante="7")
    assert body =~ ~s(data-margot-enabled="true")
  end

  test "POST /game preserves plucked-poule config", %{conn: conn} do
    conn =
      post(conn, "/game", %{
        game: "plumee-lobby",
        name: "nick",
        variant: "trictrac_en_poule_plumee",
        queue_size: "2",
        stake: "100",
        hole_value: "5",
        margot_enabled: "false"
      })

    body = html_response(conn, 200)
    assert body =~ ~s(data-variant="trictrac_en_poule_plumee")
    assert body =~ ~s(data-queue-size="2")
    assert body =~ ~s(data-stake="100")
    assert body =~ ~s(data-hole-value="5")
    assert body =~ ~s(data-margot-enabled="false")
  end

  test "POST /game preserves multiplayer cash accounting config", %{conn: conn} do
    conn =
      post(conn, "/game", %{
        game: "tourner-lobby",
        name: "nick",
        variant: "trictrac_aecrire_a_tourner",
        cash_per_jeton: "1.25"
      })

    body = html_response(conn, 200)
    assert body =~ ~s(data-variant="trictrac_aecrire_a_tourner")
    assert body =~ ~s(data-cash-per-jeton-minor="125")
    refute body =~ ~s(data-a-ecrire-partie-length=)
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

    assert body =~
             ~s(data-rules-url="/rules?return_label=Back+to+game&amp;return_to=%2Fgame%2Fcombine-bot")
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
    assert body =~ ~s(data-rules-url="")
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
