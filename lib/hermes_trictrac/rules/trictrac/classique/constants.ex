defmodule HermesTrictrac.Rules.Trictrac.Classique.Constants do
  @coin_norm_pos 12

  @score_rules %{
    jan_rencontre: %{label: "jan de rencontre", source: :JAN_RENCONTRE},
    jan_de_meseas: %{label: "jan de meseas", source: :JAN_DE_MESEAS},
    contre_jan_de_meseas: %{
      label: "contre-jan de meseas",
      source: :CONTRE_JAN_DE_MESEAS
    },
    jan_de_deux_tables: %{label: "jan de deux tables", source: :JAN_DE_DEUX_TABLES},
    contre_jan_de_deux_tables: %{
      label: "contre-jan de deux tables",
      source: :CONTRE_JAN_DE_DEUX_TABLES
    },
    jan_de_six_tables: %{label: "jan de six tables", source: :JAN_DE_SIX_TABLES},
    jan_recompense: %{label: "jan de recompense", source: :JAN_RECOMPENSE},
    jan_qui_ne_peut: %{label: "jan qui ne peut", source: :JAN_QUI_NE_PEUT},
    coin_battu: %{label: "coin battu", source: :COIN_BATTU},
    coin_battu_a_faux: %{label: "coin battu a faux", source: :COIN_BATTU_A_FAUX},
    remplissage_petit: %{label: "remplissage petit jan", source: :REMPLISSAGE_PETIT},
    remplissage_grand: %{label: "remplissage grand jan", source: :REMPLISSAGE_GRAND},
    remplissage_retour: %{label: "remplissage jan de retour", source: :REMPLISSAGE_RETOUR},
    margot: %{label: "Margot la fendue", source: :MARGOT},
    impuissance: %{label: "impuissance", source: :IMPUISSANCE},
    conservation_petit: %{label: "conservation petit jan", source: :CONSERVATION_PETIT},
    conservation_grand: %{label: "conservation grand jan", source: :CONSERVATION_GRAND},
    conservation_retour: %{
      label: "conservation jan de retour",
      source: :CONSERVATION_RETOUR
    },
    pile_misere: %{label: "pile de misere", source: :PILE_MISERE},
    sortie: %{label: "sortie", source: :SORTIE}
  }

  @score_sources Map.new(@score_rules, fn {_rule, %{label: label, source: source}} ->
                   {label, source}
                 end)

  @score_rules_by_label Map.new(@score_rules, fn {rule, %{label: label}} -> {label, rule} end)
  @score_rules_by_source Map.new(@score_rules, fn {rule, %{source: source}} -> {source, rule} end)

  @jan_tables [
    %{key: :petit, from: 18, to: 23, label: "petit jan"},
    %{key: :grand, from: 12, to: 17, label: "grand jan"},
    %{key: :retour, from: 0, to: 5, label: "jan de retour"}
  ]

  def coin_norm_pos, do: @coin_norm_pos
  def score_source(rule_or_label), do: score_rule(rule_or_label) |> score_source_for_rule()
  def score_sources, do: @score_sources
  def score_rules, do: @score_rules
  def jan_tables, do: @jan_tables

  def jan_table(key), do: Enum.find(@jan_tables, &(&1.key == key))

  def jan_table!(key) do
    jan_table(key) || raise ArgumentError, "unknown jan table: #{inspect(key)}"
  end

  def score_rule(rule) when is_atom(rule) do
    cond do
      Map.has_key?(@score_rules, rule) -> rule
      Map.has_key?(@score_rules_by_source, rule) -> Map.fetch!(@score_rules_by_source, rule)
      true -> nil
    end
  end

  def score_rule(value) when is_binary(value) do
    Map.get(@score_rules_by_label, value) ||
      value
      |> String.to_existing_atom()
      |> score_rule()
  rescue
    ArgumentError -> nil
  end

  def score_rule(_value), do: nil

  def score_label(rule_or_label) do
    case score_rule(rule_or_label) do
      nil when is_binary(rule_or_label) -> rule_or_label
      nil when is_atom(rule_or_label) -> Atom.to_string(rule_or_label)
      nil -> nil
      rule -> @score_rules |> Map.fetch!(rule) |> Map.fetch!(:label)
    end
  end

  def score_source_for_rule(nil), do: nil

  def score_source_for_rule(rule) do
    @score_rules
    |> Map.get(rule, %{})
    |> Map.get(:source)
  end

  def remplissage_rule(:petit), do: :remplissage_petit
  def remplissage_rule(:grand), do: :remplissage_grand
  def remplissage_rule(:retour), do: :remplissage_retour

  def conservation_rule(:petit), do: :conservation_petit
  def conservation_rule(:grand), do: :conservation_grand
  def conservation_rule(:retour), do: :conservation_retour

  def scoring_tables_for_variant(%{id: "plein"}) do
    Enum.filter(@jan_tables, &(&1.key == :grand))
  end

  def scoring_tables_for_variant(_variant), do: @jan_tables
end
