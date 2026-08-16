defmodule HermesTrictrac.RaceModelBot do
  @moduledoc """
  Champion-gated Julia frontend for the non-Bräde race-game models.

  Each supported variant owns a separate session and Julia port.  The process
  protocol is intentionally identical to the established TricTrac and Bräde
  runners so a released `bestnn.data` can be hot-reloaded without restarting
  the game server.
  """

  use GenServer

  require Logger

  @timeout 120_000
  @line_limit 1_048_576
  @manifest "race-champion.json"
  @variants ~w(backgammon tapa jacquet garanguet tavli)

  def start_link(opts \\ []), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  def supported_variant?(variant), do: variant in @variants

  def available?(variant) when is_binary(variant),
    do: released_session?(variant, session_dir(variant))

  def available?(_variant), do: false
  def ready(variant), do: GenServer.call(__MODULE__, {:ready, variant}, @timeout)
  def warmup(variant), do: GenServer.cast(__MODULE__, {:warmup, variant})

  def choose_action(variant, state) when is_binary(variant) and is_map(state),
    do: GenServer.call(__MODULE__, {:choose_action, variant, state}, @timeout)

  def model_name(variant) do
    case variant do
      "backgammon" -> "BackgammonZero"
      "tapa" -> "TapaZero"
      "jacquet" -> "JacquetZero"
      "garanguet" -> "GaranguetZero"
      "tavli" -> "TavliZero"
      _ -> "RaceZero"
    end
  end

  @impl true
  def init(_opts), do: {:ok, %{clients: %{}, port_index: %{}}}

  @impl true
  def handle_call({:ready, variant}, from, state) do
    with {:ok, variant} <- validate_variant(variant),
         {:ok, state} <- ensure_port(state, variant) do
      {:noreply, enqueue(state, variant, from, :ready, %{"cmd" => "ping"})}
    else
      {:error, message} -> {:reply, {:error, message}, state}
    end
  end

  def handle_call({:choose_action, variant, serialized_state}, from, state) do
    with {:ok, variant} <- validate_variant(variant),
         {:ok, state} <- ensure_port(state, variant) do
      {:noreply,
       enqueue(state, variant, from, :choose_action, %{
         "cmd" => "choose_action",
         "state" => serialized_state
       })}
    else
      {:error, message} -> {:reply, {:error, message}, state}
    end
  end

  @impl true
  def handle_cast({:warmup, variant}, state) do
    case validate_variant(variant) do
      {:ok, variant} ->
        case ensure_port(state, variant) do
          {:ok, state} ->
            {:noreply, enqueue(state, variant, nil, :warmup, %{"cmd" => "ping"})}

          {:error, message} ->
            Logger.debug("Race champion is not warm for #{variant}: #{message}")
            {:noreply, state}
        end

      {:error, _message} ->
        {:noreply, state}
    end
  end

  @impl true
  def handle_info({port, {:data, {:noeol, chunk}}}, state) do
    case client_for_port(state, port) do
      nil ->
        {:noreply, state}

      {variant, client} ->
        {:noreply, put_client(state, variant, %{client | buffer: client.buffer <> chunk})}
    end
  end

  def handle_info({port, {:data, {:eol, line}}}, state) do
    case client_for_port(state, port) do
      nil ->
        {:noreply, state}

      {variant, client} ->
        state = put_client(state, variant, %{client | buffer: ""})
        {:noreply, handle_line(state, variant, client.buffer <> line)}
    end
  end

  def handle_info({port, {:exit_status, status}}, state) do
    case client_for_port(state, port) do
      nil ->
        {:noreply, state}

      {variant, client} ->
        reply_pending(
          client.pending,
          {:error, "#{model_name(variant)} process exited with status #{status}."}
        )

        state = put_client(state, variant, %{client | port: nil, buffer: "", pending: %{}})
        {:noreply, %{state | port_index: Map.delete(state.port_index, port)}}
    end
  end

  def handle_info(_message, state), do: {:noreply, state}

  defp ensure_port(state, variant) do
    with {:ok, _signature} <- champion_signature(variant, session_dir(variant)),
         {:ok, executable} <- julia_executable(),
         {:ok, project_dir} <- validate_path(project_dir(), :dir, "RaceZero project"),
         {:ok, script} <- validate_path(script_path(), :file, "RaceZero frontend bot script"),
         {:ok, session_dir} <-
           validate_path(session_dir(variant), :dir, "#{model_name(variant)} session") do
      client = Map.get(state.clients, variant, new_client(variant, session_dir))

      if is_nil(client.port) do
        port =
          Port.open(
            {:spawn_executable, to_charlist(executable)},
            [
              :binary,
              :use_stdio,
              :exit_status,
              {:line, @line_limit},
              {:cd, to_charlist(project_dir)},
              {:args,
               Enum.map(
                 ["--startup-file=no", "--project=#{project_dir}", script, session_dir],
                 &to_charlist/1
               )}
            ]
          )

        state = put_client(state, variant, %{client | port: port, buffer: ""})
        {:ok, %{state | port_index: Map.put(state.port_index, port, variant)}}
      else
        {:ok, put_client(state, variant, client)}
      end
    end
  end

  defp enqueue(state, variant, from, kind, payload) do
    client = Map.fetch!(state.clients, variant)
    id = client.next_id
    Port.command(client.port, Jason.encode!(Map.put(payload, "id", id)) <> "\n")

    put_client(state, variant, %{
      client
      | next_id: id + 1,
        pending: Map.put(client.pending, id, %{from: from, kind: kind})
    })
  end

  defp handle_line(state, _variant, ""), do: state

  defp handle_line(state, variant, line) do
    client = Map.fetch!(state.clients, variant)

    case Jason.decode(line) do
      {:ok, %{"id" => id} = response} ->
        case Map.pop(client.pending, id) do
          {nil, pending} ->
            put_client(state, variant, %{client | pending: pending})

          {%{from: nil}, pending} ->
            put_client(state, variant, %{client | pending: pending})

          {%{from: from, kind: kind}, pending} ->
            GenServer.reply(from, decode_response(response, kind))
            put_client(state, variant, %{client | pending: pending})
        end

      _ ->
        Logger.warning("Ignoring malformed #{model_name(variant)} output: #{line}")
        state
    end
  end

  defp decode_response(%{"ok" => true}, kind) when kind in [:ready, :warmup], do: :ok

  defp decode_response(%{"ok" => true, "result" => _}, kind) when kind in [:ready, :warmup],
    do: :ok

  defp decode_response(%{"ok" => true, "result" => %{"action" => action}}, :choose_action)
       when is_map(action), do: {:ok, action}

  defp decode_response(%{"ok" => true, "result" => action}, :choose_action) when is_map(action),
    do: {:ok, action}

  defp decode_response(%{"ok" => false, "error" => error}, _kind) when is_binary(error),
    do: {:error, error}

  defp decode_response(response, _kind),
    do: {:error, "Invalid RaceZero response: #{inspect(response)}"}

  defp released_session?(variant, dir), do: match?({:ok, _}, champion_signature(variant, dir))

  defp champion_signature(variant, dir) do
    checkpoint = Path.join(dir, "bestnn.data")
    manifest = Path.join(dir, @manifest)

    with true <- File.regular?(checkpoint),
         {:ok, %{"accepted" => true, "checkpoint" => "bestnn.data", "variant_id" => ^variant}} <-
           Jason.decode(File.read!(manifest)),
         {:ok, checkpoint_stat} <- File.stat(checkpoint),
         {:ok, manifest_stat} <- File.stat(manifest) do
      {:ok,
       {{checkpoint_stat.mtime, checkpoint_stat.size}, {manifest_stat.mtime, manifest_stat.size}}}
    else
      _ -> {:error, "No accepted race-game champion is available yet."}
    end
  rescue
    _ -> {:error, "No accepted race-game champion is available yet."}
  end

  defp validate_variant(variant) when variant in @variants, do: {:ok, variant}

  defp validate_variant(variant),
    do: {:error, "Unsupported race model preset: #{inspect(variant)}."}

  defp put_client(state, variant, client),
    do: %{state | clients: Map.put(state.clients, variant, client)}

  defp client_for_port(state, port) do
    case Map.get(state.port_index, port) do
      nil -> nil
      variant -> {variant, Map.fetch!(state.clients, variant)}
    end
  end

  defp new_client(variant, dir),
    do: %{variant: variant, session_dir: dir, port: nil, next_id: 1, pending: %{}, buffer: ""}

  defp reply_pending(pending, reply) do
    Enum.each(pending, fn
      {_id, %{from: nil}} -> :ok
      {_id, %{from: from}} -> GenServer.reply(from, reply)
    end)
  end

  defp config, do: Application.get_env(:hermes_trictrac, :race_model_bot, [])

  defp project_dir,
    do: Keyword.get(config(), :project_dir, Path.expand("../../trictrac_zero", __DIR__))

  defp script_path,
    do: Keyword.get(config(), :script, Path.join(project_dir(), "scripts/frontend_race_bot.jl"))

  defp session_dir(variant) do
    sessions = Keyword.get(config(), :session_dirs, %{})

    Map.get(
      sessions,
      variant,
      Path.join(project_dir(), "sessions/#{variant}-sparse-v1-arena96x16")
    )
  end

  defp julia_executable do
    case Keyword.get(config(), :julia, System.find_executable("julia")) do
      nil -> {:error, "Julia executable not found on PATH."}
      executable -> {:ok, executable}
    end
  end

  defp validate_path(path, :dir, label),
    do: if(File.dir?(path), do: {:ok, path}, else: {:error, "#{label} not found at #{path}."})

  defp validate_path(path, :file, label),
    do: if(File.regular?(path), do: {:ok, path}, else: {:error, "#{label} not found at #{path}."})
end
