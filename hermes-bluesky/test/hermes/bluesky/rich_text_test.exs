defmodule Hermes.Bluesky.RichTextTest do
  use ExUnit.Case, async: true

  alias Hermes.Bluesky.RichText

  test "extracts link and hashtag facets from plain text" do
    rich_text = RichText.from_text("Check https://example.com/path. #elixir #bluesky")

    assert rich_text.text == "Check https://example.com/path. #elixir #bluesky"
    assert length(rich_text.facets) == 3

    [link, tag_one, tag_two] = rich_text.facets

    assert link["features"] == [
             %{"$type" => "app.bsky.richtext.facet#link", "uri" => "https://example.com/path"}
           ]

    assert tag_one["features"] == [%{"$type" => "app.bsky.richtext.facet#tag", "tag" => "elixir"}]

    assert tag_two["features"] == [
             %{"$type" => "app.bsky.richtext.facet#tag", "tag" => "bluesky"}
           ]
  end
end
