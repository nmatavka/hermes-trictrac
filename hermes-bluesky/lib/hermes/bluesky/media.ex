# Provenance:
# - Adapted from broadcast.ex-main/lib/broadcast.ex (MIT)
defmodule Hermes.Bluesky.Media do
  @moduledoc """
  Blob upload helpers for Bluesky media embeds.
  """

  alias Hermes.Bluesky.Session
  alias Hermes.Bluesky.XRPC

  defmodule Image do
    @moduledoc """
    Cross-cutting image input shape for media uploads.
    """

    defstruct [:path, :blob, :alt, :mime_type]

    @type t :: %__MODULE__{
            path: String.t() | nil,
            blob: binary() | nil,
            alt: String.t() | nil,
            mime_type: String.t() | nil
          }
  end

  @spec image(String.t(), keyword()) :: Image.t()
  def image(path, opts \\ []) when is_binary(path) do
    %Image{
      path: path,
      alt: Keyword.get(opts, :alt),
      mime_type: Keyword.get(opts, :mime_type)
    }
  end

  @spec upload_blob(Session.t(), binary(), keyword()) ::
          {:ok, map(), Session.t()} | {:error, any(), Session.t()}
  def upload_blob(%Session{} = session, binary, opts \\ []) when is_binary(binary) do
    mime_type = Keyword.get(opts, :mime_type, "application/octet-stream")

    XRPC.post(session, "com.atproto.repo.uploadBlob",
      body: binary,
      headers: [{"content-type", mime_type}]
    )
    |> case do
      {:ok, %{"blob" => blob}, updated_session} -> {:ok, blob, updated_session}
      {:ok, body, updated_session} -> {:error, {:invalid_blob_response, body}, updated_session}
      {:error, error, updated_session} -> {:error, error, updated_session}
    end
  end

  @spec upload_image(Session.t(), Image.t() | String.t()) ::
          {:ok, map(), Session.t()} | {:error, any(), Session.t()}
  def upload_image(%Session{} = session, %Image{} = image) do
    with {:ok, binary, mime_type, alt} <- read_image(image),
         {:ok, blob, updated_session} <- upload_blob(session, binary, mime_type: mime_type) do
      {:ok, %{"alt" => alt, "image" => blob}, updated_session}
    else
      {:error, reason} -> {:error, reason, session}
      {:error, reason, updated_session} -> {:error, reason, updated_session}
    end
  end

  def upload_image(%Session{} = session, path) when is_binary(path) do
    upload_image(session, image(path))
  end

  @spec upload_images(Session.t(), [Image.t() | String.t()]) ::
          {:ok, [map()], Session.t()} | {:error, any(), Session.t()}
  def upload_images(%Session{} = session, images) when is_list(images) do
    Enum.reduce_while(images, {:ok, [], session}, fn image, {:ok, acc, current_session} ->
      case upload_image(current_session, image) do
        {:ok, uploaded, next_session} -> {:cont, {:ok, acc ++ [uploaded], next_session}}
        {:error, error, next_session} -> {:halt, {:error, error, next_session}}
      end
    end)
  end

  @spec build_images_embed([map()]) :: map()
  def build_images_embed(images) when is_list(images) do
    %{
      "$type" => "app.bsky.embed.images",
      "images" => images
    }
  end

  defp read_image(%Image{blob: blob, mime_type: mime_type, alt: alt})
       when is_binary(blob) and is_binary(mime_type) do
    {:ok, blob, mime_type, alt || ""}
  end

  defp read_image(%Image{path: path, mime_type: mime_type, alt: alt}) when is_binary(path) do
    case File.read(path) do
      {:ok, binary} ->
        {:ok, binary, mime_type || MIME.from_path(path),
         alt || Path.basename(path, Path.extname(path))}

      {:error, reason} ->
        {:error, {:file_error, reason}}
    end
  end

  defp read_image(_image), do: {:error, :invalid_image}
end
