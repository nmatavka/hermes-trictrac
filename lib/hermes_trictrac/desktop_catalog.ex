defmodule HermesTrictrac.DesktopCatalog do
  @moduledoc """
  Desktop-facing catalog metadata shared by the bundled local runtime and the
  native desktop client.

  The desktop shell uses this metadata to decide which variants are playable
  locally, which remain online-only, and where local AI is currently available.
  """

  alias HermesTrictrac.{ComputerPlayCatalog, LobbyCatalog, Rules.Registry}

  @schema_version 3

  def schema_version, do: @schema_version

  def catalog do
    %{
      "schema_version" => schema_version(),
      "variants" => Enum.map(variants(), &serialize_variant/1),
      "lobby" => LobbyCatalog.serialized()
    }
  end

  def variants do
    Registry.all()
    |> Enum.sort_by(&variant_sort_key/1)
    |> Enum.map(fn variant ->
      session_mode = Map.get(variant, :session_mode)
      presentation = presentation(variant.id)

      %{
        id: variant.id,
        title: variant.title,
        family: Atom.to_string(variant.family),
        session_mode: session_mode && Atom.to_string(session_mode),
        session_style: session_style(variant),
        base_variant_id: Map.get(variant, :base_variant_id),
        online_playable: true,
        local_playable: true,
        local_ai: ComputerPlayCatalog.availability(variant.id),
        menu_section: presentation.menu_section,
        menu_rank: presentation.menu_rank,
        selection_mode: presentation.selection_mode,
        members: presentation.members,
        menu_label: presentation.menu_label
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
      "menu_label" => variant.menu_label,
      "family" => variant.family,
      "session_mode" => variant.session_mode,
      "session_style" => variant.session_style,
      "base_variant_id" => variant.base_variant_id,
      "online_playable" => variant.online_playable,
      "local_playable" => variant.local_playable,
      "local_ai" => variant.local_ai,
      "menu_section" => variant.menu_section,
      "menu_rank" => variant.menu_rank,
      "selection_mode" => variant.selection_mode,
      "members" => variant.members
    }
  end

  defp variant_sort_key(%{family: family, title: title} = variant) do
    presentation = presentation(variant.id)

    case Map.get(variant, :session_mode) do
      nil -> {0, presentation.menu_rank, family_rank(family), title}
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

  defp presentation(variant_id) do
    case ComputerPlayCatalog.entry(variant_id) do
      %{selection_mode: :composite, members: members} ->
        %{
          menu_section: "composite",
          menu_rank: 8,
          selection_mode: "composite",
          members: members,
          menu_label: "Tavli"
        }

      entry when is_map(entry) ->
        if Map.has_key?(entry, :bot_kind) do
          rank = ComputerPlayCatalog.primary() |> Enum.find_index(&(&1.id == variant_id))

          %{
            menu_section: "primary",
            menu_rank: rank || 0,
            selection_mode: "single",
            members: [],
            menu_label: entry.label
          }
        else
          more_presentation(variant_id)
        end

      nil ->
        more_presentation(variant_id)
    end
  end

  defp more_presentation(variant_id) do
    secondary_rank = ComputerPlayCatalog.secondary() |> Enum.find_index(&(&1.id == variant_id))

    %{
      menu_section: "more",
      menu_rank: 100 + (secondary_rank || 99),
      selection_mode: "single",
      members: [],
      menu_label: nil
    }
  end
end
