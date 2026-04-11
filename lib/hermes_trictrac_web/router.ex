defmodule HermesTrictracWeb.Router do
  use HermesTrictracWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_flash
    plug :put_root_layout, html: {HermesTrictracWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", HermesTrictracWeb do
    pipe_through :browser

    get "/", PageController, :index
    get "/game/:game", PageController, :game
    post "/game", PageController, :game
  end
end
