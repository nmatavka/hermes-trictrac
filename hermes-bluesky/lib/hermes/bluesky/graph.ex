# Provenance:
# - API surface adapted from proto_rune-main/lib/bluesky/graph.ex (MIT)
defmodule Hermes.Bluesky.Graph do
  @moduledoc """
  Graph and moderation-related account queries.
  """

  alias Hermes.Bluesky.XRPC

  def get_actor_starter_packs(target, actor, opts \\ []) do
    XRPC.get(target, "app.bsky.graph.getActorStarterPacks",
      params: %{
        actor: actor,
        limit: Keyword.get(opts, :limit),
        cursor: Keyword.get(opts, :cursor)
      }
    )
  end

  def get_blocks(target, opts \\ []) do
    XRPC.get(target, "app.bsky.graph.getBlocks",
      params: %{limit: Keyword.get(opts, :limit), cursor: Keyword.get(opts, :cursor)}
    )
  end

  def get_followers(target, actor, opts \\ []) do
    XRPC.get(target, "app.bsky.graph.getFollowers",
      params: %{
        actor: actor,
        limit: Keyword.get(opts, :limit),
        cursor: Keyword.get(opts, :cursor)
      }
    )
  end

  def get_follows(target, actor, opts \\ []) do
    XRPC.get(target, "app.bsky.graph.getFollows",
      params: %{
        actor: actor,
        limit: Keyword.get(opts, :limit),
        cursor: Keyword.get(opts, :cursor)
      }
    )
  end

  def get_known_followers(target, actor, opts \\ []) do
    XRPC.get(target, "app.bsky.graph.getKnownFollowers",
      params: %{
        actor: actor,
        limit: Keyword.get(opts, :limit),
        cursor: Keyword.get(opts, :cursor)
      }
    )
  end

  def get_list_blocks(target, opts \\ []) do
    XRPC.get(target, "app.bsky.graph.getListBlocks",
      params: %{limit: Keyword.get(opts, :limit), cursor: Keyword.get(opts, :cursor)}
    )
  end

  def get_list_mutes(target, opts \\ []) do
    XRPC.get(target, "app.bsky.graph.getListMutes",
      params: %{limit: Keyword.get(opts, :limit), cursor: Keyword.get(opts, :cursor)}
    )
  end

  def get_list(target, list_uri, opts \\ []) do
    XRPC.get(target, "app.bsky.graph.getList",
      params: %{
        list: list_uri,
        limit: Keyword.get(opts, :limit),
        cursor: Keyword.get(opts, :cursor)
      }
    )
  end

  def get_lists(target, actor, opts \\ []) do
    XRPC.get(target, "app.bsky.graph.getLists",
      params: %{
        actor: actor,
        limit: Keyword.get(opts, :limit),
        cursor: Keyword.get(opts, :cursor)
      }
    )
  end

  def get_mutes(target, opts \\ []) do
    XRPC.get(target, "app.bsky.graph.getMutes",
      params: %{limit: Keyword.get(opts, :limit), cursor: Keyword.get(opts, :cursor)}
    )
  end

  def get_relationships(target, actor, others \\ []) do
    get_request(target, "app.bsky.graph.getRelationships",
      params: %{actor: actor, others: others}
    )
  end

  def get_starter_pack(target, starter_pack_uri) do
    get_request(target, "app.bsky.graph.getStarterPack",
      params: %{starter_pack: starter_pack_uri}
    )
  end

  def get_starter_packs(target, uris) when is_list(uris) do
    get_request(target, "app.bsky.graph.getStarterPacks", params: %{uris: uris})
  end

  def get_suggested_follows_by_actor(target, actor) do
    XRPC.get(target, "app.bsky.graph.getSuggestedFollowsByActor", params: %{actor: actor})
  end

  def mute_actor_list(target, list_uri) do
    XRPC.post(target, "app.bsky.graph.muteActorList", json: %{list: list_uri})
  end

  def mute_actor(target, actor) do
    XRPC.post(target, "app.bsky.graph.muteActor", json: %{actor: actor})
  end

  def mute_thread(target, root_uri) do
    XRPC.post(target, "app.bsky.graph.muteThread", json: %{root: root_uri})
  end

  def unmute_actor_list(target, list_uri) do
    XRPC.post(target, "app.bsky.graph.unmuteActorList", json: %{list: list_uri})
  end

  def unmute_actor(target, actor) do
    XRPC.post(target, "app.bsky.graph.unmuteActor", json: %{actor: actor})
  end

  def unmute_thread(target, root_uri) do
    XRPC.post(target, "app.bsky.graph.unmuteThread", json: %{root: root_uri})
  end

  defp get_request(target, nsid, opts) when is_binary(target),
    do: XRPC.public_get(target, nsid, opts)

  defp get_request(target, nsid, opts), do: XRPC.get(target, nsid, opts)
end
