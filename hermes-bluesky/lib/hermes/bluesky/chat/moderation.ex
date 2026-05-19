# Provenance:
# - API surface adapted from proto_rune-main/lib/bluesky/chat/moderation.ex (MIT)
defmodule Hermes.Bluesky.Chat.Moderation do
  @moduledoc """
  Bluesky chat moderation helpers.
  """

  alias Hermes.Bluesky.XRPC

  def get_actor_metadata(target, actor) do
    get_request(target, "chat.bsky.moderation.getActorMetadata", params: %{actor: actor})
  end

  def get_message_context(target, convo_id, message_id, opts \\ []) do
    get_request(target, "chat.bsky.moderation.getMessageContext",
      params: %{
        convo_id: convo_id,
        message_id: message_id,
        before: Keyword.get(opts, :before),
        after: Keyword.get(opts, :after)
      }
    )
  end

  def update_actor_access(target, attrs) do
    XRPC.post(target, "chat.bsky.moderation.updateActorAccess", json: attrs)
  end

  defp get_request(target, nsid, opts) when is_binary(target),
    do: XRPC.public_get(target, nsid, opts)

  defp get_request(target, nsid, opts), do: XRPC.get(target, nsid, opts)
end
