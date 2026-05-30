defmodule HermesTrictrac.RulesLibraryTest do
  use ExUnit.Case, async: true

  alias HermesTrictrac.RulesLibrary

  test "discovers the imported rules books and upstream navigation" do
    books = RulesLibrary.books()

    assert Enum.map(books, & &1.slug) == [
             "traite-complet-trictrac",
             "cours-complet-de-trictrac",
             "le-jeu-de-trictrac-rendu-facile"
           ]

    assert {:ok, traite} = RulesLibrary.fetch_book("traite-complet-trictrac")

    assert Enum.take(traite.toc_entries, 5) |> Enum.map(& &1.title) == [
             "Présentation",
             "Avertissement",
             "Introduction",
             "Chapitre I",
             "Chapitre II"
           ]
  end

  test "search ranks direct title hits before body-only hits" do
    [first | _rest] = RulesLibrary.search("Backgammon")

    assert first.book_slug == "traite-complet-trictrac"
    assert first.route_path == "traite-du-jeu-de-backgammon"
    assert first.title == "Traité du jeu de Backgammon"
  end
end
