defmodule HermesTrictrac.Rules.Trictrac.Toc do
  alias HermesTrictrac.Rules.RaceCore
  alias HermesTrictrac.Rules.Trictrac.Classique

  def result(trictrac, roller, options) do
    doubles_mode? = Map.get(options, "doublesMode", "off") == "on"
    dice = get_in(trictrac, [:turn, :dice]) || %{values: []}

    trictrac
    |> get_in([:turn, :events])
    |> Kernel.||([])
    |> Enum.filter(&(event_points(&1) > 0))
    |> Enum.map(fn event ->
      beneficiary = beneficiary_atom(event_beneficiary(event))
      holes = if(doubles_mode? and double_event?(event, dice), do: 2, else: 1)

      %{
        beneficiary: beneficiary,
        holes: holes,
        own_die: beneficiary == roller,
        points: event_points(event)
      }
    end)
    |> Enum.sort_by(fn candidate -> {candidate.holes, candidate.points} end, :desc)
    |> List.first()
  end

  def apply_reprise(runtime, variant, color) do
    fresh = ensure_state(RaceCore.new(variant), variant)
    current_trictrac = Classique.ensure(runtime.trictrac)

    reset_trictrac =
      fresh.trictrac
      |> Map.put(:score_history, current_trictrac.score_history || [])
      |> Map.put(:options, current_trictrac.options || %{"margotEnabled" => false})
      |> Classique.set_turn_event_queue([])

    runtime
    |> Map.put(:board, fresh.board)
    |> Map.put(:dice, nil)
    |> Map.put(:legal_moves, [])
    |> Map.put(:history, [])
    |> Map.put(:turn_color, color)
    |> Map.put(:turn_number, runtime.turn_number + 1)
    |> Map.put(:pending_turn_decision, nil)
    |> put_in([:variant_state, :keep_turn], false)
    |> Map.put(:trictrac, reset_trictrac)
  end

  def reprise_prompt, do: "Choose whether to continue the game or take a reprise."

  defp double_event?(event, dice) do
    metadata = event_metadata(event)

    double?(dice) or
      multiway?(metadata[:ways] || metadata["ways"]) or
      multiway?(metadata[:true_ways] || metadata["true_ways"]) or
      multiway?(metadata[:false_ways] || metadata["false_ways"])
  end

  defp multiway?(value) when is_integer(value), do: value > 1
  defp multiway?(_value), do: false

  defp event_points(event), do: Map.get(event, :points) || Map.get(event, "points") || 0
  defp event_beneficiary(event), do: Map.get(event, :beneficiary) || Map.get(event, "beneficiary")
  defp event_metadata(event), do: Map.get(event, :metadata) || Map.get(event, "metadata") || %{}

  defp double?(%{values: [value, value]}), do: true
  defp double?(_dice), do: false

  defp beneficiary_atom("white"), do: :white
  defp beneficiary_atom("black"), do: :black
  defp beneficiary_atom(:white), do: :white
  defp beneficiary_atom(:black), do: :black

  defp ensure_state(runtime, variant) do
    trictrac =
      runtime.trictrac
      |> Kernel.||(%{})
      |> Classique.ensure()

    %{runtime | trictrac: trictrac, board: runtime.board || RaceCore.new(variant).board}
  end
end
