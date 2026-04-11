defmodule HermesTrictrac.Rules.Trictrac.Classique.Scoring do
  alias HermesTrictrac.Rules.Trictrac.Classique.{Constants, ScoreEvent, State}
  alias HermesTrictrac.Rules.Trictrac.VariantRules

  def apply_points(
        trictrac,
        variant,
        color,
        points,
        label,
        turn_number,
        source \\ nil,
        metadata \\ %{}
      ) do
    trictrac = State.ensure(trictrac)
    idx = State.score_index(color)
    opp_idx = State.score_index(State.opposite(color))
    score = Enum.at(trictrac.score, idx)
    opp = Enum.at(trictrac.score, opp_idx)
    trous_before = score.trous || 0
    total = (score.points || 0) + points
    trous_gain = VariantRules.trous_gain(variant, total, score, opp)

    updated_score =
      score
      |> Map.put(:points, rem(total, 12))
      |> Map.put(:trous, trous_before + trous_gain)
      |> Map.put(:doubling_active, if(VariantRules.toccategli?(variant), do: false, else: true))
      |> Map.put(:bredouille, if(VariantRules.toccategli?(variant), do: false, else: true))

    updated_opp =
      opp
      |> Map.put(:bredouille, false)
      |> Map.put(:doubling_active, false)
      |> Map.put(:points, if(trous_gain > 0, do: 0, else: opp.points || 0))

    score_list =
      trictrac.score
      |> List.replace_at(idx, updated_score)
      |> List.replace_at(opp_idx, updated_opp)
      |> maybe_apply_etendard(variant)

    event =
      %ScoreEvent{
        label: label,
        piece_type: Atom.to_string(color),
        beneficiary: Atom.to_string(color),
        points: points,
        trous_delta: trous_gain,
        turn_number: turn_number,
        source: source || source_from_label(label),
        metadata: metadata
      }

    trictrac
    |> Map.put(:score, score_list)
    |> update_in([:turn, :score_by_type, color], &((&1 || 0) + points))
    |> update_in([:score_history], &((&1 || []) ++ [event]))
  end

  def event(color, label, points, metadata \\ %{}, source_override \\ nil) do
    %ScoreEvent{
      label: label,
      beneficiary: Atom.to_string(color),
      points: points,
      source: source_override || source_from_label(label),
      metadata: metadata
    }
  end

  def maybe_record_sortie_event(trictrac, color, turn_number) do
    if State.sortie_awarded?(trictrac) do
      sortie_points =
        trictrac
        |> get_in([:turn, :events])
        |> Enum.find(&(State.event_label(&1) == "sortie"))
        |> Map.get(:points)

      put_in(trictrac, [:sortie, :last_event], %{
        piece_type: Atom.to_string(color),
        points: sortie_points,
        turn_number: turn_number
      })
    else
      trictrac
    end
  end

  def label_for_points(label), do: label

  def source_from_label(label) do
    Constants.score_sources()
    |> Map.get(label)
  end

  defp maybe_apply_etendard(score_list, variant) do
    if VariantRules.apply_etendard?(variant), do: apply_etendard(score_list), else: score_list
  end

  defp apply_etendard([white, black]) do
    cond do
      white.trous > 0 and black.trous == 0 ->
        [
          %{white | etendard: true, grande_bredouille: true},
          %{black | etendard: false, grande_bredouille: false}
        ]

      black.trous > 0 and white.trous == 0 ->
        [
          %{white | etendard: false, grande_bredouille: false},
          %{black | etendard: true, grande_bredouille: true}
        ]

      true ->
        [
          %{white | etendard: false, grande_bredouille: false},
          %{black | etendard: false, grande_bredouille: false}
        ]
    end
  end
end
