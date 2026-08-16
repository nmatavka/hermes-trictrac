defmodule HermesTrictrac.RulesLibraryTest do
  use ExUnit.Case, async: true

  alias HermesTrictrac.RulesLibrary
  alias HermesTrictrac.RulesLibrary.{Markdown, Scrubber}

  test "discovers imported and standalone rules books" do
    books = RulesLibrary.books()

    assert Enum.map(books, & &1.slug) == [
             "traite-complet-trictrac",
             "cours-complet-de-trictrac",
             "le-jeu-de-trictrac-rendu-facile",
             "english-rules-trictrac",
             "multi-rules"
           ]

    assert {:ok, traite} = RulesLibrary.fetch_book("traite-complet-trictrac")

    assert Enum.take(traite.toc_entries, 5) |> Enum.map(& &1.title) == [
             "Présentation",
             "Avertissement",
             "Introduction",
             "Chapitre I",
             "Chapitre II"
           ]

    assert {:ok, english} = RulesLibrary.fetch_book("english-rules-trictrac")
    assert english.languages == ["en"]
    assert "trictrac_classique" in english.variant_ids

    assert {:ok, multi} = RulesLibrary.fetch_book("multi-rules")
    assert multi.languages == ["fr", "de", "sv", "da"]
    assert "brade" in multi.variant_ids
  end

  test "filters rulebooks by language" do
    assert RulesLibrary.books(%{language: "en"}) |> Enum.map(& &1.slug) == [
             "english-rules-trictrac"
           ]

    assert RulesLibrary.books(%{language: "fr"}) |> Enum.map(& &1.slug) == [
             "traite-complet-trictrac",
             "cours-complet-de-trictrac",
             "le-jeu-de-trictrac-rendu-facile",
             "multi-rules"
           ]

    for language <- ~w(de sv da) do
      assert RulesLibrary.books(%{language: language}) |> Enum.map(& &1.slug) == ["multi-rules"]
    end
  end

  test "filters rulebooks by exact variant" do
    assert RulesLibrary.books(%{language: "fr", variant_id: "brade"}) |> Enum.map(& &1.slug) == [
             "multi-rules"
           ]

    assert RulesLibrary.books(%{language: "en", variant_id: "trictrac_aecrire"})
           |> Enum.map(& &1.slug) == ["english-rules-trictrac"]

    assert RulesLibrary.fetch_book("english-rules-trictrac", %{
             language: "en",
             variant_id: "brade"
           }) == :error
  end

  test "search ranks direct title hits before body-only hits" do
    [first | _rest] = RulesLibrary.search("Backgammon")

    assert first.book_slug == "traite-complet-trictrac"
    assert first.route_path == "traite-du-jeu-de-backgammon"
    assert first.title == "Traité du jeu de Backgammon"
  end

  test "search honors language filters" do
    [first | _rest] = RulesLibrary.search("Complete Table", %{language: "en"})

    assert first.book_slug == "english-rules-trictrac"

    assert RulesLibrary.search("Complete Table", %{language: "fr"}) == []
  end

  test "renders GFM through the scrubber without admitting unsafe source HTML" do
    html =
      """
      | Left | Right |
      | --- | --- |
      | one | two |

      - [x] completed

      ~~withdrawn~~[^1]

      [^1]: a note

      <script>alert('unsafe')</script><a href="javascript:alert('unsafe')">unsafe</a>
      """
      |> Markdown.to_html!()
      |> Scrubber.sanitize()

    assert html =~ "<table>"
    assert html =~ ~s(<input type="checkbox" checked="" disabled="")
    assert html =~ "<del>withdrawn</del>"
    assert html =~ "footnotes"
    refute html =~ "<script>"
    refute html =~ "javascript:"
  end

  test "keeps historical named anchors while assigning chapter outline IDs" do
    assert {:ok, chapter} =
             RulesLibrary.fetch_chapter("traite-complet-trictrac", "chapitre2", %{language: "fr"})

    assert chapter.html =~ ~s(id="methode-decroissante")
    assert Enum.any?(chapter.outline_entries, &(&1.id == "premiere-methode"))
  end

  test "rewrites legacy links to the final IDs in their actual chapter" do
    assert {:ok, chapter_two} =
             RulesLibrary.fetch_chapter("traite-complet-trictrac", "chapitre2", %{language: "fr"})

    assert chapter_two.html =~
             ~s(href="/rules/traite-complet-trictrac/chapitre15#premiere-table")

    assert {:ok, english} =
             RulesLibrary.fetch_chapter("english-rules-trictrac", "english_rules_trictrac", %{
               language: "en"
             })

    assert english.html =~
             ~s(href="/rules/english-rules-trictrac/english_rules_trictrac#4-determining-the-lead")
  end

  test "every rendered Rules Library fragment link has a rendered target" do
    for book <- RulesLibrary.books(),
        chapter <- book.chapters,
        href <- internal_hrefs(chapter.html) do
      {book_slug, route_path, fragment} = link_target(href, book, chapter)

      assert {:ok, target_chapter} = RulesLibrary.fetch_chapter(book_slug, route_path)

      target_ids =
        target_chapter.html
        |> Floki.parse_fragment!()
        |> Floki.find("[id]")
        |> Enum.flat_map(&Floki.attribute(&1, "id"))

      assert URI.decode(fragment) in target_ids,
             "#{book.slug}/#{chapter.route_path} links #{href} to a missing target"
    end
  end

  defp internal_hrefs(html) do
    html
    |> Floki.parse_fragment!()
    |> Floki.find("a[href]")
    |> Enum.flat_map(&Floki.attribute(&1, "href"))
    |> Enum.filter(fn href ->
      uri = URI.parse(href)

      is_binary(uri.fragment) and
        (uri.path in [nil, ""] or String.starts_with?(uri.path || "", "/rules/"))
    end)
  end

  defp link_target(href, current_book, current_chapter) do
    uri = URI.parse(href)

    case uri.path do
      nil ->
        {current_book.slug, current_chapter.route_path, uri.fragment}

      "" ->
        {current_book.slug, current_chapter.route_path, uri.fragment}

      path ->
        ["rules", book_slug | route_segments] = String.split(path, "/", trim: true)

        {URI.decode(book_slug), route_segments |> Enum.map(&URI.decode/1) |> Enum.join("/"),
         uri.fragment}
    end
  end
end
