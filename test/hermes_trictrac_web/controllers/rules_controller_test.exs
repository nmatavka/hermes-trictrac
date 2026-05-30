defmodule HermesTrictracWeb.RulesControllerTest do
  use HermesTrictracWeb.ConnCase, async: true

  test "GET /rules lists all imported books", %{conn: conn} do
    conn = get(conn, "/rules")

    body = html_response(conn, 200)
    assert body =~ "Trictrac Rules Library"
    assert body =~ "Traité complet du jeu de Trictrac"
    assert body =~ "Cours complet de Trictrac"
    assert body =~ "Le jeu de Trictrac rendu facile"
  end

  test "GET /rules renders search results across books", %{conn: conn} do
    conn = get(conn, "/rules", %{q: "Backgammon"})

    body = html_response(conn, 200)
    assert body =~ "Search results"
    assert body =~ "Traité du jeu de Backgammon"
  end

  test "GET /rules without a return target omits the back link", %{conn: conn} do
    conn = get(conn, "/rules")

    body = html_response(conn, 200)
    refute body =~ "Back to game"
  end

  test "GET /rules chapter preserves return navigation and rewrites chapter links", %{conn: conn} do
    conn =
      get(conn, "/rules/traite-complet-trictrac/chapitre4", %{
        return_to: "/game/test-table",
        return_label: "Back to game"
      })

    body = html_response(conn, 200)
    assert body =~ ~s(href="/game/test-table")

    assert body =~
             ~s(/rules/traite-complet-trictrac/chapitre3?return_label=Back+to+game&amp;return_to=%2Fgame%2Ftest-table#premier-exemple)
  end

  test "GET /rules chapter rewrites epub and image assets", %{conn: conn} do
    index_conn = get(conn, "/rules/le-jeu-de-trictrac-rendu-facile/index")
    index_body = html_response(index_conn, 200)

    assert index_body =~
             ~s(/rules-assets/le-jeu-de-trictrac-rendu-facile/trictracFacile.epub)

    image_conn = get(conn, "/rules/traite-complet-trictrac/chapitre14")
    image_body = html_response(image_conn, 200)

    assert image_body =~
             ~s(/rules-assets/traite-complet-trictrac/data/content-0109.png)
  end

  test "GET /rules chapter preserves explicit named anchors", %{conn: conn} do
    conn = get(conn, "/rules/traite-complet-trictrac/chapitre2")

    body = html_response(conn, 200)
    assert body =~ ~s(id="methode-decroissante")
  end

  test "GET /rules-assets serves epub downloads", %{conn: conn} do
    conn = get(conn, "/rules-assets/cours-complet-de-trictrac/coursCompletdeTrictrac.epub")

    assert response(conn, 200)

    assert Enum.any?(
             get_resp_header(conn, "content-disposition"),
             &String.contains?(&1, "coursCompletdeTrictrac.epub")
           )
  end
end
