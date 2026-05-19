defmodule Hermes.Bluesky.JetstreamTest do
  use ExUnit.Case, async: true

  alias Hermes.Bluesky.Realtime.Jetstream
  alias Hermes.Bluesky.Realtime.Jetstream.Event

  test "normalizes commit events" do
    payload =
      Jason.encode!(%{
        "kind" => "commit",
        "did" => "did:plc:alice",
        "time_us" => 123,
        "commit" => %{
          "collection" => "app.bsky.feed.post",
          "operation" => "create",
          "rkey" => "3kabc",
          "cid" => "bafycid",
          "record" => %{"text" => "hello"}
        }
      })

    assert [%Event{} = event] = Jetstream.decode_frame(payload)
    assert event.kind == :commit
    assert event.collection == "app.bsky.feed.post"
    assert event.uri == "at://did:plc:alice/app.bsky.feed.post/3kabc"
  end

  test "builds websocket subscribe URIs with repeated collections" do
    uri =
      Jetstream.build_uri(
        host: "jetstream.example.test",
        cursor: "latest",
        wanted_collections: ["app.bsky.feed.post", "app.bsky.feed.like"]
      )

    assert uri.host == "jetstream.example.test"
    assert uri.path == "/subscribe"
    assert uri.query =~ "cursor=latest"
    assert uri.query =~ "wantedCollections=app.bsky.feed.post"
    assert uri.query =~ "wantedCollections=app.bsky.feed.like"
  end
end
