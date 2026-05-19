# Provenance:
# - API surface adapted from proto_rune-main/lib/bluesky/feed.ex (MIT)
defmodule Hermes.Bluesky.Feed do
  @moduledoc """
  Feed and post read/query helpers.
  """

  alias Hermes.Bluesky.XRPC

  def describe_feed_generator(target) do
    get_request(target, "app.bsky.feed.describeFeedGenerator", [])
  end

  def get_actor_feeds(target, actor, opts \\ []) do
    get_request(target, "app.bsky.feed.getActorFeeds",
      params: %{
        actor: actor,
        limit: Keyword.get(opts, :limit),
        cursor: Keyword.get(opts, :cursor)
      }
    )
  end

  def get_actor_likes(target, actor, opts \\ []) do
    XRPC.get(target, "app.bsky.feed.getActorLikes",
      params: %{
        actor: actor,
        limit: Keyword.get(opts, :limit),
        cursor: Keyword.get(opts, :cursor)
      }
    )
  end

  def get_author_feed(target, actor, opts \\ []) do
    get_request(target, "app.bsky.feed.getAuthorFeed",
      params: %{
        actor: actor,
        limit: Keyword.get(opts, :limit),
        cursor: Keyword.get(opts, :cursor),
        filter: Keyword.get(opts, :filter)
      }
    )
  end

  def get_feed_generator(target, feed_uri) do
    get_request(target, "app.bsky.feed.getFeedGenerator", params: %{feed: feed_uri})
  end

  def get_feed_generators(target, feed_uris) when is_list(feed_uris) do
    get_request(target, "app.bsky.feed.getFeedGenerators", params: %{feeds: feed_uris})
  end

  def get_feed_skeleton(target, feed_uri, opts \\ []) do
    get_request(target, "app.bsky.feed.getFeedSkeleton",
      params: %{
        feed: feed_uri,
        limit: Keyword.get(opts, :limit),
        cursor: Keyword.get(opts, :cursor)
      }
    )
  end

  def get_feed(target, feed_uri, opts \\ []) do
    get_request(target, "app.bsky.feed.getFeed",
      params: %{
        feed: feed_uri,
        limit: Keyword.get(opts, :limit),
        cursor: Keyword.get(opts, :cursor)
      }
    )
  end

  def get_likes(target, uri, opts \\ []) do
    get_request(target, "app.bsky.feed.getLikes",
      params: %{
        uri: uri,
        cid: Keyword.get(opts, :cid),
        limit: Keyword.get(opts, :limit),
        cursor: Keyword.get(opts, :cursor)
      }
    )
  end

  def get_list_feed(target, list_uri, opts \\ []) do
    get_request(target, "app.bsky.feed.getListFeed",
      params: %{
        list: list_uri,
        limit: Keyword.get(opts, :limit),
        cursor: Keyword.get(opts, :cursor)
      }
    )
  end

  def get_post_thread(target, uri, opts \\ []) do
    get_request(target, "app.bsky.feed.getPostThread",
      params: %{
        uri: uri,
        depth: Keyword.get(opts, :depth),
        parent_height: Keyword.get(opts, :parent_height)
      }
    )
  end

  def get_posts(target, uris) when is_list(uris) do
    get_request(target, "app.bsky.feed.getPosts", params: %{uris: uris})
  end

  def get_quotes(target, uri, opts \\ []) do
    get_request(target, "app.bsky.feed.getQuotes",
      params: %{
        uri: uri,
        cid: Keyword.get(opts, :cid),
        limit: Keyword.get(opts, :limit),
        cursor: Keyword.get(opts, :cursor)
      }
    )
  end

  def get_reposted_by(target, uri, opts \\ []) do
    get_request(target, "app.bsky.feed.getRepostedBy",
      params: %{
        uri: uri,
        cid: Keyword.get(opts, :cid),
        limit: Keyword.get(opts, :limit),
        cursor: Keyword.get(opts, :cursor)
      }
    )
  end

  def get_suggested_feeds(target, opts \\ []) do
    XRPC.get(target, "app.bsky.feed.getSuggestedFeeds",
      params: %{limit: Keyword.get(opts, :limit), cursor: Keyword.get(opts, :cursor)}
    )
  end

  def get_timeline(target, opts \\ []) do
    XRPC.get(target, "app.bsky.feed.getTimeline",
      params: %{
        algorithm: Keyword.get(opts, :algorithm),
        limit: Keyword.get(opts, :limit),
        cursor: Keyword.get(opts, :cursor)
      }
    )
  end

  def search_posts(target, query, opts \\ []) do
    get_request(target, "app.bsky.feed.searchPosts",
      params: %{
        q: query,
        sort: Keyword.get(opts, :sort),
        since: Keyword.get(opts, :since),
        until: Keyword.get(opts, :until),
        mentions: Keyword.get(opts, :mentions),
        author: Keyword.get(opts, :author),
        lang: Keyword.get(opts, :lang),
        domain: Keyword.get(opts, :domain),
        url: Keyword.get(opts, :url),
        tag: Keyword.get(opts, :tag),
        limit: Keyword.get(opts, :limit),
        cursor: Keyword.get(opts, :cursor)
      }
    )
  end

  defp get_request(target, nsid, opts) when is_binary(target),
    do: XRPC.public_get(target, nsid, opts)

  defp get_request(target, nsid, opts), do: XRPC.get(target, nsid, opts)
end
