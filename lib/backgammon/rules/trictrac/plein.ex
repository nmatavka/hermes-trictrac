defmodule Backgammon.Rules.Trictrac.Plein do
  alias Backgammon.Rules.Trictrac.Classique

  def settle_match(runtime, color) do
    grand_events =
      runtime
      |> get_in([:trictrac, :turn, :events])
      |> Kernel.||([])
      |> Enum.any?(fn event ->
        beneficiary = Map.get(event, :beneficiary) || Map.get(event, "beneficiary")
        label = Map.get(event, :label) || Map.get(event, "label")

        beneficiary == Atom.to_string(color) and
          label in ["remplissage grand jan", "conservation grand jan"]
      end)

    if grand_events and Classique.table_full?(runtime.board, color, :grand) do
      %{
        runtime
        | match: %{
            runtime.match
            | is_over: true,
              winner: Atom.to_string(color),
              winner_kind: "plein"
          }
      }
    else
      runtime
    end
  end
end
