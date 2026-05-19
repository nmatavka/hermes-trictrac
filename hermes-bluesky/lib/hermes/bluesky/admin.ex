# Provenance:
# - API surface adapted from proto_rune-main/lib/atproto/admin.ex (MIT)
defmodule Hermes.Bluesky.Admin do
  @moduledoc """
  Administrative ATProto helpers.
  """

  alias Hermes.Bluesky.XRPC

  def delete_account(target, did),
    do: XRPC.post(target, "com.atproto.admin.deleteAccount", json: %{did: did})

  def disable_account_invites(target, attrs),
    do: XRPC.post(target, "com.atproto.admin.disableAccountInvites", json: attrs)

  def disable_invite_codes(target, attrs),
    do: XRPC.post(target, "com.atproto.admin.disableInviteCodes", json: attrs)

  def enable_account_invites(target, attrs),
    do: XRPC.post(target, "com.atproto.admin.enableAccountInvites", json: attrs)

  def get_account_info(target, did),
    do: XRPC.get(target, "com.atproto.admin.getAccountInfo", params: %{did: did})

  def get_account_infos(target, dids),
    do: XRPC.get(target, "com.atproto.admin.getAccountInfos", params: %{dids: dids})

  def get_invite_codes(target, opts \\ []) do
    XRPC.get(target, "com.atproto.admin.getInviteCodes",
      params: %{
        sort: Keyword.get(opts, :sort),
        limit: Keyword.get(opts, :limit),
        cursor: Keyword.get(opts, :cursor)
      }
    )
  end

  def get_subject_status(target, attrs \\ %{}),
    do: XRPC.get(target, "com.atproto.admin.getSubjectStatus", params: attrs)

  def search_accounts(target, attrs \\ %{}),
    do: XRPC.get(target, "com.atproto.admin.searchAccounts", params: attrs)

  def send_email(target, attrs),
    do: XRPC.post(target, "com.atproto.admin.sendEmail", json: attrs)

  def update_account_email(target, attrs),
    do: XRPC.post(target, "com.atproto.admin.updateAccountEmail", json: attrs)

  def update_account_handle(target, attrs),
    do: XRPC.post(target, "com.atproto.admin.updateAccountHandle", json: attrs)

  def update_account_password(target, attrs),
    do: XRPC.post(target, "com.atproto.admin.updateAccountPassword", json: attrs)

  def update_subject_status(target, attrs),
    do: XRPC.post(target, "com.atproto.admin.updateSubjectStatus", json: attrs)
end
