defmodule HermesTrictracWeb.PageControllerTest do
  use HermesTrictracWeb.ConnCase, async: true

  test "GET / renders the join form", %{conn: conn} do
    conn = get(conn, "/")

    body = html_response(conn, 200)
    assert body =~ "Start or Join a Table"
    assert body =~ ~s(data-theme="solarized-light")
    assert body =~ ~s(const fallback = "solarized-light")
    assert body =~ ~s(root.style.colorScheme = "light")
    assert body =~ ~s(name="play_mode")
    assert body =~ "Table mode"
    assert body =~ ~s(href="/rules")
    assert body =~ ~s(data-rules-language-link)
    assert body =~ ">Rules<"
    assert body =~ ~s(data-bgm-toggle)
    assert body =~ ~s(aria-pressed="true")
    assert body =~ ~s(title="Turn background music off")
    assert body =~ "Music On"
    assert body =~ "Lobby Name"
    assert body =~ "User Name"
    assert body =~ "Head-to-head"
    assert body =~ "Multi-seat"
    assert body =~ ~s(name="variant")
    assert body =~ ~s(data-play-mode-choice)
    assert body =~ ~s(data-play-mode-input)
    assert body =~ ~s(data-variant-input)
    assert body =~ "Choose a Game"
    assert body =~ "Backgammon"
    assert body =~ "Trictrac classique"
    assert body =~ "Toc"
    assert body =~ "Toccategli"
    assert body =~ "Tapa"
    assert body =~ "Jacquet"
    assert body =~ "Garanguet"
    assert body =~ "Bräde"
    assert body =~ "More games"
    assert body =~ "Trictrac à écrire"
    assert body =~ "Trictrac combiné"
    assert body =~ ~s(data-tavli-options)
    assert body =~ ~s(value="backgammon" data-tavli-member="true")
    assert body =~ ~s(name="tavli_enabled")
    assert body =~ ~s(data-tavli-variant="tavli")
    assert body =~ "Backgammon → Tapa → Jacquet"

    {backgammon_at, _} = :binary.match(body, "Backgammon")
    {tapa_at, _} = :binary.match(body, ~s(value="tapa"))
    {jacquet_at, _} = :binary.match(body, ~s(value="jacquet"))
    {garanguet_at, _} = :binary.match(body, ~s(value="garanguet"))
    {classique_at, _} = :binary.match(body, ~s(value="trictrac_classique"))
    {play_against_at, _} = :binary.match(body, "Play against")
    {tavli_at, _} = :binary.match(body, ~s(data-tavli-options))
    {more_at, _} = :binary.match(body, "More games")
    {aecrire_at, _} = :binary.match(body, "Trictrac à écrire")
    assert backgammon_at < tapa_at
    assert tapa_at < jacquet_at
    assert jacquet_at < garanguet_at
    assert garanguet_at < classique_at
    assert tapa_at < more_at
    assert aecrire_at > more_at
    assert tavli_at > play_against_at
    assert body =~ ~s(class="variant-disclosure-pill")
    assert body =~ ~s(name="bot")
    assert body =~ "Play against"
    assert body =~ "Game Options"
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
    assert body =~ "Queue Size"
    assert body =~ ~s(name="ante")
    assert body =~ "Ante"
    assert body =~ ~s(name="stake")
    assert body =~ "Stake"
    assert body =~ ~s(name="hole_value")
    assert body =~ "Hole value"
    assert body =~ ~s(name="cash_per_jeton")
    assert body =~ "Cash per jeton"
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

    assert body =~ "Computer play is enabled only when an accepted ML champion is available."
    refute body =~ ~s(data-theme-select)
    refute body =~ ~s(data-theme-cycle)
    refute body =~ "Lobby Name:"
    refute body =~ "User Name:"
  end

  test "POST /game renders the game root", %{conn: conn} do
    conn = post(conn, "/game", %{game: "lobby", name: "nick", variant: "tapa"})

    body = html_response(conn, 200)
    assert body =~ ~s(data-join-topic="games:lobby")
    assert body =~ ~s(data-user="nick")
    assert body =~ ~s(data-variant="tapa")
    assert body =~ ~s(data-client-id-scope="tab")
  end

  test "manual player name persists in session across game navigation", %{conn: conn} do
    conn =
      post(conn, "/game", %{game: "session-lobby", name: "nick", variant: "trictrac_classique"})

    assert html_response(conn, 200) =~ ~s(data-user="nick")

    conn = recycle(conn)
    conn = get(conn, "/game/session-lobby", %{variant: "trictrac_classique"})

    body = html_response(conn, 200)
    assert body =~ ~s(data-user="nick")
  end

  test "blank manual player name does not overwrite the session value", %{conn: conn} do
    conn =
      post(conn, "/game", %{game: "session-lobby", name: "nick", variant: "trictrac_classique"})

    assert html_response(conn, 200) =~ ~s(data-user="nick")

    conn = recycle(conn)

    conn =
      post(conn, "/game", %{game: "session-lobby", name: "   ", variant: "trictrac_classique"})

    body = html_response(conn, 200)
    assert body =~ ~s(data-user="nick")
  end

  test "GET / pre-fills the manual user name from the session", %{conn: conn} do
    conn = init_test_session(conn, %{manual_player_name: "nick"})
    conn = get(conn, "/")

    body = html_response(conn, 200)
    assert body =~ ~s(name="name")
    assert body =~ ~s(value="nick")
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
    assert body =~ ~s(variant_id=trictrac_classique)
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
    assert body =~ ~s(variant_id=trictrac_aecrire)
  end

  test "POST /game drops computer settings for human-only lower-rail variants", %{conn: conn} do
    conn =
      post(conn, "/game", %{
        game: "combine-bot",
        name: "nick",
        variant: "trictrac_combine",
        bot: "trictrac_zero",
        bot_margot: "yes"
      })

    body = html_response(conn, 200)
    assert body =~ ~s(data-bot="")
    assert body =~ ~s(data-bot-margot="")
    assert body =~ ~s(data-variant="trictrac_combine")

    assert body =~ ~s(data-rules-url="/rules?)
    assert body =~ ~s(return_to=%2Fgame%2Fcombine-bot)
    assert body =~ ~s(variant_id=trictrac_combine)
  end

  test "GET /game preserves the full current location in the rules return target", %{conn: conn} do
    conn =
      get(conn, "/game/combine-bot", %{
        variant: "trictrac_combine",
        name: "nick",
        view: "analysis"
      })

    body = html_response(conn, 200)

    assert body =~ ~s(data-rules-url="/rules?)

    assert body =~
             ~s(return_to=%2Fgame%2Fcombine-bot%3Fname%3Dnick%26variant%3Dtrictrac_combine%26view%3Danalysis)

    assert body =~ ~s(variant_id=trictrac_combine)
  end

  test "POST /game accepts the legacy Backgammon ingress name only after champion release", %{
    conn: conn
  } do
    conn =
      post(conn, "/game", %{
        game: "backgammon-bot",
        name: "nick",
        variant: "backgammon",
        bot: "backgammon_ai"
      })

    body = html_response(conn, 200)
    assert body =~ ~s(data-bot="")
    assert body =~ ~s(data-variant="backgammon")
    assert body =~ ~s(data-rules-url="/rules?)
    assert body =~ ~s(return_to=%2Fgame%2Fbackgammon-bot)
    assert body =~ ~s(variant_id=backgammon)
  end

  test "POST /game drops the legacy Backgammon ingress name for another game", %{conn: conn} do
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
