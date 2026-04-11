defmodule HermesTrictrac.TrictracModelBot do
  use GenServer

  require Logger

  @timeout 120_000
  @line_limit 1_048_576
  @default_model_name "TricTracZero"
  @default_preset "classique"
  @session_layout_version "sparse-v4-arena96x16"
  @preset_configs %{
    "classique" => %{
      variant_id: "trictrac_classique",
      margot_enabled: false,
      experiment: "trictrac-classique",
      label: "Trictrac Classique"
    },
    "classique-margot" => %{
      variant_id: "trictrac_classique",
      margot_enabled: true,
      experiment: "trictrac-classique-margot",
      label: "Trictrac Classique, Margot"
    },
    "aecrire" => %{
      variant_id: "trictrac_aecrire",
      margot_enabled: false,
      experiment: "trictrac-aecrire",
      label: "Trictrac a ecrire"
    },
    "aecrire-margot" => %{
      variant_id: "trictrac_aecrire",
      margot_enabled: true,
      experiment: "trictrac-aecrire-margot",
      label: "Trictrac a ecrire, Margot"
    },
    "combine" => %{
      variant_id: "trictrac_combine",
      margot_enabled: false,
      experiment: "trictrac-combine",
      label: "Trictrac combine"
    },
    "combine-margot" => %{
      variant_id: "trictrac_combine",
      margot_enabled: true,
      experiment: "trictrac-combine-margot",
      label: "Trictrac combine, Margot"
    },
    "toc" => %{
      variant_id: "toc",
      margot_enabled: false,
      experiment: "toc",
      label: "Jeu du Toc"
    },
    "toc-margot" => %{
      variant_id: "toc",
      margot_enabled: true,
      experiment: "toc-margot",
      label: "Jeu du Toc, Margot"
    },
    "toccategli" => %{
      variant_id: "toccategli",
      margot_enabled: false,
      experiment: "toccategli",
      label: "Toccategli"
    },
    "toccategli-margot" => %{
      variant_id: "toccategli",
      margot_enabled: true,
      experiment: "toccategli-margot",
      label: "Toccategli, Margot"
    }
  }
  @supported_variants @preset_configs |> Map.values() |> Enum.map(& &1.variant_id) |> Enum.uniq()

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def model_name, do: model_name(@default_preset)

  def model_name(preset) do
    base_name =
      config()
      |> Keyword.get(:name, @default_model_name)
      |> to_string()

    case Map.get(@preset_configs, normalize_preset(preset)) do
      nil -> base_name
      preset_config -> "#{base_name} (#{preset_config.label})"
    end
  end

  def supported_variant?(variant_id), do: variant_id in @supported_variants

  def ready, do: ready(@default_preset)

  def ready(preset) when is_binary(preset) do
    GenServer.call(__MODULE__, {:ready, normalize_preset(preset)}, @timeout)
  end

  def choose_action(serialized_state) when is_map(serialized_state) do
    choose_action(preset_for_state(serialized_state), serialized_state)
  end

  def choose_action(preset, serialized_state) when is_map(serialized_state) do
    GenServer.call(
      __MODULE__,
      {:choose_action, normalize_preset(preset), serialized_state},
      @timeout
    )
  end

  @impl true
  def init(_opts) do
    send(self(), {:warmup, @default_preset})
    {:ok, %{clients: %{}, port_index: %{}}}
  end

  @impl true
  def handle_call({:ready, preset}, from, state) do
    case ensure_port(state, preset) do
      {:ok, state} ->
        {:noreply, enqueue_request(state, preset, from, %{"cmd" => "ping"}, :ready)}

      {:error, msg} ->
        {:reply, {:error, msg}, state}
    end
  end

  def handle_call({:choose_action, preset, serialized_state}, from, state) do
    case ensure_port(state, preset) do
      {:ok, state} ->
        payload = %{"cmd" => "choose_action", "state" => serialized_state}
        {:noreply, enqueue_request(state, preset, from, payload, :choose_action)}

      {:error, msg} ->
        {:reply, {:error, msg}, state}
    end
  end

  @impl true
  def handle_info({:warmup, preset}, state) do
    case ensure_port(state, preset) do
      {:ok, state} ->
        {:noreply, enqueue_request(state, preset, nil, %{"cmd" => "ping"}, :warmup)}

      {:error, msg} ->
        Logger.warning("Unable to warm TricTrac model bot at startup: #{msg}")
        {:noreply, state}
    end
  end

  def handle_info({port, {:data, {:noeol, chunk}}}, state) do
    case client_for_port(state, port) do
      nil ->
        {:noreply, state}

      {preset, client} ->
        {:noreply, put_client(state, preset, %{client | buffer: client.buffer <> chunk})}
    end
  end

  def handle_info({port, {:data, {:eol, line}}}, state) do
    case client_for_port(state, port) do
      nil ->
        {:noreply, state}

      {preset, client} ->
        state =
          state
          |> put_client(preset, %{client | buffer: ""})
          |> handle_protocol_line(preset, client.buffer <> line)

        {:noreply, state}
    end
  end

  def handle_info({port, {:exit_status, status}}, state) do
    case client_for_port(state, port) do
      nil ->
        {:noreply, state}

      {preset, client} ->
        reply_all_pending(
          client.pending,
          {:error, "TricTrac model process exited with status #{status}."}
        )

        reset_client = %{client | port: nil, pending: %{}, buffer: ""}
        state = put_client(state, preset, reset_client)

        {:noreply, %{state | port_index: Map.delete(state.port_index, port)}}
    end
  end

  def handle_info(message, state) do
    Logger.debug("Ignoring unexpected TricTrac model bot message: #{inspect(message)}")
    {:noreply, state}
  end

  defp ensure_port(state, preset) do
    with {:ok, preset} <- validate_preset(preset) do
      client = Map.get(state.clients, preset, new_client(preset))

      if is_nil(client.port) do
        with {:ok, executable} <- julia_executable(),
             {:ok, project_dir} <- validate_path(project_dir(), :dir, "TricTracZero project"),
             {:ok, script} <- validate_path(script_path(), :file, "frontend bot script"),
             {:ok, session_dir} <- validate_path(client.session_dir, :dir, "TricTracZero session") do
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

          client = %{client | port: port, buffer: ""}
          state = put_client(state, preset, client)

          {:ok, %{state | port_index: Map.put(state.port_index, port, preset)}}
        end
      else
        {:ok, put_client(state, preset, client)}
      end
    end
  end

  defp enqueue_request(state, preset, from, payload, kind) do
    client = Map.fetch!(state.clients, preset)
    id = client.next_id
    message = Map.put(payload, "id", id)
    Port.command(client.port, Jason.encode!(message) <> "\n")

    updated_client = %{
      client
      | next_id: id + 1,
        pending: Map.put(client.pending, id, %{from: from, kind: kind})
    }

    put_client(state, preset, updated_client)
  end

  defp handle_protocol_line(state, _preset, ""), do: state

  defp handle_protocol_line(state, preset, line) do
    client = Map.fetch!(state.clients, preset)

    case Jason.decode(line) do
      {:ok, %{"id" => id} = response} ->
        case Map.pop(client.pending, id) do
          {nil, pending} ->
            Logger.warning("Ignoring unsolicited TricTrac model bot response: #{line}")
            put_client(state, preset, %{client | pending: pending})

          {%{from: nil, kind: kind}, pending} ->
            case decode_response(response, kind) do
              :ok -> :ok
              {:error, msg} -> Logger.warning("TricTrac model bot warmup failed: #{msg}")
              _ -> :ok
            end

            put_client(state, preset, %{client | pending: pending})

          {%{from: from, kind: kind}, pending} ->
            GenServer.reply(from, decode_response(response, kind))
            put_client(state, preset, %{client | pending: pending})
        end

      {:ok, other} ->
        Logger.warning("Ignoring malformed TricTrac model bot payload: #{inspect(other)}")
        state

      {:error, _reason} ->
        Logger.warning("Ignoring non-protocol TricTrac model bot output: #{line}")
        state
    end
  end

  defp decode_response(%{"ok" => true}, :ready), do: :ok
  defp decode_response(%{"ok" => true}, :warmup), do: :ok
  defp decode_response(%{"ok" => true, "result" => _result}, :ready), do: :ok
  defp decode_response(%{"ok" => true, "result" => _result}, :warmup), do: :ok

  defp decode_response(%{"ok" => true, "result" => %{"action" => action}}, :choose_action)
       when is_map(action) do
    {:ok, action}
  end

  defp decode_response(%{"ok" => true, "result" => result}, :choose_action)
       when is_map(result) do
    {:ok, result}
  end

  defp decode_response(%{"ok" => false, "error" => error}, _kind) when is_binary(error) do
    {:error, error}
  end

  defp decode_response(response, _kind) do
    {:error, "Invalid response from TricTrac model bot: #{inspect(response)}"}
  end

  defp reply_all_pending(pending, reply) do
    Enum.each(pending, fn
      {_id, %{from: nil}} -> :ok
      {_id, %{from: from}} -> GenServer.reply(from, reply)
    end)
  end

  defp put_client(state, preset, client) do
    %{state | clients: Map.put(state.clients, preset, client)}
  end

  defp client_for_port(state, port) do
    case Map.get(state.port_index, port) do
      nil -> nil
      preset -> {preset, Map.get(state.clients, preset, new_client(preset))}
    end
  end

  defp new_client(preset) do
    %{
      preset: preset,
      session_dir: session_dir(preset),
      port: nil,
      next_id: 1,
      pending: %{},
      buffer: ""
    }
  end

  defp validate_preset(preset) do
    preset = normalize_preset(preset)

    if Map.has_key?(@preset_configs, preset) do
      {:ok, preset}
    else
      {:error, "Unsupported TricTrac model preset: #{preset}."}
    end
  end

  defp preset_for_state(serialized_state) do
    variant_id =
      get_in(serialized_state, ["runtime", "match", "variant_id"]) ||
        get_in(serialized_state, ["runtime", "match", :variant_id]) ||
        @preset_configs[@default_preset].variant_id

    options =
      get_in(serialized_state, ["runtime", "match", "options"]) ||
        get_in(serialized_state, ["runtime", "match", :options]) ||
        %{}

    margot_enabled =
      Map.get(options, "margotEnabled", Map.get(options, :margotEnabled, false)) in [
        true,
        "true",
        "yes",
        "on"
      ]

    @preset_configs
    |> Enum.find_value(@default_preset, fn {preset, config} ->
      if config.variant_id == variant_id and config.margot_enabled == margot_enabled,
        do: preset,
        else: nil
    end)
  end

  defp normalize_preset(preset) do
    preset
    |> to_string()
    |> String.downcase()
  end

  defp config do
    Application.get_env(:hermes_trictrac, :trictrac_model_bot, [])
  end

  defp project_dir do
    Keyword.get(config(), :project_dir, Path.expand("../../trictrac_zero", __DIR__))
  end

  defp script_path do
    Keyword.get(config(), :script, Path.join(project_dir(), "scripts/frontend_bot.jl"))
  end

  defp session_dir(preset) do
    session_dirs =
      config()
      |> Keyword.get(:session_dirs, %{})
      |> normalize_key_map()

    cond do
      Map.has_key?(session_dirs, preset) ->
        Map.fetch!(session_dirs, preset)

      preset == @default_preset ->
        Keyword.get(config(), :session_dir, default_session_dir(preset))

      true ->
        default_session_dir(preset)
    end
  end

  defp default_session_dir(preset) do
    experiment = @preset_configs |> Map.fetch!(preset) |> Map.fetch!(:experiment)
    Path.join(project_dir(), "sessions/#{experiment}-#{@session_layout_version}")
  end

  defp julia_executable do
    case Keyword.get(config(), :julia, System.find_executable("julia")) do
      nil -> {:error, "Julia executable not found on PATH."}
      executable -> {:ok, executable}
    end
  end

  defp validate_path(path, :dir, label) do
    if File.dir?(path) do
      {:ok, path}
    else
      {:error, "#{label} not found at #{path}."}
    end
  end

  defp validate_path(path, :file, label) do
    if File.regular?(path) do
      {:ok, path}
    else
      {:error, "#{label} not found at #{path}."}
    end
  end

  defp normalize_key_map(map) when is_map(map) do
    Enum.into(map, %{}, fn {key, value} -> {to_string(key), value} end)
  end

  defp normalize_key_map(list) when is_list(list) do
    Enum.into(list, %{}, fn {key, value} -> {to_string(key), value} end)
  end

  defp normalize_key_map(_other), do: %{}
end
