defmodule Hermes.Bluesky.StrongRef do
  @moduledoc """
  Shared ATProto strong reference shape.
  """

  defstruct [:uri, :cid]

  @type t :: %__MODULE__{
          uri: String.t(),
          cid: String.t()
        }

  @spec new(String.t(), String.t()) :: t()
  def new(uri, cid) when is_binary(uri) and is_binary(cid) do
    %__MODULE__{uri: uri, cid: cid}
  end

  @spec from_map(map()) :: {:ok, t()} | {:error, :invalid_strong_ref}
  def from_map(%{"uri" => uri, "cid" => cid}) when is_binary(uri) and is_binary(cid),
    do: {:ok, new(uri, cid)}

  def from_map(%{uri: uri, cid: cid}) when is_binary(uri) and is_binary(cid),
    do: {:ok, new(uri, cid)}

  def from_map(_), do: {:error, :invalid_strong_ref}

  @spec from_map!(map()) :: t()
  def from_map!(map) do
    case from_map(map) do
      {:ok, ref} -> ref
      {:error, :invalid_strong_ref} -> raise ArgumentError, "invalid strong ref map"
    end
  end

  @spec to_api_map(t()) :: map()
  def to_api_map(%__MODULE__{} = ref) do
    %{"uri" => ref.uri, "cid" => ref.cid}
  end
end
