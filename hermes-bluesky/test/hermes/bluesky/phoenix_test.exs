defmodule Hermes.Bluesky.PhoenixTest do
  use ExUnit.Case, async: true

  alias Atex.DID.Document
  alias Atex.DID.Document.Service
  alias Atex.IdentityResolver.Cache
  alias Atex.IdentityResolver.Identity
  alias Atex.OAuth
  alias Atex.OAuth.SessionStore
  alias Hermes.Bluesky.Phoenix.Conn
  alias Hermes.Bluesky.Phoenix.LiveView
  alias Hermes.Bluesky.Session

  test "logout removes the active oauth session from plug session storage" do
    did = "did:plc:testphoenix123"
    handle = "phoenix.test"
    pds = "https://pds.example.test"

    identity =
      Identity.new(did, handle, %Document{
        "@context": ["https://www.w3.org/ns/did/v1"],
        id: did,
        service: [
          %Service{
            id: "#{did}#atproto_pds",
            type: "AtprotoPersonalDataServer",
            service_endpoint: pds
          }
        ]
      })

    Cache.insert(identity)

    oauth_session = %Atex.OAuth.Session{
      iss: "https://issuer.example.test",
      aud: pds,
      sub: did,
      nonce: "device-nonce",
      access_token: "access",
      refresh_token: "refresh",
      expires_at: NaiveDateTime.utc_now(),
      dpop_key: JOSE.JWK.generate_key({:ec, "P-256"})
    }

    session_key = SessionStore.session_key(oauth_session)
    :ok = SessionStore.insert(oauth_session)

    conn =
      Plug.Test.conn(:get, "/")
      |> Plug.Test.init_test_session(%{
        OAuth.session_keys_name() => [session_key],
        OAuth.session_active_session_name() => session_key
      })
      |> Conn.logout()

    assert Conn.current_session_key(conn) == nil
    assert Conn.list_session_keys(conn) == []
    assert {:error, :not_found} = SessionStore.get(session_key)
  end

  test "live view helper hydrates the bluesky session from session data" do
    did = "did:plc:testliveview123"
    handle = "liveview.test"
    pds = "https://pds.example.test"

    identity =
      Identity.new(did, handle, %Document{
        "@context": ["https://www.w3.org/ns/did/v1"],
        id: did,
        service: [
          %Service{
            id: "#{did}#atproto_pds",
            type: "AtprotoPersonalDataServer",
            service_endpoint: pds
          }
        ]
      })

    Cache.insert(identity)

    oauth_session = %Atex.OAuth.Session{
      iss: "https://issuer.example.test",
      aud: pds,
      sub: did,
      nonce: "device-nonce-live",
      access_token: "access",
      refresh_token: "refresh",
      expires_at: NaiveDateTime.utc_now(),
      dpop_key: JOSE.JWK.generate_key({:ec, "P-256"})
    }

    session_key = SessionStore.session_key(oauth_session)
    :ok = SessionStore.insert(oauth_session)

    socket = %{assigns: %{}}

    assert {:cont, socket} =
             LiveView.on_mount(:default, %{}, %{"atex_active_session" => session_key}, socket)

    assert %Session{did: ^did, handle: ^handle} = socket.assigns.bluesky_session
    assert socket.assigns.bluesky_session_key == session_key
  end
end
