defmodule HermesTrictrac.DesktopCatalog do
  @moduledoc """
  Desktop-facing catalog metadata shared by the bundled local runtime and the
  native desktop client.

  The desktop shell uses this metadata to decide which variants are playable
  locally, which remain online-only, and where local AI is currently available.
  """

  alias HermesTrictrac.{BackgammonAiBot, Rules.Registry, TrictracModelBot}

  @schema_version 1

  def schema_version, do: @schema_version

  def catalog do
    %{
      "schema_version" => schema_version(),
      "variants" => Enum.map(variants(), &serialize_variant/1)
    }
  end

  def variants do
    ai_index = ai_index()

    Registry.all()
    |> Enum.sort_by(&variant_sort_key/1)
    |> Enum.map(fn variant ->
      session_mode = Map.get(variant, :session_mode)
      local_ai = Map.get(ai_index, variant.id, unavailable_ai())

      %{
        id: variant.id,
        title: variant.title,
        family: Atom.to_string(variant.family),
        session_mode: session_mode && Atom.to_string(session_mode),
        session_style: session_style(variant),
        base_variant_id: Map.get(variant, :base_variant_id),
        online_playable: true,
        local_playable: is_nil(session_mode),
        local_ai: local_ai
      }
    end)
  end

  def local_variant_ids do
    variants()
    |> Enum.filter(& &1.local_playable)
    |> Enum.map(& &1.id)
  end

  def online_variant_ids do
    variants()
    |> Enum.filter(& &1.online_playable)
    |> Enum.map(& &1.id)
  end

  defp serialize_variant(variant) do
    %{
      "id" => variant.id,
      "title" => variant.title,
      "family" => variant.family,
      "session_mode" => variant.session_mode,
      "session_style" => variant.session_style,
      "base_variant_id" => variant.base_variant_id,
      "online_playable" => variant.online_playable,
      "local_playable" => variant.local_playable,
      "local_ai" => variant.local_ai
    }
  end

  defp variant_sort_key(%{family: family, title: title} = variant) do
    case Map.get(variant, :session_mode) do
      nil -> {0, family_rank(family), title}
      session_mode -> {1, session_rank(session_mode), family_rank(family), title}
    end
  end

  defp family_rank(:race), do: 0
  defp family_rank(:trictrac), do: 1
  defp family_rank(:tourne_case), do: 2
  defp family_rank(:rabattues), do: 3
  defp family_rank(_other), do: 9

  defp session_rank(:poule), do: 0
  defp session_rank(:multiplayer), do: 1
  defp session_rank(_other), do: 9

  defp session_style(variant) do
    case {Map.get(variant, :session_mode), Map.get(variant, :session_style)} do
      {nil, _style} -> nil
      {_session_mode, style} when is_atom(style) -> Atom.to_string(style)
      _other -> nil
    end
  end

  defp ai_index do
    trictrac_ai =
      TrictracModelBot.presets()
      |> Enum.filter(& &1.available)
      |> Enum.group_by(& &1.variant_id)
      |> Enum.into(%{}, fn {variant_id, presets} ->
        {variant_id,
         %{
           "available" => true,
           "kind" => "trictrac_zero",
           "label" => TrictracModelBot.model_name(),
           "presets" => Enum.map(presets, & &1.id)
         }}
      end)

    Map.merge(
      %{
        "backgammon" => %{
          "available" => true,
          "kind" => "backgammon_ai",
          "label" => BackgammonAiBot.model_name(),
          "presets" => ["backgammon"]
        }
      },
      trictrac_ai
    )
  end

  defp unavailable_ai do
    %{
      "available" => false,
      "kind" => nil,
      "label" => nil,
      "presets" => []
    }
  end
end
