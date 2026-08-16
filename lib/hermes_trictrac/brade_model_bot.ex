defmodule HermesTrictrac.BradeModelBot do
  @moduledoc "Champion-gated Julia frontend for the Bräde AlphaZero model."

  use GenServer

  require Logger

  @timeout 120_000
  @line_limit 1_048_576
  @default_name "BradeZero"
  @manifest "brade-champion.json"

  def start_link(opts \\ []), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  def model_name, do: Keyword.get(config(), :name, @default_name) |> to_string()
  def model_name(_preset), do: model_name()
  def available?, do: available?("brade")
  def available?("brade"), do: released_session?(session_dir())
  def available?(_preset), do: false
  def ready, do: ready("brade")
  def ready(preset), do: GenServer.call(__MODULE__, {:ready, preset}, @timeout)
  def warmup, do: warmup("brade")
  def warmup(preset), do: GenServer.cast(__MODULE__, {:warmup, preset})
  def choose_action(state), do: choose_action("brade", state)

  def choose_action("brade", state) when is_map(state),
    do: GenServer.call(__MODULE__, {:choose_action, state}, @timeout)

  def choose_action(_preset, _state), do: {:error, "Unsupported Bräde model preset."}

  @impl true
  def init(_opts), do: {:ok, %{port: nil, buffer: "", next_id: 1, pending: %{}, signature: nil}}

  @impl true
  def handle_call({:ready, "brade"}, from, state) do
    with {:ok, state} <- ensure_port(state) do
      {:noreply, enqueue(state, from, :ready, %{"cmd" => "ping"})}
    else
      {:error, message} -> {:reply, {:error, message}, state}
    end
  end

  def handle_call({:ready, _preset}, _from, state),
    do: {:reply, {:error, "Unsupported Bräde model preset."}, state}

  def handle_call({:choose_action, serialized_state}, from, state) do
    with {:ok, state} <- ensure_port(state) do
      {:noreply,
       enqueue(state, from, :choose_action, %{
         "cmd" => "choose_action",
         "state" => serialized_state
       })}
    else
      {:error, message} -> {:reply, {:error, message}, state}
    end
  end

  @impl true
  def handle_cast({:warmup, "brade"}, state) do
    case ensure_port(state) do
      {:ok, state} ->
        {:noreply, enqueue(state, nil, :warmup, %{"cmd" => "ping"})}

      {:error, message} ->
        Logger.debug("Bräde champion is not warm yet: #{message}")
        {:noreply, state}
    end
  end

  def handle_cast({:warmup, _preset}, state), do: {:noreply, state}

  @impl true
  def handle_info({port, {:data, {:noeol, chunk}}}, %{port: port} = state),
    do: {:noreply, %{state | buffer: state.buffer <> chunk}}

  def handle_info({port, {:data, {:eol, line}}}, %{port: port} = state),
    do: {:noreply, handle_line(%{state | buffer: ""}, state.buffer <> line)}

  def handle_info({port, {:exit_status, status}}, %{port: port} = state) do
    reply_pending(state.pending, {:error, "Bräde model process exited with status #{status}."})
    {:noreply, %{state | port: nil, pending: %{}, buffer: "", signature: nil}}
  end

  def handle_info(_message, state), do: {:noreply, state}

  defp ensure_port(state) do
    with {:ok, signature} <- champion_signature(),
         {:ok, executable} <- julia_executable(),
         {:ok, project_dir} <- validate_path(project_dir(), :dir, "BrädeZero project"),
         {:ok, script} <- validate_path(script_path(), :file, "Bräde frontend bot script"),
         {:ok, session_dir} <- validate_path(session_dir(), :dir, "Bräde champion session") do
      state = restart_for_new_champion(state, signature)

      if is_nil(state.port) do
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

        {:ok, %{state | port: port, signature: signature, buffer: ""}}
      else
        {:ok, state}
      end
    end
  end

  defp restart_for_new_champion(%{port: nil} = state, _signature), do: state
  defp restart_for_new_champion(%{signature: signature} = state, signature), do: state

  defp restart_for_new_champion(state, _signature) do
    reply_pending(state.pending, {:error, "Bräde champion checkpoint changed; retry the move."})
    Port.close(state.port)
    %{state | port: nil, pending: %{}, buffer: "", signature: nil}
  end

  defp enqueue(state, from, kind, payload) do
    id = state.next_id
    Port.command(state.port, Jason.encode!(Map.put(payload, "id", id)) <> "\n")
    %{state | next_id: id + 1, pending: Map.put(state.pending, id, %{from: from, kind: kind})}
  end

  defp handle_line(state, ""), do: state

  defp handle_line(state, line) do
    case Jason.decode(line) do
      {:ok, %{"id" => id} = response} ->
        case Map.pop(state.pending, id) do
          {nil, pending} ->
            %{state | pending: pending}

          {%{from: nil}, pending} ->
            %{state | pending: pending}

          {%{from: from, kind: kind}, pending} ->
            GenServer.reply(from, decode_response(response, kind))
            %{state | pending: pending}
        end

      _ ->
        Logger.warning("Ignoring malformed Bräde model bot output: #{line}")
        state
    end
  end

  defp decode_response(%{"ok" => true}, kind) when kind in [:ready, :warmup], do: :ok

  defp decode_response(%{"ok" => true, "result" => _result}, kind) when kind in [:ready, :warmup],
    do: :ok

  defp decode_response(%{"ok" => true, "result" => %{"action" => action}}, :choose_action)
       when is_map(action),
       do: {:ok, action}

  defp decode_response(%{"ok" => true, "result" => action}, :choose_action) when is_map(action),
    do: {:ok, action}

  defp decode_response(%{"ok" => false, "error" => error}, _kind) when is_binary(error),
    do: {:error, error}

  defp decode_response(response, _kind),
    do: {:error, "Invalid response from Bräde model bot: #{inspect(response)}"}

  defp reply_pending(pending, reply) do
    Enum.each(pending, fn
      {_id, %{from: nil}} -> :ok
      {_id, %{from: from}} -> GenServer.reply(from, reply)
    end)
  end

  defp released_session?(dir) do
    case champion_signature(dir) do
      {:ok, _signature} -> true
      {:error, _message} -> false
    end
  end

  defp champion_signature, do: champion_signature(session_dir())

  defp champion_signature(dir) do
    checkpoint = Path.join(dir, "bestnn.data")
    manifest = Path.join(dir, @manifest)

    with true <- File.regular?(checkpoint),
         {:ok, %{"accepted" => true, "checkpoint" => "bestnn.data"}} <-
           Jason.decode(File.read!(manifest)),
         {:ok, checkpoint_stat} <- File.stat(checkpoint),
         {:ok, manifest_stat} <- File.stat(manifest) do
      {:ok,
       {{checkpoint_stat.mtime, checkpoint_stat.size}, {manifest_stat.mtime, manifest_stat.size}}}
    else
      _ -> {:error, "No accepted Bräde champion is available yet."}
    end
  rescue
    _ -> {:error, "No accepted Bräde champion is available yet."}
  end

  defp config, do: Application.get_env(:hermes_trictrac, :brade_model_bot, [])

  defp project_dir,
    do: Keyword.get(config(), :project_dir, Path.expand("../../trictrac_zero", __DIR__))

  defp script_path,
    do: Keyword.get(config(), :script, Path.join(project_dir(), "scripts/frontend_brade_bot.jl"))

  defp session_dir,
    do:
      Keyword.get(
        config(),
        :session_dir,
        Path.join(project_dir(), "sessions/brade-sparse-v1-arena96x16")
      )

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
