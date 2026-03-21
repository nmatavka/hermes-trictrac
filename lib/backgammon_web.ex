defmodule BackgammonWeb do
  @moduledoc """
  The entrypoint for defining the web interface for the application,
  such as controllers, channels, and HTML components.
  """

  def static_paths, do: ~w(assets favicon.ico robots.txt)

  def router do
    quote do
      use Phoenix.Router, helpers: false
      import Plug.Conn
      import Phoenix.Controller
    end
  end

  def channel do
    quote do
      use Phoenix.Channel
      use Gettext, backend: BackgammonWeb.Gettext
    end
  end

  def controller do
    quote do
      use Phoenix.Controller, formats: [:html, :json]
      import Plug.Conn
      use Gettext, backend: BackgammonWeb.Gettext

      unquote(verified_routes())
    end
  end

  def html do
    quote do
      use Phoenix.Component

      import Phoenix.Controller, only: [get_csrf_token: 0, view_module: 1, view_template: 1]

      unquote(html_helpers())
    end
  end

  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end

  defp html_helpers do
    quote do
      use Gettext, backend: BackgammonWeb.Gettext
      import Phoenix.HTML

      unquote(verified_routes())
    end
  end

  def verified_routes do
    quote do
      use Phoenix.VerifiedRoutes,
        endpoint: BackgammonWeb.Endpoint,
        router: BackgammonWeb.Router,
        statics: BackgammonWeb.static_paths()
    end
  end
end
