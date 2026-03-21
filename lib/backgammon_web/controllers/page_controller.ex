defmodule BackgammonWeb.PageController do
  use BackgammonWeb, :controller

  def index(conn, _params) do
    render(conn, :index)
  end

  def game(conn, %{"game" => game} = params) do
    name = Map.get(params, "name", "Player")
    variant = Map.get(params, "variant", "backgammon")

    render(conn, :game, name: name, game: game, variant: variant)
  end
end
