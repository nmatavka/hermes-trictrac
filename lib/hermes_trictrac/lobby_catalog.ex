defmodule HermesTrictrac.LobbyCatalog do
  @moduledoc """
  Server-owned presentation and join metadata for every table format exposed by
  the lobby. Browser, Android, and native desktop clients consume this shape,
  so a client never has to infer setup fields from a variant id.
  """

  @multi_seat_formats [
    %{
      id: "trictrac_en_poule",
      session_kind: "poule",
      style: "growing_pot",
      title: "Trictrac en poule",
      title_key: "lobby.multiSeatTrictracPouleTitle",
      meta: "2 active seats · rotating queue",
      meta_key: "lobby.multiSeatTrictracPouleMeta",
      join_fields: ["queue_size", "ante", "margot_enabled"]
    },
    %{
      id: "toccategli_en_poule",
      session_kind: "poule",
      style: "growing_pot",
      title: "Toccategli en poule",
      title_key: "lobby.multiSeatToccategliPouleTitle",
      meta: "2 active seats · rotating queue",
      meta_key: "lobby.multiSeatToccategliPouleMeta",
      join_fields: ["queue_size", "ante", "margot_enabled"]
    },
    %{
      id: "trictrac_en_poule_plumee",
      session_kind: "poule",
      style: "plucked_pot",
      title: "Trictrac en poule (plumée)",
      title_key: "lobby.multiSeatTrictracPoulePlumeeTitle",
      meta: "fixed ring · common fund",
      meta_key: "lobby.multiSeatTrictracPoulePlumeeMeta",
      join_fields: ["stake", "hole_value", "margot_enabled"]
    },
    %{
      id: "toccategli_en_poule_plumee",
      session_kind: "poule",
      style: "plucked_pot",
      title: "Toccategli en poule (plumée)",
      title_key: "lobby.multiSeatToccategliPoulePlumeeTitle",
      meta: "fixed ring · common fund",
      meta_key: "lobby.multiSeatToccategliPoulePlumeeMeta",
      join_fields: ["stake", "hole_value", "margot_enabled"]
    },
    %{
      id: "trictrac_aecrire_a_tourner",
      session_kind: "multiplayer",
      multiplayer_mode: "a_tourner",
      title: "Trictrac à écrire à tourner",
      title_key: "lobby.multiSeatAecrireTournerTitle",
      meta: "3 players · round robin",
      meta_key: "lobby.multiSeatAecrireTournerMeta",
      join_fields: ["cash_per_jeton"]
    },
    %{
      id: "trictrac_aecrire_chouette",
      session_kind: "multiplayer",
      multiplayer_mode: "chouette",
      title: "Trictrac à écrire chouette",
      title_key: "lobby.multiSeatAecrireChouetteTitle",
      meta: "3 players · chouette",
      meta_key: "lobby.multiSeatAecrireChouetteMeta",
      join_fields: ["cash_per_jeton"]
    },
    %{
      id: "trictrac_aecrire_deux_contre_deux",
      session_kind: "multiplayer",
      multiplayer_mode: "deux_contre_deux",
      title: "Trictrac à écrire deux contre deux",
      title_key: "lobby.multiSeatAecrireTeamsTitle",
      meta: "4 players · two sides",
      meta_key: "lobby.multiSeatAecrireTeamsMeta",
      join_fields: ["cash_per_jeton"]
    },
    %{
      id: "trictrac_combine_chouette",
      session_kind: "multiplayer",
      multiplayer_mode: "combine_chouette",
      title: "Trictrac combiné chouette",
      title_key: "lobby.multiSeatCombineChouetteTitle",
      meta: "3 players · combined chouette",
      meta_key: "lobby.multiSeatCombineChouetteMeta",
      join_fields: ["cash_per_jeton"]
    },
    %{
      id: "trictrac_combine_deux_contre_deux",
      session_kind: "multiplayer",
      multiplayer_mode: "combine_deux_contre_deux",
      title: "Trictrac combiné deux contre deux",
      title_key: "lobby.multiSeatCombineTeamsTitle",
      meta: "4 players · combined teams",
      meta_key: "lobby.multiSeatCombineTeamsMeta",
      join_fields: ["cash_per_jeton"]
    }
  ]

  @field_defaults %{
    "queue_size" => %{type: "integer", min: 1, step: 1, default: 1},
    "ante" => %{type: "integer", min: 1, step: 1, default: 1},
    "stake" => %{type: "integer", min: 1, step: 1, default: 50},
    "hole_value" => %{type: "integer", min: 1, step: 1, default: 5},
    "margot_enabled" => %{type: "boolean", default: false},
    "cash_per_jeton" => %{type: "decimal", min: 0.01, step: 0.01, default: 1.0}
  }

  def multi_seat_formats, do: @multi_seat_formats

  def cash_per_jeton_variant_ids do
    for %{id: id, join_fields: fields} <- @multi_seat_formats,
        "cash_per_jeton" in fields,
        do: id
  end

  def serialized do
    %{
      "multi_seat_formats" =>
        Enum.map(@multi_seat_formats, fn format ->
          format
          |> Map.new(fn {key, value} -> {Atom.to_string(key), value} end)
          |> Map.update!("join_fields", fn ids ->
            Enum.map(ids, &Map.put(@field_defaults[&1], "id", &1))
          end)
        end)
    }
  end
end
