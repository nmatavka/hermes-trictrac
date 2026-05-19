# Provenance:
# - Adapted from atex-main/lib/atex/oauth/plug.ex (MIT)
defmodule Hermes.Bluesky.Phoenix.OAuthPlug do
  @moduledoc """
  Plug router that mounts an ATProto OAuth flow for Phoenix or plain Plug apps.
  """

  use Plug.Router

  alias Atex.{DID, IdentityResolver, OAuth}
  alias Atex.OAuth.{Discovery, Flow}
  alias Hermes.Bluesky.Phoenix.Conn, as: PhoenixConn

  @oauth_cookie_opts [path: "/", http_only: true, secure: true, same_site: "lax", max_age: 600]

  def init(opts) do
    callback = Keyword.get(opts, :callback)

    if !match?({_module, _function, _args}, callback) do
      raise ArgumentError, "expected :callback to be an MFA tuple"
    end

    logout_callback = Keyword.get(opts, :logout_callback)

    if logout_callback && !match?({_module, _function, _args}, logout_callback) do
      raise ArgumentError, "expected :logout_callback to be an MFA tuple"
    end

    opts
  end

  def call(conn, opts) do
    conn
    |> Plug.Conn.put_private(:hermes_bluesky_oauth_opts, opts)
    |> super(opts)
  end

  plug(:match)
  plug(:dispatch)

  get "/login" do
    conn = Plug.Conn.fetch_query_params(conn)
    handle = conn.query_params["handle"]

    if !is_binary(handle) or handle == "" do
      raise Atex.OAuth.Error,
        message: "Handle query parameter is required",
        reason: :missing_handle
    end

    with {:ok, identity} <- IdentityResolver.resolve(handle),
         pds when is_binary(pds) <- DID.Document.get_pds_endpoint(identity.document),
         {:ok, authz_server} <- Discovery.get_authorization_server(pds),
         {:ok, authz_metadata} <- Discovery.get_authorization_server_metadata(authz_server),
         state <- OAuth.create_nonce(),
         code_verifier <- OAuth.create_nonce(),
         {:ok, authz_url} <-
           Flow.create_authorization_url(authz_metadata, state, code_verifier, handle) do
      conn
      |> Plug.Conn.put_resp_cookie("state", state, @oauth_cookie_opts)
      |> Plug.Conn.put_resp_cookie("code_verifier", code_verifier, @oauth_cookie_opts)
      |> Plug.Conn.put_resp_cookie("issuer", authz_metadata.issuer, @oauth_cookie_opts)
      |> Plug.Conn.put_resp_header("location", authz_url)
      |> Plug.Conn.send_resp(307, "")
    else
      _ ->
        raise Atex.OAuth.Error, message: "Invalid or unresolvable handle", reason: :invalid_handle
    end
  end

  get "/client-metadata.json" do
    conn
    |> Plug.Conn.put_resp_content_type("application/json")
    |> Plug.Conn.send_resp(200, Jason.encode_to_iodata!(Flow.create_client_metadata()))
  end

  get "/callback" do
    conn =
      conn
      |> Plug.Conn.fetch_query_params()
      |> Plug.Conn.fetch_session()
      |> Plug.Conn.fetch_cookies()

    callback = Keyword.fetch!(conn.private.hermes_bluesky_oauth_opts, :callback)
    stored_state = conn.req_cookies["state"]
    stored_code_verifier = conn.req_cookies["code_verifier"]
    stored_issuer = conn.req_cookies["issuer"]
    code = conn.query_params["code"]
    state = conn.query_params["state"]

    if invalid_callback_request?(stored_state, stored_code_verifier, stored_issuer, code, state) do
      raise Atex.OAuth.Error,
        message: "Invalid callback request: missing or mismatched state/code parameters",
        reason: :invalid_callback_request
    end

    with {:ok, authz_metadata} <- Discovery.get_authorization_server_metadata(stored_issuer),
         dpop_key <- JOSE.JWK.generate_key({:ec, "P-256"}),
         {:ok, tokens, dpop_nonce} <-
           Flow.validate_authorization_code(authz_metadata, dpop_key, code, stored_code_verifier),
         {:ok, identity} <- IdentityResolver.resolve(tokens.did),
         pds when is_binary(pds) <- DID.Document.get_pds_endpoint(identity.document),
         {:ok, authz_server} <- Discovery.get_authorization_server(pds),
         true <- authz_server == stored_issuer do
      device_nonce = OAuth.create_nonce()

      session = %Atex.OAuth.Session{
        iss: authz_server,
        aud: pds,
        sub: tokens.did,
        nonce: device_nonce,
        access_token: tokens.access_token,
        refresh_token: tokens.refresh_token,
        expires_at: tokens.expires_at,
        dpop_key: dpop_key,
        dpop_nonce: dpop_nonce
      }

      session_key = Atex.OAuth.SessionStore.session_key(session)

      case Atex.OAuth.SessionStore.insert(session) do
        :ok ->
          existing_keys = OAuth.list_session_keys(conn)

          conn =
            conn
            |> Plug.Conn.delete_resp_cookie("state", @oauth_cookie_opts)
            |> Plug.Conn.delete_resp_cookie("code_verifier", @oauth_cookie_opts)
            |> Plug.Conn.delete_resp_cookie("issuer", @oauth_cookie_opts)
            |> Plug.Conn.put_session(
              OAuth.session_keys_name(),
              Enum.uniq([session_key | existing_keys])
            )
            |> Plug.Conn.put_session(OAuth.session_active_session_name(), session_key)

          {mod, fun, args} = callback
          apply(mod, fun, [conn | args])

        {:error, reason} ->
          raise Atex.OAuth.Error,
            message: "Failed to store OAuth session: #{inspect(reason)}",
            reason: :session_store_failed
      end
    else
      false ->
        raise Atex.OAuth.Error,
          message: "OAuth issuer does not match the resolved PDS authorization server",
          reason: :issuer_mismatch

      _ ->
        raise Atex.OAuth.Error,
          message: "Failed to validate authorization code or token",
          reason: :token_validation_failed
    end
  end

  get "/logout" do
    conn = Plug.Conn.fetch_session(conn)
    logout_callback = Keyword.get(conn.private.hermes_bluesky_oauth_opts, :logout_callback)
    conn = PhoenixConn.logout(conn)

    if logout_callback do
      {mod, fun, args} = logout_callback
      apply(mod, fun, [conn | args])
    else
      conn
      |> Plug.Conn.put_resp_header("location", "/")
      |> Plug.Conn.send_resp(302, "")
    end
  end

  defp invalid_callback_request?(stored_state, stored_code_verifier, stored_issuer, code, state) do
    Enum.any?([stored_state, stored_code_verifier, stored_issuer, code, state], &is_nil/1) or
      stored_state != state
  end
end
