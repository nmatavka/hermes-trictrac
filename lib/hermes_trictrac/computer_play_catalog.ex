defmodule HermesTrictrac.ComputerPlayCatalog do
  @moduledoc """
  The single server-side description of the head-to-head computer-play rail.

  A variant being visible is deliberately independent from its model being
  released.  This lets players start a human game of a top-rail variant while
  the corresponding AlphaZero champion is still training.
  """

  alias HermesTrictrac.{BradeModelBot, RaceModelBot, TrictracModelBot}

  @primary [
    %{id: "backgammon", label: "Backgammon", bot_kind: "backgammon_zero", preset: "backgammon"},
    %{id: "tapa", label: "Tapa", bot_kind: "tapa_zero", preset: "tapa"},
    %{id: "jacquet", label: "Jacquet", bot_kind: "jacquet_zero", preset: "jacquet"},
    %{id: "garanguet", label: "Garanguet", bot_kind: "garanguet_zero", preset: "garanguet"},
    %{
      id: "trictrac_classique",
      label: "Trictrac classique",
      bot_kind: "trictrac_zero",
      preset: "classique"
    },
    %{id: "toccategli", label: "Toccategli", bot_kind: "trictrac_zero", preset: "toccategli"},
    %{id: "toc", label: "Toc", bot_kind: "trictrac_zero", preset: "toc"},
    %{id: "brade", label: "Bräde", bot_kind: "brade_zero", preset: "brade"}
  ]

  @tavli %{
    id: "tavli",
    label: "Tavli",
    bot_kind: "tavli_zero",
    preset: "tavli",
    selection_mode: :composite,
    members: ["backgammon", "tapa", "jacquet"],
    member_labels: ["Backgammon", "Tapa", "Jacquet"]
  }

  @secondary [
    %{id: "trictrac_aecrire", label: "Trictrac à écrire"},
    %{id: "trictrac_combine", label: "Trictrac combiné"},
    %{id: "sbaraglio", label: "Sbaraglio"},
    %{id: "sbaraglino", label: "Sbaraglino"},
    %{id: "plein", label: "Plein"},
    %{id: "tourne_case", label: "Tourne-Case"},
    %{id: "dames_rabattues", label: "Dames Rabattues"}
  ]

  @legacy_bot_aliases %{"backgammon_ai" => "backgammon_zero"}

  def primary, do: @primary
  def secondary, do: @secondary
  def tavli, do: @tavli
  def tavli_members, do: @tavli.members

  def all_head_to_head, do: @primary ++ [@tavli] ++ @secondary

  def entry(variant_id) when is_binary(variant_id) do
    Enum.find(all_head_to_head(), &(&1.id == variant_id))
  end

  def entry(_variant_id), do: nil

  def computer_entry(variant_id) do
    case entry(variant_id) do
      %{bot_kind: _kind} = entry -> entry
      _ -> nil
    end
  end

  def primary_variant?(variant_id), do: not is_nil(computer_entry(variant_id))
  def human_only?(variant_id), do: not primary_variant?(variant_id)

  def composite?(variant_id),
    do: get_in(entry(variant_id) || %{}, [:selection_mode]) == :composite

  def canonical_bot_kind(kind) when is_binary(kind), do: Map.get(@legacy_bot_aliases, kind, kind)
  def canonical_bot_kind(kind), do: kind

  def requested_bot(variant_id) do
    case computer_entry(variant_id) do
      %{bot_kind: bot_kind} -> bot_kind
      _ -> nil
    end
  end

  def accepts_bot?(variant_id, requested_kind) do
    requested_kind = canonical_bot_kind(requested_kind)
    requested_kind == requested_bot(variant_id)
  end

  def available?(variant_id) do
    case computer_entry(variant_id) do
      %{id: "brade"} -> BradeModelBot.available?("brade")
      %{bot_kind: "trictrac_zero", preset: preset} -> TrictracModelBot.available?(preset)
      %{preset: preset} -> RaceModelBot.available?(preset)
      _ -> false
    end
  end

  def availability(variant_id) do
    case computer_entry(variant_id) do
      nil ->
        unavailable("Computer play is not offered for this game.")

      %{bot_kind: kind, preset: preset} = entry ->
        %{
          "available" => available?(variant_id),
          "kind" => kind,
          "label" => model_label(entry),
          "presets" => [preset]
        }
    end
  end

  def serialized_entry(entry) do
    %{
      "id" => entry.id,
      "label" => entry.label,
      "menu_section" => if(entry == @tavli, do: "composite", else: section_for(entry)),
      "selection_mode" => entry |> Map.get(:selection_mode, :single) |> Atom.to_string(),
      "members" => Map.get(entry, :members, []),
      "computer_play" => availability(entry.id)
    }
  end

  def unavailable(reason),
    do: %{
      "available" => false,
      "kind" => nil,
      "label" => nil,
      "presets" => [],
      "reason" => reason
    }

  defp section_for(entry) do
    if Enum.any?(@primary, &(&1.id == entry.id)), do: "primary", else: "more"
  end

  defp model_label(%{id: "brade"}), do: BradeModelBot.model_name()

  defp model_label(%{bot_kind: "trictrac_zero", preset: preset}),
    do: TrictracModelBot.model_name(preset)

  defp model_label(%{label: label}), do: "#{label} Zero"
end
