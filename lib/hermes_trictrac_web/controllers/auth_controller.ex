defmodule HermesTrictracWeb.AuthController do
  use HermesTrictracWeb, :controller

  alias HermesTrictrac.Identity

  def bluesky_callback(conn, _args) do
    return_to =
      conn
      |> get_session(:bluesky_return_to)
      |> Identity.sanitize_return_to()

    conn
    |> delete_session(:bluesky_return_to)
    |> redirect(to: return_to)
  end

  def bluesky_logout(conn, _args) do
    conn
    |> delete_session(:bluesky_return_to)
    |> redirect(to: "/")
  end
end
