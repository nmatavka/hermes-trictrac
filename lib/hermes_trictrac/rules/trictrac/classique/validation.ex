defmodule HermesTrictrac.Rules.Trictrac.Classique.Validation do
  alias HermesTrictrac.Rules.Trictrac.Classique.{
    ConservationCandidate,
    Constants,
    Moves,
    Obligation,
    State
  }

  alias HermesTrictrac.Rules.Trictrac.VariantRules

  def build_obligations(
        start_board,
        end_board,
        variant,
        color,
        _dice,
        branches_info,
        conservation_candidates
      ) do
    must_fill =
      scoring_tables_for_variant(variant)
      |> Enum.filter(fn table ->
        !Moves.all_paired?(start_board, color, table.from, table.to) and
          Moves.all_paired?(end_board, color, table.from, table.to) and
          Enum.any?(
            branches(branches_info),
            &Moves.all_paired?(&1, color, table.from, table.to)
          )
      end)
      |> Enum.map(& &1.key)

    %Obligation{
      piece_type: Atom.to_string(color),
      must_fill: must_fill,
      must_conserve:
        Enum.map(conservation_candidates, fn candidate ->
          %ConservationCandidate{
            key: candidate.key,
            allow_sortie: candidate.allow_sortie,
            outside_before: candidate.outside_before
          }
        end)
    }
  end

  def obligations_satisfied?(board, color, obligations) do
    obligations = State.normalize_obligation(obligations)

    must_fill_ok? =
      Enum.all?(obligations.must_fill || [], fn key ->
        case Constants.jan_table(key) do
          nil -> true
          table -> Moves.all_paired?(board, color, table.from, table.to)
        end
      end)

    must_conserve_ok? =
      Enum.all?(obligations.must_conserve || [], fn requirement ->
        case Constants.jan_table(requirement.key) do
          nil ->
            true

          table ->
            Moves.all_paired?(board, color, table.from, table.to) or
              (requirement.allow_sortie and
                 State.outside_count(board, color) > (requirement.outside_before || 0))
        end
      end)

    must_fill_ok? and must_conserve_ok?
  end

  def coin_rest_satisfied?(_board, %{id: "plein"}, _color), do: true

  def coin_rest_satisfied?(board, _variant, color) do
    Moves.pieces_at(board, State.own_coin(color), color) != 1
  end

  def build_conservation_candidates(start_board, variant, color, dice, branches_info) do
    scoring_tables_for_variant(variant)
    |> Enum.filter(fn table -> Moves.all_paired?(start_board, color, table.from, table.to) end)
    |> Enum.flat_map(fn table ->
      conserve = can_remain_plein_after_turn(start_board, color, table, branches_info)

      if conserve.can_conserve or (table.key == :retour and conserve.can_privilege_conserve) do
        [
          %ConservationCandidate{
            key: table.key,
            points: VariantRules.conservation_points(variant, State.double?(dice)),
            allow_sortie: table.key == :retour and conserve.can_privilege_conserve,
            outside_before: conserve.outside_before
          }
        ]
      else
        []
      end
    end)
  end

  def can_remain_plein_after_turn(board, color, table, branches_info) do
    outside_before = State.outside_count(board, color)
    branches = branches(branches_info)

    can_conserve =
      Enum.any?(branches, &Moves.all_paired?(&1, color, table.from, table.to))

    can_privilege_conserve =
      table.key == :retour and
        Enum.any?(branches, fn branch ->
          State.outside_count(branch, color) > outside_before
        end)

    %{
      can_conserve: can_conserve,
      can_privilege_conserve: can_privilege_conserve,
      outside_before: outside_before
    }
  end

  defp scoring_tables_for_variant(%{id: "plein"}),
    do: Enum.filter(Constants.jan_tables(), &(&1.key == :grand))

  defp scoring_tables_for_variant(_variant), do: Constants.jan_tables()

  defp branches(%{branches: branches}) when is_list(branches), do: branches
  defp branches(_branches_info), do: []
end
