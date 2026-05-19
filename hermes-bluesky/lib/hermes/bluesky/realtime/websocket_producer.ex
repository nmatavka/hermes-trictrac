# Provenance:
# - Adapted from bsky-keyword-labeler-main/apps/bsky_labeler/lib/bsky_labeler/utils/websocket_producer.ex (GPL-3.0-or-later)
defmodule Hermes.Bluesky.Realtime.WebsocketProducer do
  @moduledoc """
  Generic GenStage producer for websocket streams with reconnect support.
  """

  alias Wesex.Connection
  import System, only: [monotonic_time: 0]
  require Logger
  use GenStage

  @type closing_reason :: {:local, stop_code_reason()} | {:remote, stop_code_reason()}
  @type closed_reason ::
          {:remote, stop_code_reason()}
          | {:error, :timeout | :aborted | :closed_in_handshake | :unexpected_tcp_close}

  @type stop_code_reason() :: {1000..4999 | nil, binary() | nil}

  @reconnect_after 15_000

  def start_link(opts) do
    keys = [:uri, :headers, :flat_mapper, :event_cb]
    {config, gen_server_opts} = Keyword.split(opts, keys)
    Keyword.validate!(config, keys)
    GenStage.start_link(__MODULE__, config, gen_server_opts)
  end

  def child_spec(opts) do
    name = opts[:name]

    %{
      id: name || __MODULE__,
      start: {__MODULE__, :start_link, [opts]}
    }
  end

  def get_load(producer), do: GenStage.call(producer, :get_load)

  @impl GenStage
  def init(config) do
    flat_mapper =
      config[:flat_mapper] ||
        %{
          acc: nil,
          fun: fn element, acc -> {[element], acc} end
        }

    timer = Process.send_after(self(), :connect_timer, 0)

    state = %{
      uri: config[:uri],
      headers: config[:headers] || [],
      flat_mapper: flat_mapper,
      event_cb: config[:event_cb],
      conn: nil,
      remaining_demand: 0,
      messages: :queue.new(),
      connect_timer: timer,
      load: 0.0,
      last_handle_demand_time: monotonic_time()
    }

    Process.flag(:trap_exit, true)
    {:producer, state, buffer_size: :infinity}
  end

  @impl GenStage
  def terminate(reason, state) do
    if (reason == :shutdown or match?({:shutdown, _}, reason)) and state.conn do
      {queued_events, conn} =
        state.messages
        |> :queue.to_list()
        |> Enum.flat_map_reduce(state.conn, fn message, conn ->
          Connection.event(conn, message) ||
            (
              tap_unhandled_message(message)
              {[], conn}
            )
        end)

      if Connection.status(conn) != :closed do
        {events, conn} = Connection.close(conn, {1000, nil})
        receive_until_close(queued_events ++ events, conn, state.event_cb)
      end
    end
  end

  defp receive_until_close([], conn, event_cb) do
    receive do
      info when not (is_tuple(info) and elem(info, 0) == :"$gen_producer") ->
        case Connection.event(conn, info) do
          false -> tap_unhandled_message(info)
          {result_events, conn} -> receive_until_close(result_events, conn, event_cb)
        end
    end
  end

  defp receive_until_close([{:received, {:text, _payload}} | rest], conn, event_cb),
    do: receive_until_close(rest, conn, event_cb)

  defp receive_until_close([{:closing, reason} | rest], conn, event_cb) do
    callback(event_cb, {:closing, reason})
    receive_until_close(rest, conn, event_cb)
  end

  defp receive_until_close([{:closed, reason} | _rest], _conn, event_cb) do
    callback(event_cb, {:closed, reason, nil})
  end

  @impl GenStage
  def handle_call(:get_load, _from, state) do
    state = calc_load(monotonic_time(), state)
    {:reply, state.load, [], state}
  end

  @impl GenStage
  def handle_info(:connect_timer, state) do
    state = %{state | connect_timer: nil}
    uri = if is_function(state.uri), do: state.uri.(), else: state.uri
    callback(state.event_cb, {:connecting, uri})

    case Connection.connect(uri, state.headers, Wesex.MintAdapter, conn: [protocols: [:http1]]) do
      {:ok, conn} ->
        conn = %{conn | ping_timeout: fn -> nil end}
        {:noreply, [], %{state | conn: conn}}

      {:error, reason} ->
        timer = Process.send_after(self(), :connect_timer, @reconnect_after)
        callback(state.event_cb, {:connect_error, reason, @reconnect_after})
        {:noreply, [], %{state | connect_timer: timer}}
    end
  end

  def handle_info(message, state) do
    state = update_in(state.messages, &:queue.in(message, &1))

    cond do
      state.remaining_demand == 0 ->
        {:noreply, [], state}

      state.remaining_demand > 0 ->
        handle_additional_demand(0, state)
    end
  end

  @impl GenStage
  def handle_demand(demand, state) do
    handle_additional_demand(demand, state)
  end

  defp handle_additional_demand(demand, state) do
    start = monotonic_time()

    {conn, datas, flat_mapper} =
      stream_all_messages(state.conn, state.messages, state.flat_mapper, state.event_cb)

    timer =
      if !state.connect_timer and Wesex.Connection.status(conn) == :closed do
        Process.send_after(self(), :connect_timer, @reconnect_after)
      else
        state.connect_timer
      end

    count = Enum.count(datas)
    remaining_demand = max(state.remaining_demand + demand - count, 0)
    state = calc_load(start, state)

    state = %{
      state
      | conn: conn,
        messages: :queue.new(),
        flat_mapper: flat_mapper,
        remaining_demand: remaining_demand,
        connect_timer: timer
    }

    {:noreply, datas, state}
  end

  defp calc_load(start, state) do
    now = monotonic_time()
    duration = now - start
    idle_duration = start - state.last_handle_demand_time
    current_load = duration / max(duration + idle_duration, 1)

    time_constant = System.convert_time_unit(100, :millisecond, :native)
    dt = now - state.last_handle_demand_time
    alpha = 1 - :math.exp(-dt / time_constant)
    smoothed_load = alpha * current_load + (1 - alpha) * state.load

    %{state | load: smoothed_load, last_handle_demand_time: now}
  end

  defp stream_all_messages(conn, messages, flat_mapper, event_cb) do
    case :queue.out(messages) do
      {:empty, _messages} ->
        {conn, [], flat_mapper}

      {{:value, message}, messages} ->
        case Wesex.Connection.event(conn, message) do
          {events, conn} ->
            datas = Enum.flat_map(events, &do_events(&1, event_cb))

            {datas, flat_mapper_acc} =
              Enum.flat_map_reduce(datas, flat_mapper.acc, flat_mapper.fun)

            flat_mapper = %{flat_mapper | acc: flat_mapper_acc}
            {conn, rest, flat_mapper} = stream_all_messages(conn, messages, flat_mapper, event_cb)
            {conn, datas ++ rest, flat_mapper}

          false ->
            tap_unhandled_message(message)
            stream_all_messages(conn, messages, flat_mapper, event_cb)
        end
    end
  end

  defp do_events(:open, event_cb) do
    callback(event_cb, :open)
    []
  end

  defp do_events({:received, data}, _event_cb), do: [data]

  defp do_events({:closing, reason}, event_cb) do
    callback(event_cb, {:closing, reason})
    []
  end

  defp do_events({:closed, reason}, event_cb) do
    callback(event_cb, {:closed, reason, @reconnect_after})
    []
  end

  defp callback(nil, _arg), do: nil
  defp callback(fun, arg), do: fun.(arg)

  defp tap_unhandled_message(message) do
    Logger.warning("Unhandled websocket message: #{inspect(message)}")
    false
  end
end
