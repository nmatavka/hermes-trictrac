defmodule HermesTrictracWeb.GamesChannel do
  use HermesTrictracWeb, :channel

  alias HermesTrictrac.Identity

  intercept ["update"]

  def join("games:" <> name, payload, socket) do
    identity_mode = socket.assigns[:identity_mode] || Identity.mode()
    user = join_user(socket, payload, identity_mode)

    if authorized?(socket, payload, user) do
      variant = Map.get(payload, "variant", "backgammon")
      bot = Map.get(payload, "bot")
      bot_margot = Map.get(payload, "bot_margot")
      client_id = client_id(socket, payload)
      auth_id = socket.assigns[:identity_did]
      HermesTrictrac.GameServer.reg(name)
      HermesTrictrac.GameServer.start(name, variant, start_opts_from_payload(payload, variant))

      reply =
        HermesTrictrac.GameServer.join(name, user, client_id, variant, %{
          "bot" => bot,
          "bot_margot" => bot_margot,
          "queue_size" => Map.get(payload, "queue_size"),
          "ante" => Map.get(payload, "ante"),
          "stake" => Map.get(payload, "stake"),
          "hole_value" => Map.get(payload, "hole_value"),
          "margot_enabled" => Map.get(payload, "margot_enabled"),
          "cash_per_jeton_minor" => Map.get(payload, "cash_per_jeton_minor"),
          "auth_id" => auth_id
        })

      socket =
        socket
        |> assign(:name, name)
        |> assign(:user, user)
        |> assign(:auth_id, auth_id)
        |> assign(:variant, variant)
        |> assign(:bot, bot)
        |> assign(:bot_margot, bot_margot)
        |> assign(:client_id, client_id)

      case reply do
        {:ok, %{game: game, player: player}} ->
          send(self(), {:joined_game_state, game})
          {:ok, %{game: game, player: player, viewer: game["viewer"]}, socket}

        {:error, %{msg: _msg} = error} ->
          {:error, error_payload(error)}

        {:error, msg} ->
          {:error, error_payload(msg)}

        _ ->
          {:error, error_payload("unknown error")}
      end
    else
      {:error, %{reason: "unauthorized", code: "unauthorized", msg: "unauthorized"}}
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
        {:reply, {:ok, %{}}, socket}

      {:error, msg} ->
        {:reply, {:error, error_payload(msg)}, socket}

      _ ->
        {:reply, {:error, error_payload("unknown error")}, socket}
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
        {:reply, {:ok, %{}}, socket}

      {:error, msg} ->
        {:reply, {:error, error_payload(msg)}, socket}
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
        {:reply, {:ok, %{}}, socket}

      {:error, msg} ->
        {:reply, {:error, error_payload(msg)}, socket}
    end
  end

  def handle_in("remain_seated", _payload, socket) do
    case HermesTrictrac.GameServer.remain_seated(
           socket.assigns[:name],
           socket.assigns[:user],
           socket.assigns[:client_id]
         ) do
      {:ok, game} ->
        set_game_and_notify(socket, game)
        {:reply, {:ok, %{}}, socket}

      {:error, msg} ->
        {:reply, {:error, error_payload(msg)}, socket}
    end
  end

  def handle_in("chat", payload, socket) do
    user = socket.assigns[:user]

    g =
      HermesTrictrac.GameServer.chat(
        socket.assigns[:name],
        payload["chat"],
        user,
        socket.assigns[:client_id]
      )

    case g do
      {:ok, game} ->
        set_game_and_notify(socket, game)
        {:reply, {:ok, %{}}, socket}

      {:error, msg} ->
        {:reply, {:error, error_payload(msg)}, socket}

      _ ->
        {:reply, {:error, error_payload("unknown error")}, socket}
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
        {:reply, {:ok, %{}}, socket}

      {:error, msg} ->
        {:reply, {:error, error_payload(msg)}, socket}

      _ ->
        {:reply, {:error, error_payload("unknown error")}, socket}
    end
  end

  def handle_in("undo", _payload, socket) do
    user = socket.assigns[:user]

    case HermesTrictrac.GameServer.undo(socket.assigns[:name], user, socket.assigns[:client_id]) do
      {:ok, game} ->
        set_game_and_notify(socket, game)
        {:reply, {:ok, %{}}, socket}

      {:error, msg} ->
        {:reply, {:error, error_payload(msg)}, socket}
    end
  end

  def handle_in("confirm", _payload, socket) do
    user = socket.assigns[:user]

    case HermesTrictrac.GameServer.confirm(
           socket.assigns[:name],
           user,
           socket.assigns[:client_id]
         ) do
      {:ok, game} ->
        set_game_and_notify(socket, game)
        {:reply, {:ok, %{}}, socket}

      {:error, msg} ->
        {:reply, {:error, error_payload(msg)}, socket}
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
        {:reply, {:ok, %{}}, socket}

      {:error, msg} ->
        {:reply, {:error, error_payload(msg)}, socket}
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
        {:reply, {:ok, %{}}, socket}

      {:error, msg} ->
        {:reply, {:error, error_payload(msg)}, socket}
    end
  end

  def handle_in("claim_queue_spot", _payload, socket) do
    case HermesTrictrac.GameServer.claim_queue_spot(
           socket.assigns[:name],
           socket.assigns[:user],
           socket.assigns[:client_id]
         ) do
      {:ok, game} ->
        set_game_and_notify(socket, game)
        {:reply, {:ok, %{}}, socket}

      {:error, msg} ->
        {:reply, {:error, error_payload(msg)}, socket}
    end
  end

  def handle_in("claim_roster_slot", _payload, socket) do
    case HermesTrictrac.GameServer.claim_roster_slot(
           socket.assigns[:name],
           socket.assigns[:user],
           socket.assigns[:client_id]
         ) do
      {:ok, game} ->
        set_game_and_notify(socket, game)
        {:reply, {:ok, %{}}, socket}

      {:error, msg} ->
        {:reply, {:error, error_payload(msg)}, socket}
    end
  end

  def handle_info({:joined_game_state, game}, socket) do
    set_game_and_notify(socket, game)
    {:noreply, socket}
  end

  def handle_out("update", %{game: game}, socket) do
    viewer =
      HermesTrictrac.GameServer.viewer(
        socket.assigns[:name],
        socket.assigns[:user],
        socket.assigns[:client_id]
      )

    push(socket, "update", %{game: Map.put(game, "viewer", viewer)})
    {:noreply, socket}
  end

  def terminate(_reason, socket) do
    if GenServer.whereis(HermesTrictrac.GameServer.reg(socket.assigns[:name])) do
      _ =
        HermesTrictrac.GameServer.leave(
          socket.assigns[:name],
          socket.assigns[:user],
          socket.assigns[:client_id]
        )
    end

    :ok
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

  defp start_opts_from_payload(payload, variant) do
    if HermesTrictrac.Rules.Registry.session_variant?(variant) do
      %{
        "queue_size" => Map.get(payload, "queue_size"),
        "ante" => Map.get(payload, "ante"),
        "stake" => Map.get(payload, "stake"),
        "hole_value" => Map.get(payload, "hole_value"),
        "margot_enabled" => Map.get(payload, "margot_enabled"),
        "cash_per_jeton_minor" => Map.get(payload, "cash_per_jeton_minor")
      }
    else
      %{}
    end
  end

  defp error_payload(%{msg: msg} = payload) do
    Map.put_new(payload, :code, error_code(msg))
  end

  defp error_payload(msg) when is_binary(msg) do
    %{msg: msg, code: error_code(msg)}
  end

  defp error_payload(_msg), do: %{msg: "unknown error", code: "unknown"}

  defp error_code("unknown error"), do: "unknown"
  defp error_code("Lobby is full."), do: "lobby_full"
  defp error_code("Player not found in lobby."), do: "player_not_found"
  defp error_code("Match is already over."), do: "match_over"
  defp error_code("Not your turn."), do: "not_your_turn"
  defp error_code("Invalid move."), do: "invalid_move"
  defp error_code("No rolled dice to confirm."), do: "no_rolled_dice"
  defp error_code("Turn obligations not fulfilled."), do: "turn_obligations"

  defp error_code("Coin de repos must end the turn with 0 or at least 2 checkers."),
    do: "coin_rest"

  defp error_code("Only the host can submit match options."), do: "only_host_options"
  defp error_code("Only an active player can do that."), do: "inactive_viewer"
  defp error_code("Only a rostered competitor can participate in the order draw."),
    do: "inactive_viewer"

  defp error_code("No open queue slot is available."), do: "no_open_queue_slot"
  defp error_code("Only spectators can claim an open queue slot."), do: "queue_claim_unavailable"
  defp error_code("Reset is only available after the match is over."), do: "reset_unavailable"
  defp error_code("BackgammonAI is only available for English backgammon."), do: "bot_unavailable"

  defp error_code("Bot opponents are not available for multi-seat tables."),
    do: "bot_unavailable"

  defp error_code("No open roster slot is available."), do: "no_open_roster_slot"

  defp error_code("Only spectators can claim an open roster slot."),
    do: "roster_claim_unavailable"

  defp error_code("Only a rostered competitor can submit match options."),
    do: "match_options_unavailable"

  defp error_code("Match options are not available right now."),
    do: "match_options_unavailable"

  defp error_code("Choose a valid coup length."),
    do: "invalid_match_option"

  defp error_code("Resign is unavailable for plucked-pool tables."),
    do: "resign_unavailable"

  defp error_code("Unsupported bot option."), do: "bot_unavailable"

  defp error_code("Lobby \"" <> _rest), do: "variant_mismatch"
  defp error_code("Configured bot" <> _rest), do: "bot_unavailable"
  defp error_code("Unsupported bot" <> _rest), do: "bot_unavailable"
  defp error_code("Bot " <> _rest), do: "bot_unavailable"
  defp error_code(_msg), do: "unknown"

  # Add authorization logic here as required.
  defp authorized?(socket, _payload, user) do
    identity_mode = socket.assigns[:identity_mode] || Identity.mode()

    case identity_mode do
      :manual -> is_binary(user) and String.trim(user) != ""
      :bluesky_oauth -> is_binary(socket.assigns[:identity_did]) and is_binary(user)
      _ -> false
    end
  end

  defp join_user(socket, _payload, :bluesky_oauth) do
    socket.assigns[:identity_handle] ||
      socket.assigns[:identity_did] ||
      get_in(socket.assigns, [:identity, :handle]) ||
      get_in(socket.assigns, [:identity, :did])
  end

  defp join_user(_socket, payload, _mode) do
    Map.get(payload, "user")
  end
end
