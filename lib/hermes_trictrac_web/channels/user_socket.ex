defmodule HermesTrictracWeb.UserSocket do
  use Phoenix.Socket

  alias HermesTrictrac.Identity

  ## Channels
  channel "games:*", HermesTrictracWeb.GamesChannel

  # Socket params are passed from the client and can
  # be used to verify and authenticate a user. After
  # verification, you can put default assigns into
  # the socket that will be set for all channels, ie
  #
  #     {:ok, assign(socket, :user_id, verified_user_id)}
  #
  # To deny connection, return `:error`.
  #
  # See `Phoenix.Token` documentation for examples in
  # performing token verification on connect.
  def connect(_params, socket, connect_info) do
    identity_mode = Identity.mode()

    cond do
      Identity.manual?(identity_mode) ->
        {:ok, assign(socket, :identity_mode, identity_mode)}

      true ->
        session = Map.get(connect_info || %{}, :session, %{})

        case Identity.from_session_map(session) do
          {:ok, identity} ->
            {:ok,
             socket
             |> assign(:identity_mode, identity_mode)
             |> assign(:identity, identity)
             |> assign(:identity_did, identity.did)
             |> assign(:identity_handle, identity.handle)
             |> assign(:identity_session_key, identity.session_key)}

          _ ->
            :error
        end
    end
  end

  # Socket id's are topics that allow you to identify all sockets for a given user:
  #
  #     def id(socket), do: "user_socket:#{socket.assigns.user_id}"
  #
  # Would allow you to broadcast a "disconnect" event and terminate
  # all active sockets and channels for a given user:
  #
  #     HermesTrictracWeb.Endpoint.broadcast("user_socket:#{user.id}", "disconnect", %{})
  #
  # Returning `nil` makes this socket anonymous.
  def id(%{assigns: %{identity_mode: :bluesky_oauth, identity_did: did}}) when is_binary(did),
    do: "user_socket:#{did}"

  def id(_socket), do: nil
end
