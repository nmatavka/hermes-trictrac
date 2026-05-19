# Provenance:
# - API surface adapted from proto_rune-main/lib/bluesky/chat/actor.ex (MIT)
defmodule Hermes.Bluesky.Chat.Actor do
  @moduledoc """
  Bluesky chat actor and conversation helpers.
  """

  alias Hermes.Bluesky.XRPC

  def delete_account(target), do: XRPC.post(target, "chat.bsky.actor.deleteAccount", json: %{})
  def export_account_data(target), do: XRPC.get(target, "chat.bsky.actor.exportAccountData")

  def delete_message_for_self(target, convo_id, message_id) do
    XRPC.post(target, "chat.bsky.convo.deleteMessageForSelf",
      json: %{convo_id: convo_id, message_id: message_id}
    )
  end

  def get_convo_for_members(target, members),
    do: XRPC.get(target, "chat.bsky.convo.getConvoForMembers", params: %{members: members})

  def get_convo(target, convo_id),
    do: XRPC.get(target, "chat.bsky.convo.getConvo", params: %{convo_id: convo_id})

  def get_log(target, opts \\ []) do
    XRPC.get(target, "chat.bsky.convo.getLog", params: %{cursor: Keyword.get(opts, :cursor)})
  end

  def get_messages(target, convo_id, opts \\ []) do
    XRPC.get(target, "chat.bsky.convo.getMessages",
      params: %{
        convo_id: convo_id,
        limit: Keyword.get(opts, :limit),
        cursor: Keyword.get(opts, :cursor)
      }
    )
  end

  def leave_convo(target, convo_id),
    do: XRPC.post(target, "chat.bsky.convo.leaveConvo", json: %{convo_id: convo_id})

  def list_convos(target, opts \\ []) do
    XRPC.get(target, "chat.bsky.convo.listConvos",
      params: %{limit: Keyword.get(opts, :limit), cursor: Keyword.get(opts, :cursor)}
    )
  end

  def mute_convo(target, convo_id),
    do: XRPC.post(target, "chat.bsky.convo.muteConvo", json: %{convo_id: convo_id})

  def send_message_batch(target, items),
    do: XRPC.post(target, "chat.bsky.convo.sendMessageBatch", json: %{items: items})

  def send_message(target, convo_id, message),
    do:
      XRPC.post(target, "chat.bsky.convo.sendMessage",
        json: %{convo_id: convo_id, message: message}
      )

  def unmute_convo(target, convo_id),
    do: XRPC.post(target, "chat.bsky.convo.unmuteConvo", json: %{convo_id: convo_id})

  def update_read(target, convo_id, message_id) do
    XRPC.post(target, "chat.bsky.convo.updateRead",
      json: %{convo_id: convo_id, message_id: message_id}
    )
  end
end
