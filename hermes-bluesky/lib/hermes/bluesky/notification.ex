# Provenance:
# - API surface adapted from proto_rune-main/lib/bluesky/notification.ex (MIT)
defmodule Hermes.Bluesky.Notification do
  @moduledoc """
  Notification queries and procedures.
  """

  alias Hermes.Bluesky.XRPC

  def get_unread_count(target, opts \\ []) do
    XRPC.get(target, "app.bsky.notification.getUnreadCount",
      params: %{priority: Keyword.get(opts, :priority), seen_at: Keyword.get(opts, :seen_at)}
    )
  end

  def list_notifications(target, opts \\ []) do
    XRPC.get(target, "app.bsky.notification.listNotifications",
      params: %{
        limit: Keyword.get(opts, :limit),
        priority: Keyword.get(opts, :priority),
        cursor: Keyword.get(opts, :cursor),
        seen_at: Keyword.get(opts, :seen_at)
      }
    )
  end

  def put_preferences(target, priority) do
    XRPC.post(target, "app.bsky.notification.putPreferences", json: %{priority: priority})
  end

  def register_push(target, attrs) when is_map(attrs) do
    XRPC.post(target, "app.bsky.notification.registerPush", json: attrs)
  end

  def update_seen(target, seen_at) do
    XRPC.post(target, "app.bsky.notification.updateSeen", json: %{seen_at: seen_at})
  end
end
