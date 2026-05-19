defmodule Hermes.Bluesky.XRPCTest do
  use ExUnit.Case, async: true

  alias Hermes.Bluesky.Session
  alias Hermes.Bluesky.TestClient
  alias Hermes.Bluesky.XRPC

  test "get camelizes params and updates the wrapped session client" do
    client =
      TestClient.new(%{
        {:get, "app.bsky.feed.getTimeline"} => {:ok, %{"feed" => []}}
      })

    session = %Session{
      auth_mode: :login,
      client: client,
      did: "did:plc:test",
      handle: "alice.test",
      pds: "https://bsky.social"
    }

    assert {:ok, %{"feed" => []}, updated_session} =
             XRPC.get(session, "app.bsky.feed.getTimeline",
               params: %{parent_height: 10, reverse: false}
             )

    [{:get, "app.bsky.feed.getTimeline", opts}] = updated_session.client.requests
    assert opts[:params] == %{"parentHeight" => 10, "reverse" => false}
  end
end
