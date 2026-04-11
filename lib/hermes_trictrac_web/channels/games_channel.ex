defmodule HermesTrictracWeb.GamesChannel do
  use HermesTrictracWeb, :channel

  def join("games:" <> name, %{"user" => user} = payload, socket) do
    if authorized?(payload) do
      variant = Map.get(payload, "variant", "backgammon")
      bot = Map.get(payload, "bot")
      bot_margot = Map.get(payload, "bot_margot")
      client_id = client_id(socket, payload)
      HermesTrictrac.GameServer.reg(name)
      HermesTrictrac.GameServer.start(name, variant)

      reply =
        HermesTrictrac.GameServer.join(name, user, client_id, variant, %{
          "bot" => bot,
          "bot_margot" => bot_margot
        })

      socket =
        socket
        |> assign(:name, name)
        |> assign(:user, user)
        |> assign(:variant, variant)
        |> assign(:bot, bot)
        |> assign(:bot_margot, bot_margot)
        |> assign(:client_id, client_id)

      case reply do
        {:ok, %{game: game, player: player}} ->
          send(self(), {:joined_game_state, game})
          {:ok, %{game: game, player: player}, socket}

        {:error, msg} ->
          {:error, %{msg: msg}}

        _ ->
          {:error, %{msg: "unknown error"}}
      end
    else
      {:error, %{reason: "unauthorized"}}
    end
  end

  def set_game_and_notify(socket, game) do
    broadcast(socket, "update", %{game: game})
  end

  def handle_in("roll", _payload, socket) do
    user = socket.assigns[:user]
    g = HermesTrictrac.GameServer.roll(socket.assigns[:name], user, socket.assigns[:client_id])

    case g do
      {:ok, game} ->
        set_game_and_notify(socket, game)
        {:noreply, socket}

      {:error, msg} ->
        {:reply, {:error, %{msg: msg}}, socket}

      _ ->
        {:reply, {:error, %{msg: "unknown error"}}, socket}
    end
  end

  def handle_in("reset", _payload, socket) do
    case HermesTrictrac.GameServer.reset(
           socket.assigns[:name],
           socket.assigns[:user],
           socket.assigns[:client_id]
         ) do
      {:ok, game} ->
        set_game_and_notify(socket, game)
        {:noreply, socket}

      {:error, msg} ->
        {:reply, {:error, %{msg: msg}}, socket}
    end
  end

  def handle_in("resign", _payload, socket) do
    case HermesTrictrac.GameServer.resign(
           socket.assigns[:name],
           socket.assigns[:user],
           socket.assigns[:client_id]
         ) do
      {:ok, game} ->
        set_game_and_notify(socket, game)
        {:noreply, socket}

      {:error, msg} ->
        {:reply, {:error, %{msg: msg}}, socket}
    end
  end

  def handle_in("chat", payload, socket) do
    user = socket.assigns[:user]
    g = HermesTrictrac.GameServer.chat(socket.assigns[:name], payload["chat"], user)

    case g do
      {:ok, game} ->
        set_game_and_notify(socket, game)
        {:noreply, socket}

      {:error, msg} ->
        {:reply, {:error, %{msg: msg}}, socket}

      _ ->
        {:reply, {:error, %{msg: "unknown error"}}, socket}
    end
  end

  def handle_in("move", payload, socket) do
    user = socket.assigns[:user]
    move = parse_move(payload["move"] || %{})

    g =
      HermesTrictrac.GameServer.move(
        socket.assigns[:name],
        move,
        user,
        socket.assigns[:client_id]
      )

    case g do
      {:ok, game} ->
        set_game_and_notify(socket, game)
        {:noreply, socket}

      {:error, msg} ->
        {:reply, {:error, %{msg: msg}}, socket}

      _ ->
        {:reply, {:error, %{msg: "unknown error"}}, socket}
    end
  end

  def handle_in("undo", _payload, socket) do
    user = socket.assigns[:user]

    case HermesTrictrac.GameServer.undo(socket.assigns[:name], user, socket.assigns[:client_id]) do
      {:ok, game} ->
        set_game_and_notify(socket, game)
        {:noreply, socket}

      {:error, msg} ->
        {:reply, {:error, %{msg: msg}}, socket}
    end
  end

  def handle_in("confirm", _payload, socket) do
    user = socket.assigns[:user]

    case HermesTrictrac.GameServer.confirm(socket.assigns[:name], user, socket.assigns[:client_id]) do
      {:ok, game} ->
        set_game_and_notify(socket, game)
        {:noreply, socket}

      {:error, msg} ->
        {:reply, {:error, %{msg: msg}}, socket}
    end
  end

  def handle_in("submit_match_options", %{"options" => options}, socket) do
    user = socket.assigns[:user]

    case HermesTrictrac.GameServer.submit_match_options(
           socket.assigns[:name],
           options,
           user,
           socket.assigns[:client_id]
         ) do
      {:ok, game} ->
        set_game_and_notify(socket, game)
        {:noreply, socket}

      {:error, msg} ->
        {:reply, {:error, %{msg: msg}}, socket}
    end
  end

  def handle_in("submit_turn_decision", %{"decision" => decision}, socket) do
    user = socket.assigns[:user]

    case HermesTrictrac.GameServer.submit_turn_decision(
           socket.assigns[:name],
           decision,
           user,
           socket.assigns[:client_id]
         ) do
      {:ok, game} ->
        set_game_and_notify(socket, game)
        {:noreply, socket}

      {:error, msg} ->
        {:reply, {:error, %{msg: msg}}, socket}
    end
  end

  def handle_info({:joined_game_state, game}, socket) do
    set_game_and_notify(socket, game)
    {:noreply, socket}
  end

  defp parse_move(%{"from" => from, "to" => to} = payload) do
    %{}
    |> Map.put("from", parse_space(from))
    |> Map.put("to", parse_space(to))
    |> maybe_put_sequence(payload)
  end

  defp maybe_put_sequence(move, payload) do
    case Map.get(payload, "sequence") do
      sequence when is_list(sequence) ->
        Map.put(move, "sequence", Enum.map(sequence, &parse_sequence_step/1))

      _ ->
        move
    end
  end

  defp parse_sequence_step(step) when is_integer(step), do: step

  defp parse_sequence_step(step) when is_binary(step) do
    case Integer.parse(step) do
      {value, ""} -> value
      _ -> step
    end
  end

  defp parse_sequence_step(step), do: step

  defp parse_space(space) when is_integer(space), do: space
  defp parse_space("bar"), do: "bar"
  defp parse_space("home"), do: "home"

  defp parse_space(space) when is_binary(space) do
    case Integer.parse(space) do
      {value, ""} -> value
      _ -> space
    end
  end

  defp client_id(_socket, payload) do
    case Map.get(payload, "client_id") do
      client_id when is_binary(client_id) ->
        client_id
        |> String.trim()
        |> case do
          "" -> transient_client_id()
          trimmed -> trimmed
        end

      _ ->
        transient_client_id()
    end
  end

  defp transient_client_id do
    "anonymous:#{System.unique_integer([:positive])}"
  end

  # Add authorization logic here as required.
  defp authorized?(_payload) do
    true
  end
end
