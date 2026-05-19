# Provenance:
# - Adapted from bsky-keyword-labeler-main/apps/bsky_labeler/lib/bsky_labeler/label.ex (GPL-3.0-or-later)
defmodule Hermes.Bluesky.Ozone do
  @moduledoc """
  Ozone moderation helpers.
  """

  alias Hermes.Bluesky.Session
  alias Hermes.Bluesky.StrongRef
  alias Hermes.Bluesky.XRPC

  @spec emit_label(Session.t(), StrongRef.t() | map(), String.t(), keyword()) ::
          {:ok, any(), Session.t()} | {:error, any(), Session.t()}
  def emit_label(%Session{} = session, subject, label, opts \\ []) do
    subject_ref =
      case subject do
        %StrongRef{} = ref -> ref
        map when is_map(map) -> StrongRef.from_map!(map)
      end

    labeler_did = Keyword.get(opts, :labeler_did, session.did)

    body = %{
      event: %{
        "$type" => "tools.ozone.moderation.defs#modEventLabel",
        comment: Keyword.get(opts, :comment),
        create_label_vals: [label],
        negate_label_vals: Keyword.get(opts, :negate_label_vals, [])
      },
      subject: Map.put(StrongRef.to_api_map(subject_ref), "$type", "com.atproto.repo.strongRef"),
      created_by: labeler_did
    }

    XRPC.post(session, "tools.ozone.moderation.emitEvent",
      json: body,
      headers: [
        {"atproto-proxy", "#{labeler_did}#atproto_labeler"},
        {"accept-language", Keyword.get(opts, :accept_language, "en-US")}
      ]
    )
  end
end
