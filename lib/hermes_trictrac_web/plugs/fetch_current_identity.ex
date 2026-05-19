defmodule HermesTrictracWeb.Plugs.FetchCurrentIdentity do
  import Plug.Conn

  alias HermesTrictrac.Identity

  def init(opts), do: opts

  def call(conn, _opts) do
    current_identity =
      case Identity.from_conn(conn) do
        {:ok, identity} -> identity
        _ -> nil
      end

    conn
    |> assign(:identity_mode, Identity.mode())
    |> assign(:current_identity, current_identity)
  end
end
