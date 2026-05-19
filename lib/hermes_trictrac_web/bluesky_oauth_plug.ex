defmodule HermesTrictracWeb.BlueskyOAuthPlug do
  import Plug.Conn

  alias Hermes.Bluesky.Phoenix.OAuthPlug
  alias HermesTrictrac.Identity

  def init(opts), do: OAuthPlug.init(opts)

  def call(conn, opts) do
    conn
    |> maybe_prepare_login()
    |> maybe_delegate(opts)
  end

  defp maybe_prepare_login(%Plug.Conn{request_path: "/auth/bluesky/login"} = conn) do
    conn = fetch_query_params(conn)
    handle = conn.query_params["handle"] |> normalize_handle()
    return_to = Identity.sanitize_return_to(conn.query_params["return_to"])

    conn = put_session(conn, :bluesky_return_to, return_to)

    if is_nil(handle) do
      conn
      |> Phoenix.Controller.redirect(to: return_to)
      |> halt()
    else
      conn
    end
  end

  defp maybe_prepare_login(conn), do: conn

  defp maybe_delegate(%Plug.Conn{halted: true} = conn, _opts), do: conn
  defp maybe_delegate(conn, opts), do: OAuthPlug.call(conn, opts)

  defp normalize_handle(handle) when is_binary(handle) do
    case String.trim(handle) do
      "" -> nil
      trimmed -> trimmed
    end
  end

  defp normalize_handle(_handle), do: nil
end
