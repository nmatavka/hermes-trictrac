defmodule Backgammon.Rules.TourneCase do
  alias Backgammon.Rules.Dice

  def new do
    pieces = %{white: initial_pieces(), black: initial_pieces()}
    positions = positions_from_pieces(pieces)

    %{
      pieces: pieces,
      positions: positions,
      forced_piece: %{white: nil, black: nil},
      options: %{},
      variant_state: %{opening_rolls: %{white: nil, black: nil}},
      board: board_from_positions(positions)
    }
  end

  def pending_options do
    %{
      "rule" => "TourneCase",
      "options" => [
        %{
          "key" => "doubleWin",
          "label" => "Double if opponent has no coin piece",
          "defaultValue" => true
        }
      ]
    }
  end

  def submit_options(runtime, options) do
    %{runtime | options: Enum.into(options, %{}, fn {k, v} -> {to_string(k), v} end)}
  end

  def roll(runtime) do
    runtime = normalize_runtime(runtime)
    values = Dice.roll_two()
    low = Enum.min(values)
    Map.put(runtime, :dice, %{values: values, moves: [low], moves_left: [low], moves_played: []})
  end

  def legal_moves(runtime, color) do
    runtime
    |> normalize_runtime()
    |> internal_legal_moves(color)
    |> Enum.map(&Map.delete(&1, :piece_id))
  end

  def move(runtime, color, move) do
    runtime = normalize_runtime(runtime)

    legal =
      Enum.find(internal_legal_moves(runtime, color), fn candidate ->
        candidate.from == move["from"] and candidate.to == move["to"]
      end)

    if is_nil(legal) do
      {:error, "Invalid move."}
    else
      current_pieces = pieces_for(runtime, color)
      next = decode_space(color, legal.to)
      opp = opposite(color)
      hit_target = mirrored_hit(next)

      updated_color_pieces = update_piece_position(current_pieces, legal.piece_id, next)
      current_opp_pieces = pieces_for(runtime, opp)

      {updated_opp_pieces, hit_piece_id} =
        if hit_target == 11 do
          {current_opp_pieces, nil}
        else
          hit_piece(current_opp_pieces, hit_target)
        end

      updated_pieces = %{
        white: if(color == :white, do: updated_color_pieces, else: updated_opp_pieces),
        black: if(color == :black, do: updated_color_pieces, else: updated_opp_pieces)
      }

      updated_positions = positions_from_pieces(updated_pieces)

      forced_piece = %{
        white:
          if(color == :white,
            do: next_forced_piece_id(updated_color_pieces, legal.piece_id, next),
            else: clear_forced_piece_id(forced_piece_for(runtime, :white), hit_piece_id)
          ),
        black:
          if(color == :black,
            do: next_forced_piece_id(updated_color_pieces, legal.piece_id, next),
            else: clear_forced_piece_id(forced_piece_for(runtime, :black), hit_piece_id)
          )
      }

      updated =
        runtime
        |> Map.put(:pieces, updated_pieces)
        |> Map.put(:positions, updated_positions)
        |> Map.put(:forced_piece, forced_piece)
        |> Map.put(:board, board_from_positions(updated_positions))
        |> put_in([:dice, :moves_left], [])
        |> update_in([:dice, :moves_played], &(&1 ++ [legal.die]))

      {:ok, updated}
    end
  end

  def winner(runtime, color) do
    runtime = normalize_runtime(runtime)
    coin_count = Enum.count(position_list(runtime, color), &(&1 == 11))
    opp_coin_count = Enum.count(position_list(runtime, opposite(color)), &(&1 == 11))

    cond do
      coin_count >= 3 and runtime.options["doubleWin"] and opp_coin_count == 0 -> "double"
      coin_count >= 3 -> "single"
      true -> nil
    end
  end

  defp internal_legal_moves(runtime, color) do
    die = runtime.dice && List.first(runtime.dice.moves_left)

    if is_nil(die) do
      []
    else
      pieces =
        runtime
        |> pieces_for(color)
        |> Enum.sort_by(fn piece -> {piece.position, piece.id} end)

      positions = Enum.map(pieces, & &1.position)

      pieces
      |> Enum.with_index()
      |> Enum.flat_map(fn {position, index} ->
        next = min(position.position + die, 11)

        if legal_progress?(positions, index, next) do
          [
            %{
              from: encode_space(color, position.position),
              to: encode_space(color, next),
              die: die,
              piece_index: index,
              piece_id: position.id
            }
          ]
        else
          []
        end
      end)
      |> maybe_force_continuation(runtime, color)
    end
  end

  defp legal_progress?(positions, index, candidate) do
    ahead = Enum.at(positions, index + 1)
    behind = Enum.at(positions, index - 1)

    cond do
      candidate < 0 -> false
      candidate != 11 and Enum.any?(positions, &(&1 == candidate)) -> false
      ahead && candidate > ahead -> false
      behind && candidate < behind -> false
      true -> true
    end
  end

  defp mirrored_hit(position) when position in -1..11, do: position

  defp initial_pieces do
    Enum.map(0..2, fn id -> %{id: id, position: -1} end)
  end

  defp normalize_runtime(runtime) do
    pieces = %{
      white: pieces_for(runtime, :white),
      black: pieces_for(runtime, :black)
    }

    positions = positions_from_pieces(pieces)

    forced_piece = %{
      white: normalize_forced_piece_id(runtime, :white, pieces.white),
      black: normalize_forced_piece_id(runtime, :black, pieces.black)
    }

    runtime
    |> Map.put(:pieces, pieces)
    |> Map.put(:positions, positions)
    |> Map.put(:forced_piece, forced_piece)
    |> Map.put(:board, board_from_positions(positions))
  end

  defp pieces_for(runtime, color) do
    positions = position_list(runtime, color)

    case Map.get(runtime, :pieces) do
      %{^color => pieces} when is_list(pieces) ->
        normalized = Enum.map(pieces, &normalize_piece/1)

        cond do
          positions == [] ->
            normalized

          Enum.sort(Enum.map(normalized, & &1.position)) == Enum.sort(positions) ->
            normalized

          true ->
            pieces_from_positions(positions)
        end

      _ ->
        pieces_from_positions(positions)
    end
  end

  defp normalize_piece(%{id: id, position: position}), do: %{id: id, position: position}
  defp normalize_piece(%{id: id, pos: position}), do: %{id: id, position: position}

  defp position_list(runtime, color) do
    case Map.get(runtime, :positions) do
      %{^color => positions} -> positions
      _ -> []
    end
  end

  defp pieces_from_positions(positions) do
    positions
    |> Enum.with_index()
    |> Enum.map(fn {position, id} -> %{id: id, position: position} end)
  end

  defp positions_from_pieces(pieces) do
    %{
      white: pieces.white |> Enum.map(& &1.position) |> Enum.sort(),
      black: pieces.black |> Enum.map(& &1.position) |> Enum.sort()
    }
  end

  defp maybe_force_continuation(moves, runtime, color) do
    case forced_piece_for(runtime, color) do
      nil ->
        moves

      piece_id ->
        forced_moves = Enum.filter(moves, &(&1.piece_id == piece_id))
        if forced_moves == [], do: moves, else: forced_moves
    end
  end

  defp forced_piece_for(%{forced_piece: forced_piece}, color) when is_map(forced_piece),
    do: Map.get(forced_piece, color)

  defp forced_piece_for(_runtime, _color), do: nil

  defp normalize_forced_piece_id(runtime, color, pieces) do
    case forced_piece_for(runtime, color) do
      nil ->
        nil

      piece_id ->
        case Enum.find(pieces, &(&1.id == piece_id)) do
          %{position: position} when position in 0..10 ->
            if Enum.any?(pieces, fn piece ->
                 piece.id != piece_id and piece.position < position
               end) do
              piece_id
            else
              nil
            end

          _ ->
            nil
        end
    end
  end

  defp update_piece_position(pieces, piece_id, position) do
    Enum.map(pieces, fn piece ->
      if piece.id == piece_id, do: %{piece | position: position}, else: piece
    end)
  end

  defp hit_piece(pieces, target_position) do
    Enum.map_reduce(pieces, nil, fn piece, hit_id ->
      if piece.position == target_position and piece.position != 11 do
        {%{piece | position: -1}, piece.id}
      else
        {piece, hit_id}
      end
    end)
  end

  defp next_forced_piece_id(_pieces, _piece_id, 11), do: nil

  defp next_forced_piece_id(pieces, piece_id, position) do
    if Enum.any?(pieces, fn piece -> piece.id != piece_id and piece.position < position end) do
      piece_id
    else
      nil
    end
  end

  defp clear_forced_piece_id(forced_piece_id, hit_piece_id) when forced_piece_id == hit_piece_id,
    do: nil

  defp clear_forced_piece_id(forced_piece_id, _hit_piece_id), do: forced_piece_id

  defp board_from_positions(positions) do
    base = %{
      points: Enum.map(0..23, fn _ -> %{white: 0, black: 0} end),
      bar: %{
        white: Enum.count(positions.white, &(&1 < 0)),
        black: Enum.count(positions.black, &(&1 < 0))
      },
      outside: %{white: 0, black: 0}
    }

    Enum.reduce([{:white, positions.white}, {:black, positions.black}], base, fn {color, coords},
                                                                                 acc ->
      Enum.reduce(coords, acc, fn
        point, inner when point in 0..11 ->
          update_in(
            inner,
            [:points, Access.at(display_point(color, point)), color],
            &((&1 || 0) + 1)
          )

        _point, inner ->
          inner
      end)
    end)
  end

  defp display_point(:white, point), do: point
  defp display_point(:black, point), do: 23 - point

  defp encode_space(_color, -1), do: "bar"
  defp encode_space(_color, 11), do: "home"
  defp encode_space(color, point), do: display_point(color, point)

  defp decode_space(_color, "bar"), do: -1
  defp decode_space(_color, "home"), do: 11
  defp decode_space(:white, point) when is_integer(point), do: point
  defp decode_space(:black, point) when is_integer(point), do: 23 - point

  defp opposite(:white), do: :black
  defp opposite(:black), do: :white
end
