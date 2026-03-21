defmodule Backgammon.Rules.Trictrac.Classique.Moves do
  alias Backgammon.Rules.Trictrac.Classique.{Constants, State}

  def legal_moves(runtime, variant, color) do
    moves_left = runtime.dice && runtime.dice.moves_left || []

    runtime.board
    |> raw_legal_moves(variant, color, moves_left)
    |> Enum.uniq_by(fn move ->
      {move.from, move.to, move.die, Map.get(move, :dice_used), Map.get(move, :via), Map.get(move, :sequence)}
    end)
    |> filter_natural_coin_priority()
    |> filter_coin_rest_immediate_follow(runtime, variant, color)
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

  def destination_forbidden_by_jan_interdit?(board, color, destination) do
    if destination == State.own_coin(color) do
      false
    else
      opp = State.opposite(color)
      opp_norm = State.norm_pos(destination, opp)

      cond do
        opp_norm in 18..23 -> opponent_table_protected?(board, opp, :petit)
        opp_norm in 12..17 -> opponent_table_protected?(board, opp, :grand)
        true -> false
      end
    end
  end

  def table_full?(board, color, key) do
    case Enum.find(Constants.jan_tables(), &(&1.key == State.normalize_table_key(key))) do
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
  def count_all_at(board, point), do: pieces_at(board, point, :white) + pieces_at(board, point, :black)
  def coin_count_from_board(board, point, color), do: pieces_at(board, point, color)

  def all_paired?(board, color, from_norm, to_norm) do
    Enum.all?(from_norm..to_norm, fn norm ->
      pieces_at(board, State.denorm_pos(norm, color), color) >= 2
    end)
  end

  def all_occupied?(board, color, from_norm, to_norm) do
    Enum.all?(from_norm..to_norm, fn norm ->
      pieces_at(board, State.denorm_pos(norm, color), color) >= 1
    end)
  end

  def opponent_table_protected?(board, color, :petit) do
    can_opponent_still_fill_jan?(board, color, 18) or table_full?(board, color, :petit)
  end

  def opponent_table_protected?(board, color, :grand) do
    can_opponent_still_fill_jan?(board, color, 12) or table_full?(board, color, :grand)
  end

  def can_opponent_still_fill_jan?(board, color, jan_start_norm) do
    Enum.reduce(0..23, 0, fn pos, acc ->
      cnt = pieces_at(board, pos, color)
      if cnt > 0 and State.norm_pos(pos, color) >= jan_start_norm, do: acc + cnt, else: acc
    end) >= 12
  end

  defp remove_piece(board, color, point, count),
    do: update_in(board, [:points, Access.at(point), color], &max((&1 || 0) - count, 0))

  defp add_piece(board, color, "home", count), do: update_in(board, [:outside, color], &((&1 || 0) + count))
  defp add_piece(board, color, point, count), do: update_in(board, [:points, Access.at(point), color], &((&1 || 0) + count))

  defp apply_step_hit(board, _color, %{to: "home"}), do: board

  defp apply_step_hit(board, color, move) do
    board =
      case move do
        %{to: destination, hit?: true} ->
          hit_one(board, color, destination)

        _ ->
          board
      end

    case Map.get(move, :intermediate_hit) do
      nil -> board
      destination -> hit_one(board, color, destination)
    end
  end

  defp hit_one(board, color, destination) do
    opp = State.opposite(color)

    board
    |> put_in([:points, Access.at(destination), opp], 0)
    |> update_in([:bar, opp], &((&1 || 0) + 1))
  end

  defp single_trictrac_moves(board, variant, color, point, die) do
    source_norm = State.norm_pos(point, color)
    source_count = pieces_at(board, point, color)
    target_norm = source_norm - die

    cond do
      target_norm >= 0 ->
        raw_destination = State.denorm_pos(target_norm, color)

        with {:ok, destination, coin_mode} <- resolve_coin_destination(board, variant, color, raw_destination),
             {:ok, hit?, count} <- landing_allowed(board, variant, color, point, source_count, destination, coin_mode) do
          [%{from: point, to: destination, die: die, hit?: hit?, count: count, coin_mode: coin_mode}]
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
    source_norm = State.norm_pos(point, color)
    source_count = pieces_at(board, point, color)
    middle_norm = source_norm - first
    final_norm = source_norm - first - second

    cond do
      middle_norm < 0 ->
        maybe_sortie_sum_move(board, variant, color, point, first, second)

      final_norm >= 0 ->
        middle = State.denorm_pos(middle_norm, color)
        raw_destination = State.denorm_pos(final_norm, color)
        opp = State.opposite(color)
        middle_opp = pieces_at(board, middle, opp)
        middle_empty = count_all_at(board, middle) == 0
        final_opp = pieces_at(board, raw_destination, opp)
        passing_retour? = source_norm >= 6 and final_norm < 6
        opponent_still_petit? = opponent_table_protected?(board, opp, :petit)

        cond do
          passing_retour? and opponent_still_petit? ->
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
                middle in [State.own_coin(color), State.opp_coin(color)] and middle_empty -> :intermediate_coin
                true -> :normal
              end

            with {:ok, destination, coin_mode} <- resolve_coin_destination(board, variant, color, raw_destination),
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
              [%{
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
              }]
            else
              _ -> []
            end
        end

      true ->
        maybe_sortie_sum_move(board, variant, color, point, first, second)
    end
  end

  defp maybe_sortie_moves(_board, %{id: "plein"}, _color, _point, _die, _dice_used), do: []

  defp maybe_sortie_moves(board, _variant, color, point, die, dice_used) do
    source_norm = State.norm_pos(point, color)
    source_count = pieces_at(board, point, color)

    cond do
      not can_sortie?(board, color) ->
        []

      source_norm + 1 == die ->
        [%{
          from: point,
          to: "home",
          die: Enum.sum(dice_used),
          dice_used: dice_used,
          count: sortie_count(point, color, source_count),
          coin_mode: :sortie_exact
        }]

      die > source_norm + 1 and source_norm == furthest_sortie_norm(board, color) ->
        [%{
          from: point,
          to: "home",
          die: Enum.sum(dice_used),
          dice_used: dice_used,
          count: sortie_count(point, color, source_count),
          coin_mode: :sortie_excedant
        }]

      true ->
        []
    end
  end

  defp maybe_sortie_sum_move(_board, %{id: "plein"}, _color, _point, _first, _second), do: []

  defp maybe_sortie_sum_move(board, _variant, color, point, first, second) do
    source_norm = State.norm_pos(point, color)
    sum = first + second
    source_count = pieces_at(board, point, color)

    cond do
      can_sortie?(board, color) and source_norm + 1 == sum and first < source_norm + 1 and second < source_norm + 1 ->
        [%{
          from: point,
          to: "home",
          die: sum,
          dice_used: [first, second],
          sequence: [first, second],
          count: sortie_count(point, color, source_count),
          coin_mode: :point_sortant,
          via: "edge"
        }]

      can_privilege_sortie?(board, color) and source_norm in 6..11 and source_norm + 1 == sum ->
        [%{
          from: point,
          to: "home",
          die: sum,
          dice_used: [first, second],
          sequence: [first, second],
          count: 1,
          coin_mode: :sortie_privilege,
          via: "edge"
        }]

      true ->
        []
    end
  end

  defp can_sortie?(board, color) do
    Enum.all?(6..23, fn norm ->
      pieces_at(board, State.denorm_pos(norm, color), color) == 0
    end)
  end

  defp can_privilege_sortie?(board, color) do
    Enum.all?(12..23, fn norm ->
      pieces_at(board, State.denorm_pos(norm, color), color) == 0
    end)
  end

  defp furthest_sortie_norm(board, color) do
    5..0//-1
    |> Enum.find(fn norm -> pieces_at(board, State.denorm_pos(norm, color), color) > 0 end)
  end

  defp sortie_count(_point, _color, source_count) when source_count <= 1, do: 1
  defp sortie_count(_point, _color, _source_count), do: 1

  defp resolve_coin_destination(board, %{id: "plein"}, color, destination) do
    if destination == State.own_coin(color) do
      {:ok, State.own_coin(color), :plein_coin}
    else
      resolve_coin_destination(board, %{}, color, destination)
    end
  end

  defp resolve_coin_destination(board, _variant, color, destination) do
    own_coin = State.own_coin(color)
    opp_coin = State.opp_coin(color)

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

          pieces_at(board, own_coin, color) > 0 ->
            :error

          true ->
            {:ok, own_coin, :power_take}
        end

      true ->
        {:ok, destination, :normal}
    end
  end

  defp landing_allowed(board, variant, color, source, source_count, destination, coin_mode) do
    cond do
      destination != State.own_coin(color) and destination_forbidden_by_jan_interdit?(board, color, destination) ->
        :error

      pieces_at(board, destination, State.opposite(color)) >= 2 ->
        :error

      true ->
        own_count = pieces_at(board, destination, color)

        count =
          cond do
            coin_mode in [:natural_take, :power_take] -> 2
            true -> 1
          end

        cond do
          source_count < count ->
            :error

          not plein_variant?(variant) and source == State.own_coin(color) and source_count - count == 1 ->
            :error

          not plein_variant?(variant) and destination == State.own_coin(color) and own_count + count == 1 ->
            :error

          true ->
            {:ok, pieces_at(board, destination, State.opposite(color)) == 1, count}
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

  defp filter_coin_rest_immediate_follow(moves, runtime, _variant, color) do
    dice = runtime.dice || %{moves: [], moves_left: []}
    moves_played = dice.moves || []
    moves_left = dice.moves_left || []
    own_coin = State.own_coin(color)
    current_coin_count = pieces_at(runtime.board, own_coin, color)

    cond do
      moves == [] ->
        moves

      moves_left == [] ->
        moves

      length(moves_left) >= length(moves_played) ->
        moves

      current_coin_count != 1 ->
        moves

      true ->
        Enum.filter(moves, fn move ->
          move_count = Map.get(move, :count, 1)

          next_coin_count =
            current_coin_count
            |> then(fn count ->
              if move.from == own_coin, do: count - move_count, else: count
            end)
            |> then(fn count ->
              if move.to == own_coin, do: count + move_count, else: count
            end)

          next_coin_count != 1
        end)
    end
  end

  defp plein_variant?(%{id: "plein"}), do: true
  defp plein_variant?(_variant), do: false
end
