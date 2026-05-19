defmodule HermesTrictracWeb.Router do
  use HermesTrictracWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_flash
    plug :put_root_layout, html: {HermesTrictracWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug HermesTrictracWeb.Plugs.FetchCurrentIdentity
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", HermesTrictracWeb do
    pipe_through :browser

    get "/", PageController, :index
    get "/dev/model-lab", PageController, :model_lab
    get "/game/:game", PageController, :game
    post "/game", PageController, :game
  end

  scope "/dev", HermesTrictracWeb do
    pipe_through :api

    post "/model-lab/parse", ModelAnalysisController, :parse
    post "/model-lab/run", ModelAnalysisController, :run
  end

  scope "/auth", HermesTrictracWeb do
    pipe_through :browser

    forward "/bluesky", BlueskyOAuthPlug,
      callback: {AuthController, :bluesky_callback, []},
      logout_callback: {AuthController, :bluesky_logout, []}
  end
end
