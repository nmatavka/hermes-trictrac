defmodule Hermes.Bluesky.Session do
  @moduledoc """
  Unified authenticated context for Hermes Bluesky operations.
  """

  alias Atex.IdentityResolver
  alias Atex.OAuth
  alias Atex.OAuth.SessionStore
  alias Atex.XRPC.LoginClient
  alias Atex.XRPC.OAuthClient
  alias Hermes.Bluesky.Error

  defstruct [:auth_mode, :client, :did, :handle, :pds, :session_key, :identity]

  @type auth_mode :: :login | :oauth

  @type t :: %__MODULE__{
          auth_mode: auth_mode(),
          client: LoginClient.t() | OAuthClient.t(),
          did: String.t(),
          handle: String.t() | nil,
          pds: String.t(),
          session_key: String.t() | nil,
          identity: Atex.IdentityResolver.Identity.t() | nil
        }

  @spec login(String.t(), String.t(), keyword()) :: {:ok, t()} | {:error, Error.t() | any()}
  def login(identifier, password, opts \\ [])
      when is_binary(identifier) and is_binary(password) do
    endpoint = Keyword.get(opts, :service, "https://bsky.social")

    with {:ok, %Req.Response{body: body}} <-
           Atex.XRPC.unauthed_post(endpoint, "com.atproto.server.createSession",
             json: %{identifier: identifier, password: password}
           ),
         {:ok, session} <- build_login_session(endpoint, body) do
      {:ok, session}
    else
      {:ok, %Req.Response{} = response} -> {:error, Error.from_response(response)}
      {:error, reason} -> {:error, Error.from_reason(reason)}
      error -> error
    end
  end

  @spec from_oauth_conn(Plug.Conn.t()) :: {:ok, t()} | :error | {:error, any()}
  def from_oauth_conn(%Plug.Conn{} = conn) do
    case OAuth.current_session_key(conn) do
      nil ->
        :error

      session_key ->
        from_session_key(session_key)
    end
  end

  @spec from_session_key(String.t()) :: {:ok, t()} | {:error, any()}
  def from_session_key(session_key) when is_binary(session_key) do
    with {:ok, client} <- OAuthClient.new(session_key),
         {:ok, oauth_session} <- SessionStore.get(session_key),
         {:ok, session} <- hydrate_oauth_session(client, oauth_session, session_key) do
      {:ok, session}
    end
  end

  @spec refresh(t()) :: {:ok, t()} | {:error, any()}
  def refresh(%__MODULE__{auth_mode: :login, client: client} = session) do
    case LoginClient.refresh(client) do
      {:ok, updated_client} -> {:ok, %{session | client: updated_client}}
      {:error, reason} -> {:error, Error.from_reason(reason)}
    end
  end

  def refresh(%__MODULE__{auth_mode: :oauth, client: client, session_key: session_key}) do
    with {:ok, _oauth_session} <- OAuthClient.refresh(client),
         {:ok, oauth_session} <- SessionStore.get(session_key),
         {:ok, session} <- hydrate_oauth_session(client, oauth_session, session_key) do
      {:ok, session}
    end
  end

  @spec switch(Plug.Conn.t(), String.t()) :: Plug.Conn.t() | no_return()
  def switch(%Plug.Conn{} = conn, session_key) when is_binary(session_key) do
    case SessionStore.get(session_key) do
      {:ok, _session} -> OAuth.switch_session(conn, session_key)
      {:error, :not_found} -> raise ArgumentError, "unknown OAuth session key"
    end
  end

  @spec current_actor(t()) :: map()
  def current_actor(%__MODULE__{} = session) do
    %{did: session.did, handle: session.handle, pds: session.pds}
  end

  @spec as_client(t()) :: LoginClient.t() | OAuthClient.t()
  def as_client(%__MODULE__{client: client}), do: client

  @spec update_client(t(), LoginClient.t() | OAuthClient.t()) :: t()
  def update_client(%__MODULE__{} = session, client), do: %{session | client: client}

  @spec authenticated?(term()) :: boolean()
  def authenticated?(%__MODULE__{}), do: true
  def authenticated?(_), do: false

  defp build_login_session(
         endpoint,
         %{"accessJwt" => access, "refreshJwt" => refresh, "did" => did} = body
       ) do
    client = LoginClient.new(endpoint, access, refresh)
    handle = body["handle"]

    identity =
      case IdentityResolver.resolve(did) do
        {:ok, identity} -> identity
        _ -> nil
      end

    pds = identity && Atex.DID.Document.get_pds_endpoint(identity.document)

    {:ok,
     %__MODULE__{
       auth_mode: :login,
       client: client,
       did: did,
       handle: handle || (identity && identity.handle),
       pds: pds || endpoint,
       identity: identity
     }}
  end

  defp build_login_session(_endpoint, _body), do: {:error, :invalid_login_response}

  defp hydrate_oauth_session(client, oauth_session, session_key) do
    identity =
      case IdentityResolver.resolve(oauth_session.sub) do
        {:ok, identity} -> identity
        _ -> nil
      end

    {:ok,
     %__MODULE__{
       auth_mode: :oauth,
       client: client,
       did: oauth_session.sub,
       handle: identity && identity.handle,
       pds: oauth_session.aud,
       session_key: session_key,
       identity: identity
     }}
  end
end
