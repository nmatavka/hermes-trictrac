# Provenance:
# - API surface adapted from proto_rune-main/lib/atproto/repo.ex (MIT)
defmodule Hermes.Bluesky.Repo do
  @moduledoc """
  Repository XRPC helpers.
  """

  alias Hermes.Bluesky.Identity
  alias Hermes.Bluesky.Session
  alias Hermes.Bluesky.Util
  alias Hermes.Bluesky.XRPC

  @spec create_record(Session.t(), map()) ::
          {:ok, any(), Session.t()} | {:error, any(), Session.t()}
  def create_record(%Session{} = session, attrs) when is_map(attrs) do
    payload =
      %{
        repo: Util.map_value(attrs, :repo, "repo", session.did),
        collection: Util.map_value(attrs, :collection),
        record: Util.map_value(attrs, :record)
      }
      |> Util.maybe_put(:rkey, Util.map_value(attrs, :rkey))
      |> Util.maybe_put(:validate, Util.map_value(attrs, :validate))
      |> Util.maybe_put(:swap_commit, Util.map_value(attrs, :swap_commit))

    XRPC.post(session, "com.atproto.repo.createRecord", json: payload)
  end

  @spec get_record(Session.t() | String.t(), String.t(), String.t(), String.t(), keyword()) ::
          {:ok, any(), Session.t()}
          | {:error, any(), Session.t()}
          | {:ok, any()}
          | {:error, any()}
  def get_record(target, repo, collection, rkey, opts \\ []) do
    params =
      %{
        repo: repo,
        collection: collection,
        rkey: rkey
      }
      |> Util.maybe_put(:cid, Keyword.get(opts, :cid))

    do_get(target, "com.atproto.repo.getRecord", params: params)
  end

  @spec get_record_by_uri(Session.t() | String.t(), String.t(), keyword()) ::
          {:ok, any(), Session.t()}
          | {:error, any(), Session.t()}
          | {:ok, any()}
          | {:error, any()}
  def get_record_by_uri(target, uri, opts \\ []) do
    with {:ok, at_uri} <- Identity.parse_at_uri(uri) do
      get_record(target, at_uri.authority, at_uri.collection, at_uri.rkey, opts)
    else
      :error ->
        if match?(%Session{}, target) do
          {:error, :invalid_at_uri, target}
        else
          {:error, :invalid_at_uri}
        end
    end
  end

  @spec put_record(Session.t(), map()) :: {:ok, any(), Session.t()} | {:error, any(), Session.t()}
  def put_record(%Session{} = session, attrs) when is_map(attrs) do
    payload =
      %{
        repo: Util.map_value(attrs, :repo, "repo", session.did),
        collection: Util.map_value(attrs, :collection),
        rkey: Util.map_value(attrs, :rkey),
        record: Util.map_value(attrs, :record)
      }
      |> Util.maybe_put(:validate, Util.map_value(attrs, :validate))
      |> Util.maybe_put(:swap_record, Util.map_value(attrs, :swap_record))
      |> Util.maybe_put(:swap_commit, Util.map_value(attrs, :swap_commit))

    XRPC.post(session, "com.atproto.repo.putRecord", json: payload)
  end

  @spec delete_record(Session.t(), map()) ::
          {:ok, any(), Session.t()} | {:error, any(), Session.t()}
  def delete_record(%Session{} = session, attrs) when is_map(attrs) do
    payload =
      %{
        repo: Util.map_value(attrs, :repo, "repo", session.did),
        collection: Util.map_value(attrs, :collection),
        rkey: Util.map_value(attrs, :rkey)
      }
      |> Util.maybe_put(:swap_record, Util.map_value(attrs, :swap_record))
      |> Util.maybe_put(:swap_commit, Util.map_value(attrs, :swap_commit))

    XRPC.post(session, "com.atproto.repo.deleteRecord", json: payload)
  end

  @spec list_records(Session.t() | String.t(), String.t(), String.t(), keyword()) ::
          {:ok, any(), Session.t()}
          | {:error, any(), Session.t()}
          | {:ok, any()}
          | {:error, any()}
  def list_records(target, repo, collection, opts \\ []) do
    params =
      %{
        repo: repo,
        collection: collection
      }
      |> Util.maybe_put(:limit, Keyword.get(opts, :limit))
      |> Util.maybe_put(:cursor, Keyword.get(opts, :cursor))
      |> Util.maybe_put(:reverse, Keyword.get(opts, :reverse))

    do_get(target, "com.atproto.repo.listRecords", params: params)
  end

  defp do_get(target, nsid, opts) when is_binary(target), do: XRPC.public_get(target, nsid, opts)
  defp do_get(target, nsid, opts), do: XRPC.get(target, nsid, opts)
end
