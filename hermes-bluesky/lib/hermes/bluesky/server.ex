# Provenance:
# - API surface adapted from proto_rune-main/lib/atproto/server.ex (MIT)
defmodule Hermes.Bluesky.Server do
  @moduledoc """
  ATProto server/account XRPC helpers.
  """

  alias Hermes.Bluesky.XRPC

  def activate_account(target),
    do: XRPC.post(target, "com.atproto.server.activateAccount", json: %{})

  def check_account_status(target), do: XRPC.get(target, "com.atproto.server.checkAccountStatus")

  def confirm_email(target, email, token) do
    XRPC.post(target, "com.atproto.server.confirmEmail", json: %{email: email, token: token})
  end

  def create_account(endpoint, attrs) when is_binary(endpoint) do
    XRPC.public_post(endpoint, "com.atproto.server.createAccount", json: attrs)
  end

  def create_app_password(target, attrs) when is_map(attrs) do
    XRPC.post(target, "com.atproto.server.createAppPassword", json: attrs)
  end

  def create_invite_code(target, attrs) when is_map(attrs) do
    XRPC.post(target, "com.atproto.server.createInviteCode", json: attrs)
  end

  def create_invite_codes(target, attrs) when is_map(attrs) do
    XRPC.post(target, "com.atproto.server.createInviteCodes", json: attrs)
  end

  def create_session(endpoint, identifier, password) when is_binary(endpoint) do
    XRPC.public_post(endpoint, "com.atproto.server.createSession",
      json: %{identifier: identifier, password: password}
    )
  end

  def deactivate_account(target, delete_after) do
    XRPC.post(target, "com.atproto.server.deactivateAccount", json: %{delete_after: delete_after})
  end

  def delete_account(target, attrs) when is_map(attrs) do
    XRPC.post(target, "com.atproto.server.deleteAccount", json: attrs)
  end

  def delete_session(target), do: XRPC.post(target, "com.atproto.server.deleteSession", json: %{})

  def describe_server(endpoint) when is_binary(endpoint),
    do: XRPC.public_get(endpoint, "com.atproto.server.describeServer")

  def get_account_invite_codes(target, opts \\ []) do
    XRPC.get(target, "com.atproto.server.getAccountInviteCodes",
      params: %{
        include_used: Keyword.get(opts, :include_used),
        create_available: Keyword.get(opts, :create_available)
      }
    )
  end

  def get_service_auth(target, attrs) when is_map(attrs) do
    XRPC.get(target, "com.atproto.server.getServiceAuth", params: attrs)
  end

  def get_session(target), do: XRPC.get(target, "com.atproto.server.getSession")
  def list_app_passwords(target), do: XRPC.get(target, "com.atproto.server.listAppPasswords")

  def refresh_session(target),
    do: XRPC.post(target, "com.atproto.server.refreshSession", json: %{})

  def request_account_delete(target),
    do: XRPC.post(target, "com.atproto.server.requestAccountDelete", json: %{})

  def request_email_confirmation(target),
    do: XRPC.post(target, "com.atproto.server.requestEmailConfirmation", json: %{})

  def request_email_update(target),
    do: XRPC.post(target, "com.atproto.server.requestEmailUpdate", json: %{})

  def request_password_reset(endpoint, email) when is_binary(endpoint) do
    XRPC.public_post(endpoint, "com.atproto.server.requestPasswordReset", json: %{email: email})
  end

  def reserve_signing_key(endpoint, did) when is_binary(endpoint) do
    XRPC.public_post(endpoint, "com.atproto.server.reserveSigningKey", json: %{did: did})
  end

  def reset_password(endpoint, attrs) when is_binary(endpoint) do
    XRPC.public_post(endpoint, "com.atproto.server.resetPassword", json: attrs)
  end

  def revoke_app_password(target, name) do
    XRPC.post(target, "com.atproto.server.revokeAppPassword", json: %{name: name})
  end

  def update_email(target, attrs) when is_map(attrs) do
    XRPC.post(target, "com.atproto.server.updateEmail", json: attrs)
  end
end
