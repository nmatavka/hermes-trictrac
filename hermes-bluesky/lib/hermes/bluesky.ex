# Provenance:
# - High-level ergonomics adapted from proto_rune-main/lib/proto_rune/bsky.ex (MIT)
defmodule Hermes.Bluesky do
  @moduledoc """
  High-level Bluesky client helpers.
  """

  alias Hermes.Bluesky.Actor
  alias Hermes.Bluesky.Feed
  alias Hermes.Bluesky.Graph
  alias Hermes.Bluesky.Identity
  alias Hermes.Bluesky.Media
  alias Hermes.Bluesky.Notification
  alias Hermes.Bluesky.Repo
  alias Hermes.Bluesky.RichText
  alias Hermes.Bluesky.Server
  alias Hermes.Bluesky.Session
  alias Hermes.Bluesky.StrongRef
  alias Hermes.Bluesky.Util

  defdelegate login(identifier, password, opts \\ []), to: Session
  defdelegate from_oauth_conn(conn), to: Session
  defdelegate refresh(session), to: Session
  defdelegate current_actor(session), to: Session
  defdelegate as_client(session), to: Session

  def post(%Session{} = session, content, opts \\ []) do
    with {:ok, record, updated_session} <- build_post_record(session, content, opts) do
      Repo.create_record(updated_session, %{
        repo: updated_session.did,
        collection: "app.bsky.feed.post",
        record: record
      })
    end
  end

  def like(%Session{} = session, uri, cid) when is_binary(uri) and is_binary(cid) do
    Repo.create_record(session, %{
      repo: session.did,
      collection: "app.bsky.feed.like",
      record: %{
        "$type" => "app.bsky.feed.like",
        subject: StrongRef.to_api_map(StrongRef.new(uri, cid)),
        created_at: Util.iso8601_now()
      }
    })
  end

  def unlike(%Session{} = session, like_uri), do: delete_by_uri(session, like_uri)

  def repost(%Session{} = session, uri, cid) when is_binary(uri) and is_binary(cid) do
    Repo.create_record(session, %{
      repo: session.did,
      collection: "app.bsky.feed.repost",
      record: %{
        "$type" => "app.bsky.feed.repost",
        subject: StrongRef.to_api_map(StrongRef.new(uri, cid)),
        created_at: Util.iso8601_now()
      }
    })
  end

  def unrepost(%Session{} = session, repost_uri), do: delete_by_uri(session, repost_uri)

  def follow(%Session{} = session, actor) when is_binary(actor) do
    with {:ok, did} <- resolve_actor(actor) do
      Repo.create_record(session, %{
        repo: session.did,
        collection: "app.bsky.graph.follow",
        record: %{
          "$type" => "app.bsky.graph.follow",
          subject: did,
          created_at: Util.iso8601_now()
        }
      })
    end
  end

  def unfollow(%Session{} = session, follow_uri), do: delete_by_uri(session, follow_uri)

  def block(%Session{} = session, actor) when is_binary(actor) do
    with {:ok, did} <- resolve_actor(actor) do
      Repo.create_record(session, %{
        repo: session.did,
        collection: "app.bsky.graph.block",
        record: %{
          "$type" => "app.bsky.graph.block",
          subject: did,
          created_at: Util.iso8601_now()
        }
      })
    end
  end

  def unblock(%Session{} = session, block_uri), do: delete_by_uri(session, block_uri)
  def mute(%Session{} = session, actor), do: Graph.mute_actor(session, actor)
  def unmute(%Session{} = session, actor), do: Graph.unmute_actor(session, actor)
  def delete_post(%Session{} = session, post_uri), do: delete_by_uri(session, post_uri)

  def get_profile(target, actor), do: Actor.get_profile(target, actor)
  def get_profiles(target, actors), do: Actor.get_profiles(target, actors)
  def get_timeline(target, opts \\ []), do: Feed.get_timeline(target, opts)
  def get_post_thread(target, uri, opts \\ []), do: Feed.get_post_thread(target, uri, opts)
  def get_posts(target, uris), do: Feed.get_posts(target, uris)
  def search_posts(target, query, opts \\ []), do: Feed.search_posts(target, query, opts)
  def search_actors(target, query, opts \\ []), do: Actor.search_actors(target, query, opts)
  def list_notifications(target, opts \\ []), do: Notification.list_notifications(target, opts)
  def get_unread_count(target, opts \\ []), do: Notification.get_unread_count(target, opts)

  def update_seen(%Session{} = session, %DateTime{} = seen_at) do
    Notification.update_seen(session, DateTime.to_iso8601(seen_at))
  end

  def update_seen(%Session{} = session, seen_at) when is_binary(seen_at) do
    Notification.update_seen(session, seen_at)
  end

  def get_session(target), do: Server.get_session(target)

  defp build_post_record(%Session{} = session, %RichText{} = rich_text, opts) do
    build_post_record(session, RichText.to_post_data(rich_text), opts)
  end

  defp build_post_record(%Session{} = session, text, opts) when is_binary(text) do
    build_post_record(session, RichText.from_text(text) |> RichText.to_post_data(), opts)
  end

  defp build_post_record(%Session{} = session, %{text: text} = content, opts)
       when is_binary(text) do
    %{
      "$type" => "app.bsky.feed.post",
      text: text,
      facets: Map.get(content, :facets) || Map.get(content, "facets") || [],
      langs: Keyword.get(opts, :langs, ["en"]),
      created_at: Keyword.get(opts, :created_at, Util.iso8601_now())
    }
    |> maybe_add_reply(session, Keyword.get(opts, :reply_to))
    |> maybe_add_images(session, Keyword.get(opts, :images) || Keyword.get(opts, :media_paths))
  end

  defp maybe_add_reply(record, session, nil), do: {:ok, record, session}

  defp maybe_add_reply(record, session, reply_to) do
    with {:ok, reply, updated_session} <- build_reply(session, reply_to) do
      {:ok, Map.put(record, :reply, reply), updated_session}
    end
  end

  defp maybe_add_images({:ok, record, session}, _original_session, nil),
    do: {:ok, record, session}

  defp maybe_add_images({:ok, record, session}, _original_session, []), do: {:ok, record, session}

  defp maybe_add_images({:ok, record, session}, _original_session, images) do
    images = Enum.map(images, fn image -> image end)

    case Media.upload_images(session, images) do
      {:ok, uploaded_images, updated_session} ->
        {:ok, Map.put(record, :embed, Media.build_images_embed(uploaded_images)), updated_session}

      {:error, error, updated_session} ->
        {:error, error, updated_session}
    end
  end

  defp build_reply(%Session{} = session, reply_to) do
    with {:ok, response, updated_session} <- Repo.get_record_by_uri(session, reply_to),
         {:ok, parent_ref} <- StrongRef.from_map(response) do
      root_ref =
        response
        |> get_in(["value", "reply", "root"])
        |> case do
          nil -> parent_ref
          root -> StrongRef.from_map!(root)
        end

      {:ok,
       %{
         root: StrongRef.to_api_map(root_ref),
         parent: StrongRef.to_api_map(parent_ref)
       }, updated_session}
    else
      {:error, error, updated_session} -> {:error, error, updated_session}
      {:error, error} -> {:error, error, session}
    end
  end

  defp delete_by_uri(%Session{} = session, at_uri) do
    with {:ok, parsed} <- Identity.parse_at_uri(at_uri),
         {:ok, response, updated_session} <-
           Repo.delete_record(session, %{
             repo: parsed.authority,
             collection: parsed.collection,
             rkey: parsed.rkey
           }) do
      {:ok, response, updated_session}
    else
      :error -> {:error, :invalid_at_uri, session}
      {:error, error, updated_session} -> {:error, error, updated_session}
    end
  end

  defp resolve_actor("did:" <> _ = did), do: {:ok, did}
  defp resolve_actor(handle), do: Identity.resolve_handle(handle)
end
