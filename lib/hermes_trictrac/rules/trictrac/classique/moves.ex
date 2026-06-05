defmodule HermesTrictrac.Rules.Trictrac.Classique.Moves do
  alias HermesTrictrac.Rules.Trictrac.Classique.{Constants, State}
  alias HermesTrictrac.Rules.Trictrac.VariantRules

  def legal_moves(runtime, variant, color) do
    moves_left = (runtime.dice && runtime.dice.moves_left) || []

    runtime.board
    |> raw_legal_moves(variant, color, moves_left)
    |> Enum.uniq_by(fn move ->
      {move.from, move.to, move.die, Map.get(move, :dice_used), Map.get(move, :via),
       Map.get(move, :sequence)}
    end)
    |> filter_natural_coin_priority()
    |> filter_coin_rest_immediate_follow(runtime, variant, color)
    |> filter_coin_rest_setup_follow(runtime, variant, color)
  end

  def raw_legal_moves(board, variant, color, moves_left) do
    singles =
      0..23
      |> Enum.flat_map(fn point ->
        if pieces_at(board, point, color) > 0 do
          Enum.flat_map(Enum.with_index(moves_left), fn {die, _idx} ->
            single_trictrac_moves(board, variant, color, point, die)
          end)
        else
          []
        end
      end)

    combined =
      case moves_left do
        [a, b] ->
          0..23
          |> Enum.flat_map(fn point ->
            if pieces_at(board, point, color) > 0 do
              combined_trictrac_moves(board, variant, color, point, a, b)
            else
              []
            end
          end)

        _ ->
          []
      end

    singles ++ combined
  end

  def destination_forbidden_by_jan_interdit?(board, variant, color, destination) do
    if destination == own_coin(variant, color) do
      false
    else
      opp = State.opposite(color)
      opp_norm = norm_pos(variant, destination, opp)
      destination_table = destination_jan_table_for_opponent_norm(opp_norm)

      cond do
        is_nil(destination_table) ->
          false

        VariantRules.toccategli?(variant) and destination_table == :grand and
            opponent_table_protected?(board, variant, opp, :grand) ->
          false

        true ->
          case retour_passage_phase(board, variant, opp) do
            :retour_blocked ->
              destination_table in [:petit, :grand]

            :retour_open_grand_protected ->
              destination_table == :grand

            :retour_open_grand_open ->
              false
          end
      end
    end
  end

  def table_full?(board, color, key) do
    case Constants.jan_table(State.normalize_table_key(key)) do
      nil -> false
      table -> all_paired?(board, color, table.from, table.to)
    end
  end

  def apply_step_move(board, color, move) do
    count = Map.get(move, :count, 1)

    board
    |> remove_piece(color, move.from, count)
    |> apply_step_hit(color, move)
    |> add_piece(color, move.to, count)
  end

  def pieces_at(board, point, color), do: get_in(board, [:points, Access.at(point), color]) || 0

  def count_all_at(board, point),
    do: pieces_at(board, point, :white) + pieces_at(board, point, :black)

  def coin_count_from_board(board, point, color), do: pieces_at(board, point, color)

  def all_paired?(board, color, from_norm, to_norm) do
    Enum.all?(from_norm..to_norm, fn norm ->
      pieces_at(board, State.denorm_pos(norm, color), color) >= 2
    end)
  end

  def all_paired?(board, variant, color, from_norm, to_norm) do
    Enum.all?(from_norm..to_norm, fn norm ->
      pieces_at(board, State.denorm_pos(variant, norm, color), color) >= 2
    end)
  end

  def all_occupied?(board, color, from_norm, to_norm) do
    Enum.all?(from_norm..to_norm, fn norm ->
      pieces_at(board, State.denorm_pos(norm, color), color) >= 1
    end)
  end

  def all_occupied?(board, variant, color, from_norm, to_norm) do
    Enum.all?(from_norm..to_norm, fn norm ->
      pieces_at(board, State.denorm_pos(variant, norm, color), color) >= 1
    end)
  end

  def opponent_table_protected?(board, variant, color, :petit) do
    can_opponent_still_fill_table?(board, variant, color, :petit) or
      table_full_for_movement?(board, variant, color, :petit)
  end

  def opponent_table_protected?(board, variant, color, :grand) do
    can_opponent_still_fill_table?(board, variant, color, :grand) or
      table_full_for_movement?(board, variant, color, :grand)
  end

  def can_opponent_still_fill_jan?(board, color, jan_start_norm) do
    can_opponent_still_fill_jan?(board, %{}, color, jan_start_norm)
  end

  def can_opponent_still_fill_jan?(board, variant, color, jan_start_norm) do
    case jan_table_key_for_start_norm(jan_start_norm) do
      nil -> false
      key -> can_opponent_still_fill_table?(board, variant, color, key)
    end
  end

  defp remove_piece(board, color, point, count),
    do: update_in(board, [:points, Access.at(point), color], &max((&1 || 0) - count, 0))

  defp add_piece(board, color, "home", count),
    do: update_in(board, [:outside, color], &((&1 || 0) + count))

  defp add_piece(board, color, point, count),
    do: update_in(board, [:points, Access.at(point), color], &((&1 || 0) + count))

  defp apply_step_hit(board, _color, _move), do: board

  defp single_trictrac_moves(board, variant, color, point, die) do
    source_norm = norm_pos(variant, point, color)
    source_count = pieces_at(board, point, color)
    target_norm = source_norm - die

    cond do
      plein_forbids_opponent_side?(variant) and target_norm < Constants.coin_norm_pos() ->
        []

      target_norm >= 0 ->
        raw_destination = denorm_pos(variant, target_norm, color)

        with {:ok, destination, coin_mode} <-
               resolve_coin_destination(board, variant, color, raw_destination),
             {:ok, hit?, count} <-
               landing_allowed(board, variant, color, point, source_count, destination, coin_mode) do
          [
            %{
              from: point,
              to: destination,
              die: die,
              hit?: hit?,
              count: count,
              coin_mode: coin_mode
            }
          ]
        else
          _ -> []
        end

      true ->
        maybe_sortie_moves(board, variant, color, point, die, [die])
    end
  end

  defp combined_trictrac_moves(board, variant, color, point, a, b) do
    [{a, b}, {b, a}]
    |> Enum.uniq()
    |> Enum.flat_map(fn {first, second} ->
      combined_trictrac_move(board, variant, color, point, first, second)
    end)
  end

  defp combined_trictrac_move(board, variant, color, point, first, second) do
    source_norm = norm_pos(variant, point, color)
    source_count = pieces_at(board, point, color)
    middle_norm = source_norm - first
    final_norm = source_norm - first - second

    cond do
      plein_forbids_opponent_side?(variant) and final_norm < Constants.coin_norm_pos() ->
        []

      middle_norm < 0 ->
        maybe_sortie_sum_move(board, variant, color, point, first, second)

      final_norm >= 0 ->
        middle = denorm_pos(variant, middle_norm, color)
        raw_destination = denorm_pos(variant, final_norm, color)
        opp = State.opposite(color)
        middle_opp = pieces_at(board, middle, opp)
        middle_empty = count_all_at(board, middle) == 0
        final_opp = pieces_at(board, raw_destination, opp)
        passing_retour? = source_norm >= 6 and final_norm < 6
        retour_phase = retour_passage_phase(board, variant, opp)

        cond do
          passing_retour? and retour_phase == :retour_blocked ->
            []

          middle_opp >= 2 ->
            []

          passing_retour? and not middle_empty and not (middle_opp == 1 and final_opp == 1) ->
            []

          middle_opp == 1 and final_opp != 1 ->
            []

          true ->
            move_coin_mode =
              cond do
                middle in [own_coin(variant, color), opp_coin(variant, color)] and middle_empty ->
                  :intermediate_coin

                true ->
                  :normal
              end

            with {:ok, destination, coin_mode} <-
                   resolve_coin_destination(board, variant, color, raw_destination),
                 {:ok, hit?, count} <-
                   landing_allowed(
                     board,
                     variant,
                     color,
                     point,
                     source_count,
                     destination,
                     if(coin_mode == :normal, do: move_coin_mode, else: coin_mode)
                   ) do
              [
                %{
                  from: point,
                  to: destination,
                  die: first + second,
                  dice_used: [first, second],
                  sequence: [first, second],
                  hit?: hit?,
                  count: count,
                  coin_mode: if(coin_mode == :normal, do: move_coin_mode, else: coin_mode),
                  via: middle,
                  intermediate_hit: if(middle_opp == 1, do: middle, else: nil)
                }
              ]
            else
              _ -> []
            end
        end

      true ->
        maybe_sortie_sum_move(board, variant, color, point, first, second)
    end
  end

  defp maybe_sortie_moves(_board, %{id: "plein"}, _color, _point, _die, _dice_used), do: []

  defp maybe_sortie_moves(board, variant, color, point, die, dice_used) do
    source_norm = norm_pos(variant, point, color)

    cond do
      not can_sortie?(board, variant, color) ->
        []

      source_norm + 1 == die ->
        [
          %{
            from: point,
            to: "home",
            die: Enum.sum(dice_used),
            dice_used: dice_used,
            count: 1,
            coin_mode: :sortie_exact
          }
        ]

      die > source_norm + 1 and source_norm == furthest_sortie_norm(board, variant, color) ->
        [
          %{
            from: point,
            to: "home",
            die: Enum.sum(dice_used),
            dice_used: dice_used,
            count: 1,
            coin_mode: :sortie_excedant
          }
        ]

      true ->
        []
    end
  end

  defp maybe_sortie_sum_move(_board, %{id: "plein"}, _color, _point, _first, _second), do: []

  defp maybe_sortie_sum_move(board, variant, color, point, first, second) do
    source_norm = norm_pos(variant, point, color)
    sum = first + second

    cond do
      can_sortie?(board, variant, color) and source_norm + 1 == sum and first < source_norm + 1 and
          second < source_norm + 1 ->
        [
          %{
            from: point,
            to: "home",
            die: sum,
            dice_used: [first, second],
            sequence: [first, second],
            count: 1,
            coin_mode: :point_sortant,
            via: "edge"
          }
        ]

      can_privilege_sortie?(board, variant, color) and source_norm in 6..11 and
          source_norm + 1 == sum ->
        [
          %{
            from: point,
            to: "home",
            die: sum,
            dice_used: [first, second],
            sequence: [first, second],
            count: 1,
            coin_mode: :sortie_privilege,
            via: "edge"
          }
        ]

      true ->
        []
    end
  end

  defp can_sortie?(board, variant, color) do
    Enum.all?(6..23, fn norm ->
      pieces_at(board, denorm_pos(variant, norm, color), color) == 0
    end)
  end

  defp can_privilege_sortie?(board, variant, color) do
    Enum.all?(12..23, fn norm ->
      pieces_at(board, denorm_pos(variant, norm, color), color) == 0
    end)
  end

  defp furthest_sortie_norm(board, variant, color) do
    5..0//-1
    |> Enum.find(fn norm -> pieces_at(board, denorm_pos(variant, norm, color), color) > 0 end)
  end

  defp resolve_coin_destination(board, %{id: "plein"} = variant, color, destination) do
    if destination == own_coin(variant, color) do
      {:ok, own_coin(variant, color), :plein_coin}
    else
      resolve_standard_coin_destination(board, variant, color, destination)
    end
  end

  defp resolve_coin_destination(board, variant, color, destination) do
    resolve_standard_coin_destination(board, variant, color, destination)
  end

  defp resolve_standard_coin_destination(board, variant, color, destination) do
    own_coin = own_coin(variant, color)
    opp_coin = opp_coin(variant, color)

    cond do
      destination == own_coin ->
        if pieces_at(board, own_coin, color) == 0 do
          {:ok, own_coin, :natural_take}
        else
          {:ok, own_coin, :normal}
        end

      destination == opp_coin ->
        cond do
          pieces_at(board, opp_coin, State.opposite(color)) > 0 ->
            :error

          pieces_at(board, own_coin, color) >= 2 ->
            :error

          true ->
            {:ok, own_coin, :power_take}
        end

      true ->
        {:ok, destination, :normal}
    end
  end

  defp landing_allowed(board, variant, color, _source, source_count, destination, coin_mode) do
    cond do
      destination != own_coin(variant, color) and
          destination_forbidden_by_jan_interdit?(board, variant, color, destination) ->
        :error

      pieces_at(board, destination, State.opposite(color)) > 0 ->
        :error

      true ->
        count =
          cond do
            coin_mode in [:natural_take, :power_take] -> 1
            true -> 1
          end

        cond do
          source_count < count ->
            :error

          true ->
            {:ok, false, count}
        end
    end
  end

  defp filter_natural_coin_priority(moves) do
    if Enum.any?(moves, &(&1.coin_mode == :natural_take)) do
      Enum.reject(moves, &(&1.coin_mode == :power_take))
    else
      moves
    end
  end

  defp filter_coin_rest_immediate_follow(moves, _runtime, %{id: "plein"}, _color), do: moves

  defp filter_coin_rest_immediate_follow(moves, runtime, variant, color) do
    dice = runtime.dice || %{}
    moves_played = Map.get(dice, :moves_played, Map.get(dice, :moves, []))
    moves_left = Map.get(dice, :moves_left, [])
    total_moves = Map.get(dice, :moves, moves_played ++ moves_left)
    restricted_points = restricted_rest_points(runtime.board, variant, color)
    current_singles = restricted_rest_singles(runtime.board, variant, color)

    cond do
      moves == [] ->
        moves

      moves_left == [] ->
        moves

      moves_played == [] and length(moves_left) >= length(total_moves) ->
        moves

      current_singles == [] ->
        moves

      true ->
        Enum.filter(moves, fn move ->
          next_board = apply_step_move(runtime.board, color, move)
          restricted_points != [] and restricted_rest_singles(next_board, variant, color) == []
        end)
    end
  end

  defp filter_coin_rest_setup_follow(moves, _runtime, %{id: "plein"}, _color), do: moves

  defp filter_coin_rest_setup_follow(moves, runtime, variant, color) do
    dice = runtime.dice || %{}
    current_singles = restricted_rest_singles(runtime.board, variant, color)

    cond do
      moves == [] ->
        moves

      current_singles != [] ->
        moves

      true ->
        Enum.filter(moves, fn move ->
          next_board = apply_step_move(runtime.board, color, move)
          next_singles = restricted_rest_singles(next_board, variant, color)

          if next_singles == [] do
            true
          else
            remaining =
              State.remove_all_used(
                Map.get(dice, :moves_left, []),
                Map.get(move, :dice_used, [move.die])
              )

            if remaining == [] do
              false
            else
              next_runtime = %{
                runtime
                | board: next_board,
                  dice:
                    dice
                    |> Map.put(:moves_left, remaining)
                    |> Map.put(
                      :moves_played,
                      Map.get(dice, :moves_played, Map.get(dice, :moves, [])) ++
                        Map.get(move, :dice_used, [move.die])
                    )
              }

              next_board
              |> raw_legal_moves(variant, color, remaining)
              |> Enum.uniq_by(fn candidate ->
                {candidate.from, candidate.to, candidate.die, Map.get(candidate, :dice_used),
                 Map.get(candidate, :via), Map.get(candidate, :sequence)}
              end)
              |> filter_natural_coin_priority()
              |> filter_coin_rest_immediate_follow(next_runtime, variant, color)
              |> Kernel.!=([])
            end
          end
        end)
    end
  end

  defp plein_forbids_opponent_side?(%{id: "plein"}), do: true
  defp plein_forbids_opponent_side?(_variant), do: false

  defp restricted_rest_singles(board, variant, color) do
    board
    |> restricted_rest_points(variant, color)
    |> Enum.filter(&(pieces_at(board, &1, color) == 1))
  end

  defp restricted_rest_points(board, variant, color) do
    own_coin = own_coin(variant, color)
    opp = State.opposite(color)

    extra_points =
      if VariantRules.toccategli?(variant) and
           opponent_table_protected?(board, variant, opp, :grand) do
        Enum.map(12..17, &denorm_pos(variant, &1, opp))
      else
        []
      end

    Enum.uniq([own_coin | extra_points])
  end

  defp table_full_for_movement?(board, variant, color, key) do
    case Constants.jan_table(State.normalize_table_key(key)) do
      nil ->
        false

      table ->
        Enum.all?(table.from..table.to, fn norm ->
          pieces_at(board, denorm_pos(variant, norm, color), color) >= 2
        end)
    end
  end

  defp retour_passage_phase(board, variant, color) do
    petit_fillable? = can_opponent_still_fill_table?(board, variant, color, :petit)

    grand_fillable? =
      petit_fillable? or can_opponent_still_fill_table?(board, variant, color, :grand)

    cond do
      petit_fillable? -> :retour_blocked
      grand_fillable? -> :retour_open_grand_protected
      true -> :retour_open_grand_open
    end
  end

  defp can_opponent_still_fill_table?(board, variant, color, key) do
    case Constants.jan_table(State.normalize_table_key(key)) do
      nil ->
        false

      table ->
        Enum.all?(table.from..table.to, fn suffix_start ->
          available = available_checkers_from_norm(board, variant, color, suffix_start)
          required = missing_units_in_suffix(board, variant, color, suffix_start, table.to)
          available >= required
        end)
    end
  end

  defp available_checkers_from_norm(board, variant, color, start_norm) do
    Enum.reduce(start_norm..23, 0, fn norm, acc ->
      acc + pieces_at(board, denorm_pos(variant, norm, color), color)
    end)
  end

  defp missing_units_in_suffix(board, variant, color, start_norm, end_norm) do
    Enum.reduce(start_norm..end_norm, 0, fn norm, acc ->
      count = pieces_at(board, denorm_pos(variant, norm, color), color)
      acc + max(2 - count, 0)
    end)
  end

  defp jan_table_key_for_start_norm(18), do: :petit
  defp jan_table_key_for_start_norm(12), do: :grand
  defp jan_table_key_for_start_norm(0), do: :retour
  defp jan_table_key_for_start_norm(_), do: nil

  defp destination_jan_table_for_opponent_norm(norm) when norm in 18..23, do: :petit
  defp destination_jan_table_for_opponent_norm(norm) when norm in 12..17, do: :grand
  defp destination_jan_table_for_opponent_norm(_), do: nil

  defp own_coin(variant, color), do: State.own_coin(variant, color)
  defp opp_coin(variant, color), do: State.opp_coin(variant, color)
  defp norm_pos(variant, position, color), do: State.norm_pos(variant, position, color)
  defp denorm_pos(variant, position, color), do: State.denorm_pos(variant, position, color)
end
