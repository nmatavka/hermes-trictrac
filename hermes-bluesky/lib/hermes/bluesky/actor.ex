# Provenance:
# - API surface adapted from proto_rune-main/lib/bluesky/actor.ex (MIT)
defmodule Hermes.Bluesky.Actor do
  @moduledoc """
  Actor and profile queries.
  """

  alias Hermes.Bluesky.XRPC

  def get_preferences(target), do: XRPC.get(target, "app.bsky.actor.getPreferences")

  def get_profile(target, actor) do
    get_request(target, "app.bsky.actor.getProfile", params: %{actor: actor})
  end

  def get_profiles(target, actors) when is_list(actors) do
    get_request(target, "app.bsky.actor.getProfiles", params: %{actors: actors})
  end

  def get_suggestions(target, opts \\ []) do
    XRPC.get(target, "app.bsky.actor.getSuggestions",
      params: %{limit: Keyword.get(opts, :limit), cursor: Keyword.get(opts, :cursor)}
    )
  end

  def put_preferences(target, preferences) do
    XRPC.post(target, "app.bsky.actor.putPreferences", json: %{preferences: preferences})
  end

  def search_actors_typeahead(target, query, opts \\ []) do
    get_request(target, "app.bsky.actor.searchActorsTypeahead",
      params: %{q: query, limit: Keyword.get(opts, :limit)}
    )
  end

  def search_actors(target, query, opts \\ []) do
    get_request(target, "app.bsky.actor.searchActors",
      params: %{q: query, limit: Keyword.get(opts, :limit), cursor: Keyword.get(opts, :cursor)}
    )
  end

  defp get_request(target, nsid, opts) when is_binary(target),
    do: XRPC.public_get(target, nsid, opts)

  defp get_request(target, nsid, opts), do: XRPC.get(target, nsid, opts)
end
