defmodule Hermes.Bluesky.Identity do
  @moduledoc """
  Identity and `at://` helpers for Bluesky and ATProto identifiers.
  """

  alias Atex.AtURI
  alias Atex.DID
  alias Atex.Handle
  alias Atex.IdentityResolver

  @spec resolve(String.t(), keyword()) ::
          {:ok, Atex.IdentityResolver.Identity.t()} | {:error, any()}
  def resolve(identifier, opts \\ []) do
    IdentityResolver.resolve(identifier, opts)
  end

  @spec resolve_handle(String.t(), keyword()) :: {:ok, String.t()} | {:error, any()}
  def resolve_handle(handle, _opts \\ []) do
    with {:ok, identity} <- IdentityResolver.resolve(handle) do
      {:ok, identity.did}
    end
  end

  @spec resolve_did(String.t(), keyword()) :: {:ok, map()} | {:error, any()}
  def resolve_did(did, _opts \\ []) do
    with {:ok, identity} <- IdentityResolver.resolve(did) do
      {:ok, identity.document}
    end
  end

  @spec validate(String.t(), keyword()) ::
          {:ok, Atex.IdentityResolver.Identity.t()} | {:error, any()}
  def validate(identifier, opts \\ []) do
    resolve(identifier, opts)
  end

  @spec parse_at_uri(String.t()) :: {:ok, AtURI.t()} | :error
  def parse_at_uri(uri), do: AtURI.new(uri)

  @spec parse_at_uri!(String.t()) :: AtURI.t()
  def parse_at_uri!(uri), do: AtURI.new!(uri)

  @spec valid_handle?(String.t()) :: boolean()
  def valid_handle?(value), do: Handle.match?(value)

  @spec valid_did?(String.t()) :: boolean()
  def valid_did?(value), do: DID.match?(value)
end
