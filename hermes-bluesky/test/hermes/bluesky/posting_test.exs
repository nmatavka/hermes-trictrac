defmodule Hermes.Bluesky.PostingTest do
  use ExUnit.Case, async: true

  alias Hermes.Bluesky
  alias Hermes.Bluesky.Session
  alias Hermes.Bluesky.TestClient

  test "post builds reply threading, facets, and image embeds" do
    reply_uri = "at://did:plc:parent/app.bsky.feed.post/3kparent"

    client =
      TestClient.new(%{
        {:get, "com.atproto.repo.getRecord"} =>
          {:ok,
           %{
             "uri" => reply_uri,
             "cid" => "cid-parent",
             "value" => %{}
           }},
        {:post, "com.atproto.repo.uploadBlob"} =>
          {:ok,
           %{
             "blob" => %{
               "$type" => "blob",
               "ref" => %{"$link" => "bafkblob"},
               "mimeType" => "image/png",
               "size" => 4
             }
           }},
        {:post, "com.atproto.repo.createRecord"} =>
          {:ok,
           %{
             "uri" => "at://did:plc:self/app.bsky.feed.post/3kpost",
             "cid" => "cid-post"
           }}
      })

    session = %Session{
      auth_mode: :login,
      client: client,
      did: "did:plc:self",
      handle: "self.test",
      pds: "https://bsky.social"
    }

    image_path =
      Path.join(
        System.tmp_dir!(),
        "hermes-bluesky-test-#{System.unique_integer([:positive])}.png"
      )

    File.write!(image_path, <<137, 80, 78, 71>>)

    assert {:ok, %{"uri" => "at://did:plc:self/app.bsky.feed.post/3kpost"}, updated_session} =
             Bluesky.post(session, "Hello https://example.com #elixir",
               reply_to: reply_uri,
               media_paths: [image_path]
             )

    [
      {:get, "com.atproto.repo.getRecord", _get_opts},
      {:post, "com.atproto.repo.uploadBlob", _blob_opts},
      {:post, "com.atproto.repo.createRecord", create_opts}
    ] = updated_session.client.requests

    record = create_opts[:json]["record"]

    assert record["reply"]["parent"]["uri"] == reply_uri
    assert record["reply"]["root"]["cid"] == "cid-parent"
    assert record["embed"]["images"] |> length() == 1

    assert Enum.any?(record["facets"], fn facet ->
             facet["features"] == [%{"$type" => "app.bsky.richtext.facet#tag", "tag" => "elixir"}]
           end)
  end
end
