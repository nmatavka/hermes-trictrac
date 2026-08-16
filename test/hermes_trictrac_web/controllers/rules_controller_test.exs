defmodule HermesTrictracWeb.RulesControllerTest do
  use HermesTrictracWeb.ConnCase, async: true

  test "GET /rules lists the current language rulebooks and controls", %{conn: conn} do
    conn = get(conn, "/rules")

    body = html_response(conn, 200)
    assert body =~ "Rules Library"
    assert body =~ ~s(class="rules-shell")
    assert body =~ ~s(data-rules-filter-form)
    assert body =~ ~s(name="lang")
    assert body =~ ~s(name="variant_id")
    assert body =~ ~s(data-theme-cycle)
    assert body =~ "Cycle Theme"
    refute body =~ ~s(data-theme-select)
    assert body =~ "Trictrac: Complete Table Rulebook"
    refute body =~ "Traité complet du jeu de Trictrac"
  end

  test "GET /rules filters books by language", %{conn: conn} do
    french_conn = get(conn, "/rules", %{lang: "fr"})
    french_body = html_response(french_conn, 200)

    assert french_body =~ "Traité complet du jeu de Trictrac"
    assert french_body =~ "Cours complet de Trictrac"
    assert french_body =~ "Le jeu de Trictrac rendu facile"
    assert french_body =~ "Multilingual Trictrac"
    refute french_body =~ "Trictrac: Complete Table Rulebook"

    german_conn = get(conn, "/rules", %{lang: "de"})
    german_body = html_response(german_conn, 200)

    assert german_body =~ "Multilingual Trictrac"
    refute german_body =~ "Trictrac: Complete Table Rulebook"
    refute german_body =~ "Traité complet du jeu de Trictrac"
  end

  test "GET /rules filters books by exact variant", %{conn: conn} do
    conn = get(conn, "/rules", %{lang: "fr", variant_id: "brade"})

    body = html_response(conn, 200)
    assert body =~ "Multilingual Trictrac"
    refute body =~ "Traité complet du jeu de Trictrac"
  end

  test "GET /rules renders search results within active filters", %{conn: conn} do
    conn = get(conn, "/rules", %{lang: "fr", q: "Backgammon"})

    body = html_response(conn, 200)
    assert body =~ "Search results"
    assert body =~ "Traité du jeu de Backgammon"

    conn = get(conn, "/rules", %{lang: "en", q: "Complete Table"})
    body = html_response(conn, 200)
    assert body =~ "Trictrac: Complete Table Rulebook"
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
        return_label: "Back to game",
        lang: "fr"
      })

    body = html_response(conn, 200)
    assert body =~ ~s(href="/game/test-table")

    assert body =~
             ~s(/rules/traite-complet-trictrac/chapitre3?)

    assert body =~ ~s(lang=fr)
    assert body =~ ~s(return_to=%2Fgame%2Ftest-table)
  end

  test "GET /rules chapter rewrites epub and image assets", %{conn: conn} do
    index_conn = get(conn, "/rules/le-jeu-de-trictrac-rendu-facile/index", %{lang: "fr"})
    index_body = html_response(index_conn, 200)

    assert index_body =~
             ~s(/rules-assets/le-jeu-de-trictrac-rendu-facile/trictracFacile.epub)

    image_conn = get(conn, "/rules/traite-complet-trictrac/chapitre14", %{lang: "fr"})
    image_body = html_response(image_conn, 200)

    assert image_body =~
             ~s(/rules-assets/traite-complet-trictrac/data/content-0109.png)
  end

  test "GET /rules chapter preserves explicit named anchors", %{conn: conn} do
    conn = get(conn, "/rules/traite-complet-trictrac/chapitre2", %{lang: "fr"})

    body = html_response(conn, 200)
    assert body =~ ~s(id="methode-decroissante")
  end

  test "GET /rules chapter provides a contextual outline beside the active book TOC", %{
    conn: conn
  } do
    conn = get(conn, "/rules/english-rules-trictrac/english_rules_trictrac", %{lang: "en"})

    body = html_response(conn, 200)
    assert body =~ ~s(aria-label="On this page")
    assert body =~ "4. Determining the lead"
    assert body =~ ~s(class="rules-toc-entry active")
  end

  test "GET /rules first chapter marks frontmatter content for shared reader styling", %{
    conn: conn
  } do
    conn = get(conn, "/rules/traite-complet-trictrac/index", %{lang: "fr"})

    body = html_response(conn, 200)
    assert body =~ ~s(class="rules-article rules-frontmatter")
  end

  test "GET /rules hides books excluded by the active filters", %{conn: conn} do
    conn = get(conn, "/rules/traite-complet-trictrac/index", %{lang: "en"})

    assert html_response(conn, 404)
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
