defmodule HermesTrictrac.Rules.Trictrac.VariantRules do
  alias HermesTrictrac.Rules.Trictrac.Classique.State

  @toccategli "toccategli"

  def toccategli?(%{id: @toccategli}), do: true
  def toccategli?(_variant), do: false

  def jan_rencontre_points(variant, is_double) do
    if toccategli?(variant), do: 0, else: if(is_double, do: 6, else: 4)
  end

  def coin_jan_points(variant, is_double) do
    if toccategli?(variant),
      do: if(is_double, do: 4, else: 2),
      else: if(is_double, do: 6, else: 4)
  end

  def six_tables_points(variant) do
    if toccategli?(variant), do: 2, else: 4
  end

  def jan_recompense_points(variant, target, opp, is_double, ways) do
    cond do
      ways <= 0 ->
        0

      not toccategli?(variant) ->
        jan_recompense_base(target, opp, is_double) * ways

      petit_like_target?(target, opp) and ways == 1 ->
        if(is_double, do: 4, else: 2)

      petit_like_target?(target, opp) ->
        ways * if(is_double, do: 2, else: 1)

      true ->
        ways * if(is_double, do: 2, else: 1)
    end
  end

  def coin_battu_points(variant, is_double) do
    if toccategli?(variant), do: 2, else: if(is_double, do: 6, else: 4)
  end

  def remplissage_points(variant, table_key, is_double, ways) do
    cond do
      ways <= 0 ->
        0

      not toccategli?(variant) ->
        ways * if(is_double, do: 6, else: 4)

      table_key == :grand ->
        ways * 2

      true ->
        ways * if(is_double, do: 4, else: 2)
    end
  end

  def conservation_points(variant, is_double) do
    if toccategli?(variant),
      do: if(is_double, do: 4, else: 2),
      else: if(is_double, do: 6, else: 4)
  end

  def pile_misere_points(variant, is_double) do
    if toccategli?(variant), do: 0, else: if(is_double, do: 6, else: 4)
  end

  def margot_points(variant, is_double, ways) do
    cond do
      ways <= 0 ->
        0

      toccategli?(variant) ->
        ways * if(is_double, do: 2, else: 1)

      true ->
        ways * if(is_double, do: 4, else: 2)
    end
  end

  def impuissance_points(variant, dice, unplayable_dice) do
    per_die =
      if toccategli?(variant) do
        if State.double?(dice), do: 2, else: 1
      else
        2
      end

    unplayable_dice * per_die
  end

  def sortie_points(variant, is_double) do
    if toccategli?(variant), do: 2, else: if(is_double, do: 6, else: 4)
  end

  def false_hit_scoring?(variant), do: not toccategli?(variant)

  def trous_gain(variant, total, score, opp) do
    base_trous = div(total, 12)

    cond do
      base_trous <= 0 ->
        0

      toccategli?(variant) ->
        base_trous * toccategli_hole_result(opp.points || 0).multiplier

      true ->
        base_trous * if(score.doubling_active, do: 2, else: 1)
    end
  end

  def apply_etendard?(variant), do: not toccategli?(variant)

  def toccategli_hole_result(opponent_points) when is_integer(opponent_points) do
    {classification, multiplier} =
      cond do
        opponent_points == 0 -> {:march, 4}
        opponent_points <= 3 -> {:triple, 3}
        opponent_points <= 6 -> {:double, 2}
        true -> {:simple, 1}
      end

    %{
      classification: classification,
      multiplier: multiplier,
      opponent_points: opponent_points
    }
  end

  defp petit_like_target?(target, opp) do
    opp_norm = State.norm_pos(target, opp)
    opp_norm >= 18 or opp_norm < 6
  end

  defp jan_recompense_base(target, opp, is_double) do
    if petit_like_target?(target, opp) do
      if is_double, do: 6, else: 4
    else
      if is_double, do: 4, else: 2
    end
  end
end
