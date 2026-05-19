# Provenance:
# - Adapted from bsky-keyword-labeler-main/apps/bsky_labeler/lib/bsky_labeler/pipeline/s1_bsky_producer.ex (GPL-3.0-or-later)
defmodule Hermes.Bluesky.Realtime.Jetstream do
  @moduledoc """
  Generic Jetstream websocket producer and event normalizer.
  """

  alias Hermes.Bluesky.Realtime.WebsocketProducer
  require Logger

  @default_hosts ["jetstream1.us-east.bsky.network", "jetstream2.us-east.bsky.network"]

  defmodule Event do
    @moduledoc """
    Normalized Jetstream event shape.
    """

    defstruct [
      :kind,
      :time_us,
      :did,
      :collection,
      :operation,
      :uri,
      :cid,
      :record,
      :commit,
      :payload
    ]
  end

  def child_spec(opts) do
    wanted_collections = Keyword.get(opts, :wanted_collections, [])
    user_mapper = Keyword.get(opts, :flat_mapper)

    internal_mapper = %{
      acc: if(user_mapper, do: user_mapper.acc, else: nil),
      fun: fn frame, acc ->
        events = decode_frame(frame) |> filter_collections(wanted_collections)

        case user_mapper do
          nil -> {events, acc}
          mapper -> Enum.flat_map_reduce(events, acc, mapper.fun)
        end
      end
    }

    WebsocketProducer.child_spec(
      uri: fn -> build_uri(opts) end,
      headers: Keyword.get(opts, :headers, []),
      event_cb: Keyword.get(opts, :event_cb, &telemetry/1),
      flat_mapper: internal_mapper,
      name: Keyword.get(opts, :name)
    )
  end

  def build_uri(opts \\ []) do
    host =
      Keyword.get(opts, :host) ||
        opts
        |> Keyword.get(:hosts, @default_hosts)
        |> Enum.random()

    query =
      []
      |> maybe_add_query(:cursor, Keyword.get(opts, :cursor))
      |> maybe_add_repeated_query("wantedCollections", Keyword.get(opts, :wanted_collections, []))
      |> URI.encode_query()

    %URI{
      scheme: "wss",
      host: host,
      port: 443,
      path: "/subscribe",
      query: if(query == "", do: nil, else: query)
    }
  end

  def decode_frame({:text, payload}), do: decode_frame(payload)
  def decode_frame({:binary, _payload}), do: []

  def decode_frame(payload) when is_binary(payload) do
    case Jason.decode(payload) do
      {:ok, event} ->
        normalize_event(event)

      {:error, reason} ->
        Logger.warning("Unable to decode Jetstream event: #{inspect(reason)}")
        []
    end
  end

  def normalize_event(
        %{"kind" => "commit", "did" => did, "time_us" => time_us, "commit" => commit} = payload
      ) do
    uri =
      case {commit["collection"], commit["rkey"]} do
        {collection, rkey} when is_binary(collection) and is_binary(rkey) ->
          "at://#{did}/#{collection}/#{rkey}"

        _ ->
          nil
      end

    [
      %Event{
        kind: :commit,
        time_us: time_us,
        did: did,
        collection: commit["collection"],
        operation: commit["operation"],
        uri: uri,
        cid: commit["cid"],
        record: commit["record"],
        commit: commit,
        payload: payload
      }
    ]
  end

  def normalize_event(%{"kind" => "account", "did" => did, "time_us" => time_us} = payload) do
    [
      %Event{
        kind: :account,
        time_us: time_us,
        did: did,
        payload: payload
      }
    ]
  end

  def normalize_event(%{"kind" => "identity", "did" => did, "time_us" => time_us} = payload) do
    [
      %Event{
        kind: :identity,
        time_us: time_us,
        did: did,
        payload: payload
      }
    ]
  end

  def normalize_event(other) do
    Logger.warning("Unknown Jetstream event: #{inspect(other)}")
    []
  end

  def telemetry({:connecting, uri}), do: Logger.info("Jetstream connecting to #{uri}")
  def telemetry(:open), do: Logger.info("Jetstream websocket open")

  def telemetry({:connect_error, reason, reconnect_after}) do
    Logger.error(
      "Jetstream connect error: #{inspect(reason)}; reconnecting in #{reconnect_after}ms"
    )
  end

  def telemetry({:closing, reason}),
    do: Logger.info("Jetstream websocket closing: #{inspect(reason)}")

  def telemetry({:closed, reason, reconnect_after}) do
    :telemetry.execute([:hermes_bluesky, :realtime, :jetstream, :closed], %{}, %{reason: reason})

    Logger.warning(
      "Jetstream websocket closed: #{inspect(reason)}" <>
        if(reconnect_after, do: "; reconnecting in #{reconnect_after}ms", else: "")
    )
  end

  defp filter_collections(events, []), do: events

  defp filter_collections(events, wanted_collections) do
    Enum.filter(events, fn
      %Event{collection: nil} -> true
      %Event{collection: collection} -> collection in wanted_collections
      _ -> true
    end)
  end

  defp maybe_add_query(query, _key, nil), do: query
  defp maybe_add_query(query, key, value), do: [{key, value} | query]

  defp maybe_add_repeated_query(query, _key, []), do: query

  defp maybe_add_repeated_query(query, key, values) do
    Enum.reduce(values, query, fn value, acc -> [{key, value} | acc] end)
  end
end
