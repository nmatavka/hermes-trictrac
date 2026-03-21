defmodule Backgammon.Rules.Trictrac.Classique.Constants do
  @coin_norm_pos 12

  @score_sources %{
    "jan de rencontre" => :JAN_RENCONTRE,
    "jan de meseas" => :JAN_DE_MESEAS,
    "contre-jan de meseas" => :CONTRE_JAN_DE_MESEAS,
    "jan de deux tables" => :JAN_DE_DEUX_TABLES,
    "contre-jan de deux tables" => :CONTRE_JAN_DE_DEUX_TABLES,
    "jan de six tables" => :JAN_DE_SIX_TABLES,
    "jan de recompense" => :JAN_RECOMPENSE,
    "jan qui ne peut" => :JAN_QUI_NE_PEUT,
    "coin battu" => :COIN_BATTU,
    "coin battu a faux" => :COIN_BATTU_A_FAUX,
    "remplissage petit jan" => :REMPLISSAGE_PETIT,
    "remplissage grand jan" => :REMPLISSAGE_GRAND,
    "remplissage jan de retour" => :REMPLISSAGE_RETOUR,
    "Margot la fendue" => :MARGOT,
    "impuissance" => :IMPUISSANCE,
    "conservation petit jan" => :CONSERVATION_PETIT,
    "conservation grand jan" => :CONSERVATION_GRAND,
    "conservation jan de retour" => :CONSERVATION_RETOUR,
    "pile de misere" => :PILE_MISERE,
    "sortie" => :SORTIE
  }

  @jan_tables [
    %{key: :petit, from: 18, to: 23, label: "petit jan"},
    %{key: :grand, from: 12, to: 17, label: "grand jan"},
    %{key: :retour, from: 0, to: 5, label: "jan de retour"}
  ]

  def coin_norm_pos, do: @coin_norm_pos
  def score_source(label), do: Map.get(@score_sources, label)
  def score_sources, do: @score_sources
  def jan_tables, do: @jan_tables

  def scoring_tables_for_variant(%{id: "plein"}) do
    Enum.filter(@jan_tables, &(&1.key == :grand))
  end

  def scoring_tables_for_variant(_variant), do: @jan_tables
end
