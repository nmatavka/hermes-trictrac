# Provenance:
# - Adapted from proto_rune-main/lib/proto_rune/rich_text.ex (MIT)
# - Adapted from broadcast.ex-main/lib/bluesky/facet.ex (MIT)
defmodule Hermes.Bluesky.RichText do
  @moduledoc """
  Builder and facet extractor for Bluesky rich text.
  """

  alias Hermes.Bluesky.Identity

  defstruct text: "", facets: []

  @type facet_map :: map()

  @type t :: %__MODULE__{
          text: String.t(),
          facets: [facet_map()]
        }

  @spec new() :: t()
  def new, do: %__MODULE__{}

  @spec text(t(), String.t()) :: t()
  def text(%__MODULE__{} = rich_text, content) when is_binary(content) do
    %{rich_text | text: rich_text.text <> content}
  end

  @spec mention(t(), String.t()) :: t()
  def mention(%__MODULE__{} = rich_text, handle) when is_binary(handle) do
    start_offset = byte_size(rich_text.text)
    mention_text = "@#{handle}"
    end_offset = start_offset + byte_size(mention_text)

    case Identity.resolve_handle(handle) do
      {:ok, did} ->
        facet = %{
          "index" => %{"byteStart" => start_offset, "byteEnd" => end_offset},
          "features" => [%{"$type" => "app.bsky.richtext.facet#mention", "did" => did}]
        }

        %{rich_text | text: rich_text.text <> mention_text, facets: rich_text.facets ++ [facet]}

      {:error, _reason} ->
        %{rich_text | text: rich_text.text <> mention_text}
    end
  end

  @spec link(t(), String.t(), String.t()) :: t()
  def link(%__MODULE__{} = rich_text, link_text, url)
      when is_binary(link_text) and is_binary(url) do
    start_offset = byte_size(rich_text.text)
    end_offset = start_offset + byte_size(link_text)

    facet = %{
      "index" => %{"byteStart" => start_offset, "byteEnd" => end_offset},
      "features" => [%{"$type" => "app.bsky.richtext.facet#link", "uri" => url}]
    }

    %{rich_text | text: rich_text.text <> link_text, facets: rich_text.facets ++ [facet]}
  end

  @spec hashtag(t(), String.t()) :: t()
  def hashtag(%__MODULE__{} = rich_text, tag) when is_binary(tag) do
    start_offset = byte_size(rich_text.text)
    tag_text = "##{tag}"
    end_offset = start_offset + byte_size(tag_text)

    facet = %{
      "index" => %{"byteStart" => start_offset, "byteEnd" => end_offset},
      "features" => [%{"$type" => "app.bsky.richtext.facet#tag", "tag" => tag}]
    }

    %{rich_text | text: rich_text.text <> tag_text, facets: rich_text.facets ++ [facet]}
  end

  @spec build(t()) :: {:ok, t()}
  def build(%__MODULE__{} = rich_text), do: {:ok, rich_text}

  @spec from_text(String.t()) :: t()
  def from_text(text) when is_binary(text) do
    %__MODULE__{text: text, facets: facets(text)}
  end

  @spec to_post_data(t()) :: map()
  def to_post_data(%__MODULE__{} = rich_text) do
    %{
      text: rich_text.text,
      facets: rich_text.facets
    }
  end

  @spec to_plain_text(t()) :: String.t()
  def to_plain_text(%__MODULE__{text: text}), do: text

  @spec facets(t() | String.t()) :: [facet_map()]
  def facets(%__MODULE__{facets: facets}), do: facets

  def facets(text) when is_binary(text) do
    (extract_links(text) ++ extract_hashtags(text))
    |> Enum.sort_by(fn facet -> facet["index"]["byteStart"] end)
  end

  defp extract_links(text) do
    regex = ~r/https?:\/\/[a-zA-Z0-9][-a-zA-Z0-9.]*\.[a-zA-Z0-9][-a-zA-Z0-9%_.~\/#?&=:]*/u

    Regex.scan(regex, text, return: :index)
    |> Enum.map(fn [{start_index, length}] ->
      url = binary_part(text, start_index, length)

      clean_url =
        case Regex.run(~r/^(.*?)([.,!?;:]*)$/u, url) do
          [_, stripped, punctuation] when punctuation != "" -> stripped
          _ -> url
        end

      adjusted_length = byte_size(clean_url)

      %{
        "index" => %{
          "byteStart" => start_index,
          "byteEnd" => start_index + adjusted_length
        },
        "features" => [
          %{
            "$type" => "app.bsky.richtext.facet#link",
            "uri" => clean_url
          }
        ]
      }
    end)
  end

  defp extract_hashtags(text) do
    regex = ~r/#([a-zA-Z0-9_]+)/u

    Regex.scan(regex, text, return: :index)
    |> Enum.map(fn [{start_index, length}, {tag_start, tag_length}] ->
      tag = binary_part(text, tag_start, tag_length)

      %{
        "index" => %{
          "byteStart" => start_index,
          "byteEnd" => start_index + length
        },
        "features" => [
          %{
            "$type" => "app.bsky.richtext.facet#tag",
            "tag" => tag
          }
        ]
      }
    end)
  end
end
