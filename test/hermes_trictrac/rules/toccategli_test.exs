defmodule HermesTrictrac.Rules.ToccategliTest do
  use ExUnit.Case, async: true

  alias HermesTrictrac.Rules.Registry
  alias HermesTrictrac.Rules.Trictrac.Classique
  alias HermesTrictrac.Rules.Trictrac.VariantRules

  test "registry exposes toccategli as a trictrac variant" do
    variant = Registry.fetch!("toccategli")

    assert variant.title == "Toccategli"
    assert variant.family == :trictrac
  end

  test "toccategli trous gained depend on the opponent bridge state" do
    variant = Registry.fetch!("toccategli")

    quadruple =
      Classique.ensure(%{
        score: [%{points: 11, trous: 0}, %{points: 0, trous: 0}]
      })
      |> Classique.apply_points(variant, :white, 1, "test", 1)

    assert get_in(quadruple, [:score, Access.at(0), :trous]) == 4
    assert get_in(quadruple, [:score, Access.at(0), :points]) == 0
    assert get_in(quadruple, [:score, Access.at(1), :points]) == 0

    double =
      Classique.ensure(%{
        score: [%{points: 11, trous: 0}, %{points: 5, trous: 0}]
      })
      |> Classique.apply_points(variant, :white, 1, "test", 1)

    assert get_in(double, [:score, Access.at(0), :trous]) == 2
    assert get_in(double, [:score, Access.at(0), :points]) == 0
    assert get_in(double, [:score, Access.at(1), :points]) == 0
  end

  test "toccategli allows entry into the opponent grand jan while classique forbids it" do
    board = %{
      points:
        Enum.map(0..23, fn index ->
          cond do
            index == 0 -> %{white: 0, black: 15}
            true -> %{white: 0, black: 0}
          end
        end),
      bar: %{white: 0, black: 0},
      outside: %{white: 0, black: 0}
    }

    classique = Registry.fetch!("trictrac_classique")
    toccategli = Registry.fetch!("toccategli")

    assert Classique.destination_forbidden_by_jan_interdit?(board, classique, :white, 10)
    refute Classique.destination_forbidden_by_jan_interdit?(board, toccategli, :white, 10)
  end

  test "toccategli follows the provided tariff and omits faux-only scores" do
    variant = Registry.fetch!("toccategli")

    assert VariantRules.jan_rencontre_points(variant, false) == 0
    assert VariantRules.pile_misere_points(variant, false) == 0
    refute VariantRules.false_hit_scoring?(variant)

    assert VariantRules.coin_jan_points(variant, false) == 2
    assert VariantRules.coin_jan_points(variant, true) == 4
    assert VariantRules.six_tables_points(variant) == 2
    assert VariantRules.coin_battu_points(variant, false) == 2
    assert VariantRules.coin_battu_points(variant, true) == 2
    assert VariantRules.sortie_points(variant, false) == 2
    assert VariantRules.sortie_points(variant, true) == 2
    assert VariantRules.impuissance_points(variant, %{values: [6, 5]}, 1) == 1
    assert VariantRules.impuissance_points(variant, %{values: [6, 6]}, 2) == 4
    assert VariantRules.margot_points(variant, false, 2) == 2
    assert VariantRules.margot_points(variant, true, 2) == 4
  end
end
