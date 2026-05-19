defmodule Hermes.Bluesky.Phoenix.Conn do
  @moduledoc """
  Plug session helpers for Hermes Bluesky OAuth sessions.
  """

  alias Atex.OAuth
  alias Atex.OAuth.{Discovery, Flow, SessionStore}
  alias Hermes.Bluesky.Session

  @spec current_session_key(Plug.Conn.t()) :: String.t() | nil
  def current_session_key(conn), do: OAuth.current_session_key(conn)

  @spec list_session_keys(Plug.Conn.t()) :: [String.t()]
  def list_session_keys(conn), do: OAuth.list_session_keys(conn)

  @spec current_session(Plug.Conn.t()) :: {:ok, Session.t()} | :error | {:error, any()}
  def current_session(conn) do
    case current_session_key(conn) do
      nil -> :error
      session_key -> Session.from_session_key(session_key)
    end
  end

  @spec switch_session(Plug.Conn.t(), String.t()) :: Plug.Conn.t()
  def switch_session(conn, session_key) do
    Session.switch(conn, session_key)
  end

  @spec logout(Plug.Conn.t(), String.t() | nil) :: Plug.Conn.t()
  def logout(conn, session_key \\ nil) do
    session_key = session_key || current_session_key(conn)

    case session_key do
      nil ->
        conn

      key ->
        case revoke_session(conn, key) do
          {:ok, updated_conn} -> updated_conn
          {:error, _reason} -> conn
        end
    end
  end

  @spec revoke_session(Plug.Conn.t(), String.t()) :: {:ok, Plug.Conn.t()} | {:error, :not_found}
  def revoke_session(conn, session_key) do
    with {:ok, oauth_session} <- SessionStore.get(session_key) do
      revoke_tokens_best_effort(oauth_session)
      _ = SessionStore.delete(oauth_session)

      session_keys = list_session_keys(conn) |> List.delete(session_key)
      active_key = current_session_key(conn)
      next_active = if active_key == session_key, do: List.first(session_keys), else: active_key

      conn =
        conn
        |> Plug.Conn.put_session(OAuth.session_keys_name(), session_keys)
        |> put_active_session(next_active)

      {:ok, conn}
    else
      {:error, :not_found} -> {:error, :not_found}
    end
  end

  defp revoke_tokens_best_effort(oauth_session) do
    with {:ok, metadata} <- Discovery.get_authorization_server_metadata(oauth_session.iss) do
      Flow.revoke_tokens(oauth_session, metadata)
    end

    :ok
  end

  defp put_active_session(conn, nil),
    do: Plug.Conn.delete_session(conn, OAuth.session_active_session_name())

  defp put_active_session(conn, session_key),
    do: Plug.Conn.put_session(conn, OAuth.session_active_session_name(), session_key)
end
