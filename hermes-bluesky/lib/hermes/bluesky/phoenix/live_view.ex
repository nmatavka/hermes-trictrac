defmodule Hermes.Bluesky.Phoenix.LiveView do
  @moduledoc """
  LiveView-compatible session hydration helpers.
  """

  alias Hermes.Bluesky.Session

  @spec on_mount(any(), map(), map(), map()) :: {:cont, map()}
  def on_mount(_name, _params, session_data, socket) do
    session_key =
      session_data["atex_active_session"] || session_data["hermes_bluesky_active_session"]

    socket =
      case session_key do
        key when is_binary(key) ->
          case Session.from_session_key(key) do
            {:ok, bluesky_session} ->
              socket
              |> assign(:bluesky_session, bluesky_session)
              |> assign(:bluesky_session_key, key)

            _ ->
              socket
              |> assign(:bluesky_session, nil)
              |> assign(:bluesky_session_key, nil)
          end

        _ ->
          socket
          |> assign(:bluesky_session, nil)
          |> assign(:bluesky_session_key, nil)
      end

    {:cont, socket}
  end

  defp assign(socket, key, value) do
    if Code.ensure_loaded?(Phoenix.Component) and
         function_exported?(Phoenix.Component, :assign, 3) do
      apply(Phoenix.Component, :assign, [socket, key, value])
    else
      Map.update(socket, :assigns, %{key => value}, &Map.put(&1, key, value))
    end
  end
end
